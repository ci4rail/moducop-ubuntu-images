# WORK-IN-PROGRESS

This repo contains an early and unfinished attempt to run Ubuntu on ModuCop.
Use at your own risk. Ci4Rail will not provide support.

## Usage



Use a docker container to build the rootfs.

$ ./startdev.sh

# Inside the container
$ make


# TODO

- [x] NetworkManager
- [x] ModemManager
- [x] SIM7906E Modem
- [x] Wifi
- [x] GPS
- [x] Io4Edge Tools 
- [x] Io4Edge Devices (Networkmanager config, dhcpd, udev rules)
- [ ] TTYNVT and -runner
- [ ] SocketCAN Io4Edge and -runner
- [x] Docker with Compose
- [ ] Alsa
- [ ] SDCard Automount
- [ ] Ignition Watcher
- [ ] Chrony

Ubuntu specific
- [ ] cloud-init

OTA
- [ ] Mender
- [ ] Read-only rootfs
- [ ] A/B partitioning

Build
- [ ] Use kernel artifacts from gh packages

## Boot via nfs

setenv autoload no; dhcp; setenv serverip 192.168.24.70; tftp $fdt_addr_r moducop/boot/imx8mm-verdin-wifi-moducop-cpu01.dtb; tftp $kernel_addr_r moducop/boot/Image; setenv bootargs root=/dev/nfs $console nfsroot=$serverip:/srv/fs/moducop,tcp,v3 rw ip=$ipaddr:$serverip:$gatewayip:$netmask:$hostname:$netdev:none ; booti $kernel_addr_r - $fdt_addr_r


