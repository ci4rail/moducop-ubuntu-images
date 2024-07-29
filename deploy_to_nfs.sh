#! /bin/bash
SERVER_IP="192.168.24.70"

ssh ${SERVER_IP} "cd /srv/fs && sudo rm -rf moducop && sudo mkdir -p moducop && sudo chmod 777 moducop && cd moducop && sudo tar xzf -" < nfsboot_build/rootfs.tgz