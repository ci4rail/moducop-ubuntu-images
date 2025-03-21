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
      dhcp4: yes
EOF
