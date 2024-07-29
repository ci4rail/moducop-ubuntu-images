#! /bin/bash
#
# This script is executed in a chroot environment on the target's rootfs.
#

source /root/postinst-includes/base.sh

# create /etc/netplan/01-eth.yam:
cat <<EOF > /etc/netplan/01-eth.yaml
network:
  version: 2
  renderer: NetworkManager
  ethernets:
    eth0: 
      dhcp4: false
      addresses: [192.168.24.174/24] 
      gateway4: 192.168.24.1 
      nameservers:
        addresses: [8.8.8.8,8.8.4.4,192.168.24.1]
EOF
