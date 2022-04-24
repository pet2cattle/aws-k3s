#!/bin/bash

set -x
exec > /var/log/userdata.log 2>&1

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

MASTER_INSTANCE=$(aws ec2 describe-instances --filters Name=tag-value,Values=k3s-master Name=instance-state-name,Values=running --query 'sort_by(Reservations[].Instances[], &LaunchTime)[:-1].[InstanceId]' --output text | head -n1)
LOCAL_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
FLANNEL_IFACE=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)')
PROVIDER_ID="$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)/$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"

# TODO: handle S3 backup/restore?

if [[ "$MASTER_INSTANCE" == "$INSTANCE_ID" ]]; then
  # first running instance

  # TODO: check whether there is a S3 backup?
  echo "Cluster init!"
  curl -sfL https://get.k3s.io | K3S_TOKEN=${K3S_TOKEN} sh -s - --cluster-init --node-ip $LOCAL_IP --advertise-address $LOCAL_IP --flannel-iface $FLANNEL_IFACE --kubelet-arg="provider-id=aws:///$PROVIDER_ID"
else
  echo "Join cluster"
  curl -sfL https://get.k3s.io | K3S_TOKEN=${K3S_TOKEN} sh -s - --server https://${K3S_CLUSTERNAME}:6443 --node-ip $LOCAL_IP --advertise-address $LOCAL_IP --flannel-iface $FLANNEL_IFACE --kubelet-arg="provider-id=aws:///$PROVIDER_ID"
fi

until kubectl get pods -A | grep 'Running'; 
do
  echo 'Waiting for k3s startup'
  sleep 5
done
