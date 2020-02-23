#!/bin/bash
sudo systemctl stop packagekit.service
sudo systemctl disable packagekit.service
sudo yum update -y
sudo yum install -y yum-utils \
device-mapper-persistent-data vim \
lvm2

sudo yum-config-manager \
--add-repo \
https://download.docker.com/linux/centos/docker-ce.repo


sudo yum install -y docker-ce \
docker-ce-cli \
containerd.io

sudo systemctl start docker

sudo docker run hello-world

sudo bash -c 'cat <<EOF > /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF'

sudo mkdir -p /etc/systemd/system/docker.service.d
sudo systemctl daemon-reload && sudo systemctl restart docker

sudo tee -a  /etc/yum.repos.d/kubernetes.repo <<EOF
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

sudo setenforce 0

sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

sudo systemctl enable --now kubelet

sudo tee -a /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sudo sysctl --system
