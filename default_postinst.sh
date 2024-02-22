#
# This script is executed in a chroot environment on the target's rootfs.
#
set -x 
set -e

# Additional package sources
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
curl -fsSL https://downloads.mender.io/repos/debian/gpg -o /etc/apt/trusted.gpg.d/mender.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
echo "deb [arch=$(dpkg --print-architecture)] https://downloads.mender.io/repos/debian ubuntu/jammy/stable main" |\
  tee /etc/apt/sources.list.d/mender.list > /dev/null

# mender-client needs to know the device type
export DEVICE_TYPE=ubuntu-moducop-cpu01

# install packages
# logrotate is needed for log rotation
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt -y --no-install-recommends install \
    linux-firmware \
    wpasupplicant \
    network-manager \
    modemmanager \
    logrotate \
    gpsd gpsd-tools  \
    docker-ce docker-ce-cli containerd.io docker-compose-plugin \
    net-tools iputils-ping netcat \
    nano \
    dnsmasq-base \
    wireless-regdb \
    fuse-overlayfs \
    avahi-daemon avahi-utils \
    isc-dhcp-server \
    mender-client4 \
    mender-connect \
    mender-configure \

# prevent the Mender client from upgrading when upgrading the rest of the system
apt-mark hold mender-auth
apt-mark hold mender-update
apt-mark hold mender-client

# The docker installer uses iptables for nat. Unfortunately Debian uses nftables. 
# Setup Debian to use the legacy iptables.
update-alternatives --set iptables /usr/sbin/iptables-legacy
update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

# WIFI Chipset firmware
# The kernel 5.6.x driver still uses the old name, provide a symlink for older kernels
(cd /usr/lib/firmware && ln -fs sdsd8997_combo_v4.bin sd8997_uapsta.bin)

# We don't want unattended upgrades
apt -y remove unattended-upgrades

# limit journald size
sed -i 's/#SystemMaxUse=/SystemMaxUse=50M/' /etc/systemd/journald.conf

# permit ssh root login
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# generate ssh host keys (TODO: should this be done in the image build process?)
ssh-keygen -A

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

cat <<EOF > /etc/default/gpsd
START_DAEMON="false"

# -n = don't wait for clients. Poll GPS device from the start. Required to provide time to chrony
# -G = Allow non-local connections (restricted by iptable settings in gpsd.socket) ???
#
GPSD_OPTIONS="-G -n"

#
# No devices need to be provided here.
# Due to USBAUTO="true", gpsd will be triggered by udev when USB GPS devices are attached
#
DEVICES=""
USBAUTO="true"
GPSD_SOCKET="/var/run/gpsd.sock"
EOF

# dont wait for network
systemctl mask NetworkManager-wait-online.service

# deactivate cloud-init service
touch /etc/cloud/cloud-init.disabled

# change password algorithm to sha512
sed -i 's/pam_unix.so obscure yescrypt/pam_unix.so obscure sha512/' /etc/pam.d/common-password

# change root password
echo "root:ci" | chpasswd

#-----------------------------------
# IO4Edge devices

wget https://github.com/ci4rail/io4edge-client-go/releases/download/v1.7.0/io4edge-cli-v1.7.0-linux-arm64.tar.gz && \
tar -C /usr/local/bin -xvf io4edge-cli-v1.7.0-linux-arm64.tar.gz io4edge-cli && \
rm io4edge-cli-v1.7.0-linux-arm64.tar.gz

# USB io4edge devices udev rules
echo 'ACTION=="add", ATTRS{interface}=="TinyUSB Network", PROGRAM="/usr/bin/usb_io4edge_interface_name.sh %k", NAME="%c"' > /etc/udev/rules.d/99-usb-io4edge.rules

cat <<EOF > /usr/bin/usb_io4edge_interface_name.sh 
#!/bin/sh

USB_PATH=\$(readlink /sys/class/net/\$1)

USB_PORT=\$(echo \$USB_PATH | awk -F/ '{print\$(NF-3)}')

case \$USB_PORT in

  1-1.4.1)
    echo "usb_ext1"
    ;;

  1-1.4.2)
    echo "usb_ext2"
    ;;

  1-1.4.4)
    echo "usb_ext3"
    ;;

  1-1.4.3)
    echo "usb_ext4"
    ;;

  1-1.3.1)
    echo "usb_ext5"
    ;;

  1-1.3.3)
    echo "usb_ext6"
    ;;

  1-1.3.2)
    echo "usb_ext7"
    ;;

  1-1.3.4)
    echo "usb_ext8"
    ;;

  1-1.2.1)
    echo "usb_io_ctrl"
    ;;

  *)
    echo "unknown"
    ;;

esac
EOF
chmod +x /usr/bin/usb_io4edge_interface_name.sh

cat <<EOF > /etc/netplan/10-usb-ext.yaml
network:
  version: 2
  renderer: NetworkManager
  ethernets:
    usb_io_ctrl:
      dhcp4: false
      addresses: [192.168.200.10/24]
    usb_ext1:
      dhcp4: false
      addresses: [192.168.201.10/24]
    usb_ext2:
      dhcp4: false
      addresses: [192.168.202.10/24]
    usb_ext3:
      dhcp4: false
      addresses: [192.168.203.10/24]
    usb_ext4:
      dhcp4: false
      addresses: [192.168.204.10/24]
    usb_ext5:
      dhcp4: false
      addresses: [192.168.205.10/24]
    usb_ext6:
      dhcp4: false
      addresses: [192.168.206.10/24]
    usb_ext7:
      dhcp4: false
      addresses: [192.168.207.10/24]
    usb_ext8:
      dhcp4: false
      addresses: [192.168.208.10/24]
EOF

cat <<EOF > /etc/dhcp/dhcpd.conf
ddns-update-style none;

# option definitions common to all supported networks... (not relevant for this snippet)
option domain-name "example.org";
option domain-name-servers ns1.example.org, ns2.example.org;

default-lease-time 600;
max-lease-time 7200;

subnet 192.168.200.0 netmask 255.255.255.0 {
    range 192.168.200.1 192.168.200.1;
}

subnet 192.168.201.0 netmask 255.255.255.0 {
    range 192.168.201.1 192.168.201.1;
}

subnet 192.168.202.0 netmask 255.255.255.0 {
    range 192.168.202.1 192.168.202.1;
}

subnet 192.168.203.0 netmask 255.255.255.0 {
    range 192.168.203.1 192.168.203.1;
}

subnet 192.168.204.0 netmask 255.255.255.0 {
    range 192.168.204.1 192.168.204.1;
}

subnet 192.168.205.0 netmask 255.255.255.0 {
    range 192.168.205.1 192.168.205.1;
}

subnet 192.168.206.0 netmask 255.255.255.0 {
    range 192.168.206.1 192.168.206.1;
}

subnet 192.168.207.0 netmask 255.255.255.0 {
    range 192.168.207.1 192.168.207.1;
}

subnet 192.168.208.0 netmask 255.255.255.0 {
    range 192.168.208.1 192.168.208.1;
}

# subnet for enp5s0 (eth2)
subnet 192.168.25.0 netmask 255.255.255.0 {
    range 192.168.25.1 192.168.25.98;
}
EOF

cat <<EOF > /etc/default/isc-dhcp-server
INTERFACESv4="usb_io_ctrl usb_ext1 usb_ext2 usb_ext3 usb_ext4 usb_ext5 usb_ext6 usb_ext7 usb_ext8"
EOF

cat <<EOF > /etc/NetworkManager/dispatcher.d/10-dhcpd-restart
#!/bin/bash
#
# This script restarts the DHDCP daemon whenever a network interface
# listed in /etc/default/dhcp-server comes up.
# This is needed to provide USB attached
# io4edge devices with an IP address whenever they are restarted.
#
# Also needed for point-to-point Ethernet connections, that have no link initially.
#

interface=\$1 status=\$2

echo "10-dhcpd-restart running with \$interface and \$status"
if [[ "\$2" == "up" ]]; then
  if [[ \$(grep "\$1" /etc/default/isc-dhcp-server | grep "INTERFACESv4") ]]; then
    echo "Restarting dhcpd"
    systemctl restart isc-dhcp-server
  fi
fi
EOF
chmod +x /etc/NetworkManager/dispatcher.d/10-dhcpd-restart

#-----------------------------------
# Mender
cat <<EOF >/etc/mender/mender-connect.conf
{
    "ShellCommand": "/bin/bash",
    "User": "root",
    "Sessions": {
        "ExpireAfterIdle": 300,
        "MaxPerUser": 5,
        "StopExpired": true
    }
}
EOF