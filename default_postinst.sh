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
    wireless-regdb
    
#fuse-overlayfs

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

