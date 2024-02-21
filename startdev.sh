#! /bin/bash
docker run -it -v`pwd`:/work -v`pwd`/../yocto-images-dunfell:/yocto-images  ubuntu:22.04 /bin/sh -c 'cd /work && ./install_tools.sh && exec /bin/bash'