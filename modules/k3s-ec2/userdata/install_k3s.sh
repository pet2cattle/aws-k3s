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

CLUSTER_INSTANCES=$(aws ec2 describe-instances --filters Name=tag:k3s_cluster_name,Values=${K3S_CLUSTERNAME} Name=tag:k3s_role,Values=master --query 'sort_by(Reservations[].Instances[], &LaunchTime)[*].[PrivateIpAddress]' --output text)
CLUSTER_INSTANCES_COUNT=$(echo "$CLUSTER_INSTANCES" | wc -l)
LOCAL_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
FLANNEL_IFACE=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)')
PROVIDER_ID="$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)/$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"

# TODO: handle S3 backup/restore?

BASE_OPTS=$(echo  "" \
                  " --disable-cloud-controller" \
                  " --disable servicelb" \
                  " --disable traefik" \
                  " --node-ip $LOCAL_IP" \
                  " --advertise-address $LOCAL_IP" \
                  " --flannel-iface $FLANNEL_IFACE" \
                  " --write-kubeconfig-mode=644" \
                  " --kubelet-arg="cloud-provider=external" \
                  " --kubelet-arg="provider-id=aws:///$PROVIDER_ID" \
                  ""
            )

BACKUPS_AVAILABLE=$(aws s3 ls s3://${K3S_BUCKET}/${K3S_BACKUP_PREFIX} | wc -l)

echo "Cluster init!"
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server"  K3S_TOKEN=${K3S_TOKEN} sh -s - $BASE_OPTS


# echo "Join cluster"
# # TODO
# curl -sfL https://get.k3s.io | K3S_TOKEN=${K3S_TOKEN} sh -s - --server https://K3S_LB:6443 --node-ip $LOCAL_IP --advertise-address $LOCAL_IP --flannel-iface $FLANNEL_IFACE --kubelet-arg="provider-id=aws:///$PROVIDER_ID"
