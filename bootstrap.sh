
setenforce 0
sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
systemctl disable --now firewalld

swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/98-k8s.conf
net.ipv4.ip_forward=1
net.ipv4.ip_nonlocal_bind=1
net.bridge.bride-nf-call-iptables=1
net.netfilter.nf_conntrack_max=1000000
EOF

/sbin/sysctl --system

dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
dnf -y update
dnf install  -y containerd.io

containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
systemctl enable --now containerd

cat <<EOF /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF


dnf install -y iproute-tc
dnf install -y {kubelet,kubeadm,kubectl} --disableexcludes=kubernetes
systemctl enable kubelet.service
