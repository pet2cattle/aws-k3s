#!/bin/bash

set -x

# ALB controller - Kustomize dependency
yum install git nc jq -y

# aws cli config
mkdir -p ~/.aws
echo "[default]" > ~/.aws/config
echo "region = ${REGION}" >> ~/.aws/config

MASTER_INSTANCES=$(aws ec2 describe-instances --filters Name=tag:k3s_cluster_name,Values=${K3S_CLUSTERNAME} Name=tag:k3s_role,Values=master Name=instance-state-name,Values=running --query 'sort_by(Reservations[].Instances[], &LaunchTime)[*].[PrivateIpAddress]' --output text | grep -v None)
MASTER_INSTANCES_COUNT=$(echo "$MASTER_INSTANCES" | grep -v None | wc -l)
LOCAL_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
FLANNEL_IFACE=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)')
PROVIDER_ID="$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)/$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
K3S_ROLE=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)" --output=text | grep k3s_role | awk '{ print $NF }' | head -n1)
BOOTSTRAP=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)" --output=text | grep k3s_bootstrap | awk '{ print $NF }' | wc -l)
BOOTSTRAP_INSTANCES_COUNT=$(aws ec2 describe-instances --filters Name=instance-state-name,Values=running Name=tag:k3s_bootstrap,Values=true --query 'sort_by(Reservations[].Instances[], &LaunchTime)[*].[PrivateIpAddress]' --output=text | grep -v None | wc -l)
LIFECYCLE=$(aws ec2 describe-spot-instance-requests --filters Name=instance-id,Values="$(wget -q -O - http://169.254.169.254/latest/meta-data/instance-id)" --region ${REGION} | jq -r '.SpotInstanceRequests | if length > 0 then "spot" else "ondemand" end')

MAIN_IP=$(hostname | grep -Eo "[0-9]+-[0-9]+-[0-9]+-[0-9]+" | tr - .)

BASE_OPTS=$(echo  "" \
                  " --token ${K3S_TOKEN}" \
                  " --disable-cloud-controller" \
                  " --disable servicelb" \
                  " --disable traefik" \
                  " --disable metrics-server" \
                  " --node-ip $LOCAL_IP" \
                  " --advertise-address $LOCAL_IP" \
                  " --flannel-iface $FLANNEL_IFACE" \
                  " --write-kubeconfig-mode=644" \
                  " --kubelet-arg="cloud-provider=external" \
                  " --kubelet-arg="provider-id=aws:///$PROVIDER_ID" \
                  " --etcd-s3 " \
                  " --etcd-s3-bucket ${K3S_BUCKET}" \
                  " --etcd-s3-folder ${K3S_BACKUP_PREFIX}" \
                  " --etcd-s3-region ${REGION}" \
                  " --node-label node.lifecycle=$LIFECYCLE" \
                  " --bind-address $MAIN_IP" \
                  " --advertise-address $MAIN_IP"
                  ""
            )

PK_BOOTSTRAP="${BOOTSTRAP_PK_PATH}"

export BASE_OPTS="$BASE_OPTS"

BACKUPS_AVAILABLE=$(aws s3 ls s3://${K3S_BUCKET}/${K3S_BACKUP_PREFIX}/ | wc -l)

kubectl_settings() {
  # make sure local-path is not the default SC
  kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

  # configuring kube-system as the default namespace
  kubectl config set-context --current --namespace kube-system
}

seconary_join() {
  MASTER_INSTANCES=$(aws ec2 describe-instances --filters Name=tag:k3s_cluster_name,Values=${K3S_CLUSTERNAME} Name=tag:k3s_role,Values=master --query 'sort_by(Reservations[].Instances[], &LaunchTime)[*].[PrivateIpAddress]' --output text | grep -v None)
  MASTER_INSTANCES_COUNT=$(echo "$MASTER_INSTANCES" | grep -v None | wc -l)

  if [ $MASTER_INSTANCES_COUNT -ne 0 ];
  then
    until [ $MASTER_INSTANCES_COUNT -gt 0 ];
    do
      # wait for master instances to come up
      sleep 5s

      MASTER_INSTANCES=$(aws ec2 describe-instances --filters Name=tag:k3s_cluster_name,Values=${K3S_CLUSTERNAME} Name=tag:k3s_role,Values=master --query 'sort_by(Reservations[].Instances[], &LaunchTime)[*].[PrivateIpAddress]' --output text | grep -v None)
      MASTER_INSTANCES_COUNT=$(echo "$MASTER_INSTANCES" | grep -v None | wc -l)
    done
  fi

  for PRIMARY_NODE in $MASTER_INSTANCES;
  do
    while true;
    do
      nc -zv $PRIMARY_NODE 6443
      if [ $? -eq 0 ];
      then
        break
      else
        echo "waiting for $PRIMARY_NODE 6443"
        sleep 30s
      fi
    done

    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="$INSTALL_MODE" sh -s - --server https://$PRIMARY_NODE:6443 $BASE_OPTS
    if [ $? -eq 0 ]
    then
      echo "Install k3s on $PRIMARY_NODE succeeded"

      kubectl_settings

      exit 0
    fi
  done
}

if [ "$K3S_ROLE" == "master" ];
then
  INSTALL_MODE="server"
  DIFF_INSTANCES=$(($MASTER_INSTANCES_COUNT-$BOOTSTRAP_INSTANCES_COUNT))

  if [ $DIFF_INSTANCES -le 1 ] && [ $BOOTSTRAP -eq 1 ];
  then
    # master node alive in bootstrap mode

    if [ $BACKUPS_AVAILABLE -eq 0 ];
    then
      # no backups available, install k3s
      echo "Cluster init"
      curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="$INSTALL_MODE" sh -s - --cluster-init $BASE_OPTS

      # wait for k3s to be Pending (aws-cloud-controller is needed to get to Running state)
      until kubectl get pods -A | grep Pending > /dev/null; 
      do 
        sleep 5; 
      done

    else
      # backups available, restore k3s
      echo "Restore from backup"

      RESTORE_BACKUP=""
      RESTORE_TS="0"
      for BACKUP in $(aws s3 ls s3://${K3S_BUCKET}/${K3S_BACKUP_PREFIX}/ | awk '{ print $NF }');
      do
        TIMESTAMP=$(echo $BACKUP | rev | cut -d'-' -f1 | rev)
        
        if [ $TIMESTAMP -gt $RESTORE_TS ];
        then
          RESTORE_BACKUP=$BACKUP
          RESTORE_TS=$TIMESTAMP
        fi
      done

      if [ $RESTORE_TS -eq 0 ];
      then
        echo "No backups available"
        exit 1
      fi

      echo "Restore backup $RESTORE_BACKUP"
      curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server" sh -s -  $BASE_OPTS \
                                                                        --cluster-reset \
                                                                        --cluster-reset-restore-path="$RESTORE_BACKUP"

      # give it some time
      sleep 1m

      journalctl -xe

      # wait restore process to finish
      until journalctl -xe | grep "Managed etcd cluster membership has been reset";
      do
        sleep 5;
      done
      
      sed -e '/--cluster-reset/d' -i /etc/systemd/system/k3s.service

      systemctl daemon-reload

    fi

  else
    # secondary master node alive
    echo "Intalling secondary master node"

    seconary_join
  fi

  #
  # post install master
  #

  # add cronjob to backup etcd
  (crontab -l 2>/dev/null; echo "0 0 * * * k3s etcd-snapshot --s3 --s3-bucket=${K3S_BUCKET} --etcd-s3-folder=${K3S_BACKUP_PREFIX} --etcd-s3-region=${REGION}"; ) | crontab -
  (crontab -l 2>/dev/null; echo "15 0 * * * k3s etcd-snapshot prune --s3 --s3-bucket=${K3S_BUCKET} --etcd-s3-folder=${K3S_BACKUP_PREFIX} --etcd-s3-region=${REGION}"; ) | crontab -

  # upsert ECR secret
  if [ "$(kubectl get secret ecr --no-headers 2>/dev/null | wc -l)" -ne 0 ];
  then
    kubeconfig delete secret ecr
  fi
  
  kubectl create secret docker-registry ecr --docker-server 602401143452.dkr.ecr.us-west-2.amazonaws.com --docker-username=AWS --docker-password=$(aws ecr get-login-password) -n kube-system

  # cron to update it
  (crontab -l 2>/dev/null; echo "0 */11 * * * kubeconfig delete secret ecr; kubectl create secret docker-registry ecr --docker-server 602401143452.dkr.ecr.us-west-2.amazonaws.com --docker-username=AWS --docker-password=$(aws ecr get-login-password) -n kube-system"; ) | crontab -

  # basic helm charts

  mkdir -p /var/lib/rancher/k3s/server/manifests/

  # https://kubernetes.github.io/cloud-provider-aws/index.yaml
  : aws-cloud-provider
  cat <<"EOF" > /var/lib/rancher/k3s/server/manifests/aws-cloud-provider.yaml
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: aws-cloud-controller-manager
  namespace: kube-system
spec:
  chart: https://github.com/kubernetes/cloud-provider-aws/releases/download/helm-chart-aws-cloud-controller-manager-0.0.6/aws-cloud-controller-manager-0.0.6.tgz
  targetNamespace: kube-system
  bootstrap: true
  valuesContent: |-
    args:
      - --v=2
      - --cloud-provider=aws
      - --cluster-cidr=${MAIN_VPC_CIDR_BLOCK}
    hostNetworking: true
    nodeSelector:
      node-role.kubernetes.io/master: "true"
EOF
 
  : ebs-csi
  cat <<"EOF" > /var/lib/rancher/k3s/server/manifests/ebs-csi.yaml
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: ebs-csi
  namespace: kube-system
spec:
  chart: https://github.com/kubernetes-sigs/aws-ebs-csi-driver/releases/download/helm-chart-aws-ebs-csi-driver-2.6.7/aws-ebs-csi-driver-2.6.7.tgz
  targetNamespace: kube-system
  bootstrap: true
  valuesContent: |-
    storageClasses:
    - name: ebs-gp2
      # annotation metadata
      annotations:
        storageclass.kubernetes.io/is-default-class: "true"
      volumeBindingMode: WaitForFirstConsumer
      reclaimPolicy: Retain
      parameters:
        encrypted: "true"
        type: gp2
EOF

  : TargetGroupBinding
  kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds?ref=master"

  : aws-load-balancer-controller
  cat <<"EOF" > /var/lib/rancher/k3s/server/manifests/alb-controller.yaml
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: alb-controller
  namespace: kube-system
spec:
  chart: https://aws.github.io/eks-charts/aws-load-balancer-controller-1.4.1.tgz
  targetNamespace: kube-system
  bootstrap: true
  valuesContent: |-
    clusterName: default
    image:
      repository: 602401143452.dkr.ecr.us-west-2.amazonaws.com/amazon/aws-load-balancer-controller
    replicaCount: 1
    imagePullSecrets:
      - name: ecr
EOF

  : aws-node-termination-handler
  cat <<"EOF" > /var/lib/rancher/k3s/server/manifests/termination-handler.yaml
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: termination-handler
  namespace: kube-system
spec:
  chart: https://aws.github.io/eks-charts/aws-node-termination-handler-0.18.3.tgz
  targetNamespace: kube-system
  bootstrap: true
  valuesContent: |-
    enableRebalanceMonitoring: false
    enableRebalanceDraining: false
    enableScheduledEventDraining: ""
    enableSpotInterruptionDraining: "true"
    checkASGTagBeforeDraining: false
    emitKubernetesEvents: true
    nodeSelector:
      node.lifecycle: spot
EOF

  : metrics server
  cat <<"EOF" > /var/lib/rancher/k3s/server/manifests/metrics.yaml
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: metrics-server
  namespace: kube-system
spec:
  chart: https://github.com/kubernetes-sigs/metrics-server/releases/download/metrics-server-helm-chart-3.8.2/metrics-server-3.8.2.tgz
  targetNamespace: kube-system
  bootstrap: true
  valuesContent: |-
    affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: node.lifecycle
              operator: In
              values:
              - spot
          topologyKey: kubernetes.io/hostname
EOF

  if [ ! -z "${BOOTSTRAP_REPO}" ];
  then
    # wait for k3s to have Running pods
    until kubectl get pods -A | grep Running > /dev/null; 
    do 
      sleep 5; 
    done

    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    echo "$PK_BOOTSTRAP" | base64 -d - | gzip -d -  > /root/.ssh/id_bootstraprepo
    chmod 600 /root/.ssh/id_bootstraprepo

    # install objects from git repo
    mkdir -p /root/bootstraprepo
    GIT_SSH_COMMAND='ssh -i /root/.ssh/id_bootstraprepo -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null' git clone "${BOOTSTRAP_REPO}" /root/bootstraprepo
  fi

  # initial backup
  k3s etcd-snapshot --s3 --s3-bucket=${K3S_BUCKET} --etcd-s3-folder=${K3S_BACKUP_PREFIX} --etcd-s3-region=${REGION}

else
  echo "worker node"
  INSTALL_MODE="agent"

  seconary_join
fi

kubectl_settings

