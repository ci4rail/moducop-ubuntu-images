Use a docker container to build the rootfs.

docker run -it -v`pwd`:/work -v`pwd`/../yocto-images-dunfell:/yocto-images  ubuntu:22.04

# Inside docker shell
cd /work
./install_tools.sh
make 


# TODO

- [x] NetworkManager
- [x] ModemManager
- [ ] SIM7906E Modem
- [ ] Wifi
- [ ] GPS
- [ ] Io4Edge Tools 
- [ ] Io4Edge Devices (Networkmanager config, dhcpd, udev rules)
- [ ] TTYNVT and -runner
- [ ] SocketCAN Io4Edge and -runner
- [ ] Docker with Compose
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