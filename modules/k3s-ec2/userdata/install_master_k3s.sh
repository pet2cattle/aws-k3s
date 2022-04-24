#!/bin/bash

set -x
exec > /var/log/userdata.log 2>&1

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
EXISTING_HOSTNAME=$(cat /etc/hostname)

hostnamectl set-hostname $INSTANCE_ID
hostname $INSTANCE_ID

sudo sed -i "s/$EXISTING_HOSTNAME/$INSTANCE_ID/g" /etc/hosts
sudo sed -i "s/$EXISTING_HOSTNAME/$INSTANCE_ID/g" /etc/hostname

if [ "$(uname -m)" == "x86_64" ]; 
then
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
else
  curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "/tmp/awscliv2.zip"
fi
unzip /tmp/awscliv2.zip
sudo ./aws/install
rm -rf aws /tmp/awscliv2.zip

MASTER_INSTANCE=$(aws ec2 describe-instances --filters Name=tag-value,Values=k3s-server Name=instance-state-name,Values=running --query 'sort_by(Reservations[].Instances[], &LaunchTime)[:-1].[InstanceId]' --output text | head -n1)
LOCAL_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
FLANNEL_IFACE=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)')
PROVIDER_ID="$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)/$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"

if [[ "$MASTER_INSTANCE" == "$INSTANCE_ID" ]]; then
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
