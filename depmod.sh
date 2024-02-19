#
# This script is executed in a chroot environment on the target's rootfs.
#
set -x 
set -e

ls /usr/lib/modules
ver=$(ls /usr/lib/modules)
depmod -a $ver
