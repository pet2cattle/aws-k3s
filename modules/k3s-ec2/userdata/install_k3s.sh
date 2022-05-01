#!/bin/bash

set -x

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

      # wait for k3s to be ready
      until kubectl get pods -A | grep Running > /dev/null; 
      do 
        sleep 5; 
      done

      # initial backup
      k3s etcd-snapshot --s3 --s3-bucket=${K3S_BUCKET} --etcd-s3-folder=${K3S_BACKUP_PREFIX} --etcd-s3-region=${REGION}

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

      # wait restore process to finish
      until journalctl -xe | grep "restart without --cluster-reset";
      do
        sleep 5;
      done
      
      sed -e '/--cluster-reset/d' -i /etc/systemd/system/k3s.service

      systemctl daemon-reload
      systemctl restart k3s

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

  # cloud provider install

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
    hostNetworking: true
    nodeSelector:
      node-role.kubernetes.io/master: "true"
EOF

else
  echo "worker node"
  seconary_join
fi