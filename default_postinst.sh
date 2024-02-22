#
# This script is executed in a chroot environment on the target's rootfs.
#
set -x 
set -e

# Additional package sources
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

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
      addresses: [192.168.24.15/24] 
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

# DHCP server for USB IO4Edge devices
cat <<EOF > /etc/NetworkManager/conf.d/00-use-dnsmasq.conf
[main]
dns=dnsmasq
EOF

cat <<EOF > /etc/NetworkManager/dnsmasq.d/usb_io4edge.conf
domain=usb_io_ctrl.lan,192.168.200.0/24,local
interface=usb_io_ctrl
dhcp-authoritative
dhcp-option=1,255.255.255.0
dhcp-option=3,192.168.200.10
dhcp-option=6,192.168.200.10
dhcp-range=tag:usb_io_ctrl,192.168.200.1,192.168.200.1,24h

# TODO: only the present interfaces should be configured. Otherwise dnsmasq will fail to start
# domain=usb_ext1.lan,192.168.201.0/24,local
# interface=usb_ext1
# dhcp-authoritative
# dhcp-option=1,255.255.255.0
# dhcp-option=3,192.168.201.10
# dhcp-option=6,192.168.201.10
# dhcp-range=tag:usb_ext1,192.168.201.1,192.168.201.1,24h

# TODO: add more usb_extX interfaces
EOF
