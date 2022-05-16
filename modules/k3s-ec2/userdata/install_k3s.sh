#!/bin/bash

set -x

# ALB controller - Kustomize dependency
yum install git -y

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
EXISTING_HOSTNAME=$(cat /etc/hostname)

hostnamectl set-hostname $INSTANCE_ID
hostname $INSTANCE_ID

sudo sed -i "s/$EXISTING_HOSTNAME/$INSTANCE_ID/g" /etc/hosts
sudo sed -i "s/$EXISTING_HOSTNAME/$INSTANCE_ID/g" /etc/hostname

# aws cli config
mkdir -p ~/.aws
echo "[default]" > ~/.aws/config
echo "region = ${REGION}" >> ~/.aws/config

CLUSTER_INSTANCES=$(aws ec2 describe-instances --filters Name=tag:k3s_cluster_name,Values=${K3S_CLUSTERNAME} Name=tag:k3s_role,Values=master --query 'sort_by(Reservations[].Instances[], &LaunchTime)[*].[PrivateIpAddress]' --output text | grep -v None)
CLUSTER_INSTANCES_COUNT=$(echo "$CLUSTER_INSTANCES" | grep -v None | wc -l)
LOCAL_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
FLANNEL_IFACE=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)')
PROVIDER_ID="$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)/$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
K3S_ROLE=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$(hostname)" --output=text | grep k3s_role | awk '{ print $NF }' | head -n1)

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
                  ""
            )

export BASE_OPTS="$BASE_OPTS"

BACKUPS_AVAILABLE=$(aws s3 ls s3://${K3S_BUCKET}/${K3S_BACKUP_PREFIX}/ | wc -l)

seconary_join() {
  for PRIMARY_NODE in $CLUSTER_INSTANCES;
  do
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server" sh -s - --server https://$PRIMARY_NODE:6443 $BASE_OPTS
    if [ $? -eq 0 ]
    then
      echo "Install k3s on $PRIMARY_NODE succeeded"
      exit 0
    fi
  done
}

if [ "$K3S_ROLE" == "master" ];
then
  if [ $CLUSTER_INSTANCES_COUNT -eq 1 ];
  then
    # first / only master node alive

    if [ $BACKUPS_AVAILABLE -eq 0 ];
    then
      # no backups available, install k3s
      echo "Cluster init"
      curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server" sh -s - --cluster-init $BASE_OPTS

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

  # basic helm charts

  mkdir -p /var/lib/rancher/k3s/server/manifests/

  # https://kubernetes.github.io/cloud-provider-aws/index.yaml
  cat <<"EOF" > /var/lib/rancher/k3s/server/manifests/aws-ccm.yaml
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

  # TargetGroupBinding
  kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds?ref=master"

  # aws-load-balancer-controller
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
EOF

  # initial backup
  k3s etcd-snapshot --s3 --s3-bucket=${K3S_BUCKET} --etcd-s3-folder=${K3S_BACKUP_PREFIX} --etcd-s3-region=${REGION}

else
  echo "worker node"
  seconary_join
fi

# make sure local-path is not the default SC
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

# configuring kube-system as the default namespace
kubectl config set-context --current --namespace kube-system
