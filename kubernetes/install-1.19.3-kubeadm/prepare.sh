#设置host
cat >> /etc/hosts <<EOF
10.0.50.101 kube-m-50-101.jieee.xyz
10.0.50.102 kube-m-50-102.jieee.xyz
10.0.50.103 kube-m-50-103.jieee.xyz
10.0.60.101 kube-n-60-101.jieee.xyz
10.0.60.102 kube-n-60-102.jieee.xyz
10.0.60.103 kube-n-60-103.jieee.xyz
EOF

#关闭防火墙
systemctl stop firewalld
systemctl disable firewalld
#关闭swap
swapoff -a
sed -i '/swap/s/^\(.*\)$/#\1/g' /etc/fstab
#关闭selinux
setenforce 0
sed -i 's/enforcing/disabled/' /etc/selinux/config
#关闭dnsmasq
service dnsmasq stop
systemctl disable dnsmasq
#重置iptables
iptables -F && iptables -X && iptables -F -t nat && iptables -X -t nat && iptables -P FORWARD ACCEPT

#更新yum
yum update
#安装依赖包
yum install -y ipset ipvsadm curl

#设置内核参数
cat > /etc/sysctl.d/k8s.conf<<EOF
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
vm.swappiness = 0
vm.overcommit_memory=1
vm.panic_on_oom=0
fs.inotify.max_user_watches=89100
EOF
#使配置文件生效
modprobe br_netfilter
sysctl -p /etc/sysctl.d/k8s.conf

#配置ipvs，保证系统重启后能自动加载ipvs模块
cat > /etc/sysconfig/modules/ipvs.modules<<EOF
#!/bin/bash
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack_ipv4
EOF
chmod 755 /etc/sysconfig/modules/ipvs.modules
bash /etc/sysconfig/modules/ipvs.modules

#如果存在旧的安装包，删除掉
yum remove -y docker* container-selinux

#安装必要的软件包
yum install -y yum-utils device-mapper-persistent-data lvm2

#添加yum源（这里使用了aliyun镜像加速）
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

#安装docker(目前官方推荐安装19.03.11)
yum install docker-ce-19.03.11-3.el7 -y

#开机启动
systemctl enable docker

#配置docker镜像以及存储目录(我这里/data目录空间较大，所有把docker存储放在/data目录下)
mkdir -p /etc/docker
cat > /etc/docker/daemon.json<<EOF
{
"exec-opts": ["native.cgroupdriver=systemd"],
"registry-mirrors": ["http://hub-mirror.c.163.com"],
"graph": "/data/docker"
}
EOF

#启动docker
systemctl start docker