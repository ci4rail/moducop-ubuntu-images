#
# Makefile to build rootfs based on an ubuntu ISO image
#
# The following variable may be overwritten on the command line
# .e.g. make ISO_URL=... VARIANT=...

# The ubuntu ISO image to use
ISO_URL ?= https://cdimage.ubuntu.com/releases/22.04/release/ubuntu-22.04.3-live-server-arm64.iso

# Location of the squashed rootfs in the ISO image
SQUASHED_FS ?= casper/ubuntu-server-minimal.squashfs

# The variant that we are building
# Different variants are built in different directories
# Each variant has its own install script <variant>_postinst.sh
VARIANT ?= default

# The project and package version of the kernel packages
KERNEL_PACKAGES_PATH ?= /yocto-images/cpu01-edgefarm-devtools-image/install
#KERNEL_PACKAGES_VERSION ?= 1.0.0

# The BSP version to write into /etc/bsp.version
BSP_VERSION ?= local-build

KERNEL_ARTIFACT_PREFIX = ac370

#---------
# Build directory for variant
BUILD_DIR := ${VARIANT}_build

# Where the rootfs will be built
ROOTFS_DIR := ${BUILD_DIR}/rootfs

build: ${BUILD_DIR}/rootfs.tgz


${BUILD_DIR}:
	@mkdir -p ${BUILD_DIR}

# Download the ISO image
${BUILD_DIR}/base.iso: | ${BUILD_DIR}
	@echo "=== Downloading ISO Image ==="
	curl -f -L -o ${BUILD_DIR}/base.iso ${ISO_URL}

# extract the squashfs from the ISO image
${BUILD_DIR}/squashfs: ${BUILD_DIR}/base.iso
	@echo "=== Extracting Squashfs from ISO ==="
	7z x ${BUILD_DIR}/base.iso ${SQUASHED_FS} -so > ${BUILD_DIR}/squashfs

# extract the rootfs from the squashfs
${ROOTFS_DIR}: ${BUILD_DIR}/squashfs
	@echo "=== Unsquashing Rootfs ==="
	@rm -rf ${ROOTFS_DIR} ${BUILD_DIR}/.postinst.done
	unsquashfs -d ${ROOTFS_DIR} ${BUILD_DIR}/squashfs

# prepare for qemu chroot
${ROOTFS_DIR}/usr/bin/qemu-aarch64-static: | ${ROOTFS_DIR}
	@cp /usr/bin/qemu-aarch64-static ${ROOTFS_DIR}/usr/bin

# chroot into the rootfs and run the install script
${BUILD_DIR}/.postinst.done: ${VARIANT}_postinst.sh
	@mv ${ROOTFS_DIR}/etc/resolv.conf ${ROOTFS_DIR}/etc/resolv.conf.bak
	@echo "nameserver 8.8.8.8" > ${ROOTFS_DIR}/etc/resolv.conf
	@echo "=== Running Post Install Script ==="
	@cp ${VARIANT}_postinst.sh ${ROOTFS_DIR}/root/postinst.sh && chmod +x ${ROOTFS_DIR}/root/postinst.sh
	@chroot ${ROOTFS_DIR} /root/postinst.sh
	@mv ${ROOTFS_DIR}/etc/resolv.conf.bak ${ROOTFS_DIR}/etc/resolv.conf
	@touch $@

# Install kernel, dtb and modules
${ROOTFS_DIR}/boot/Image: ${ROOTFS_DIR} 
	@echo "=== Installing Kernel Image/DTB and modules ==="
	gunzip -c ${KERNEL_PACKAGES_PATH}/images/moducop-cpu01/Image.gz > ${ROOTFS_DIR}/boot/Image
	tar -C ${ROOTFS_DIR}/usr -xzf ${KERNEL_PACKAGES_PATH}/images/moducop-cpu01/modules-moducop-cpu01.tgz
	@cp depmod.sh ${ROOTFS_DIR}/root && chmod +x ${ROOTFS_DIR}/root/depmod.sh
	@chroot ${ROOTFS_DIR} /root/depmod.sh
	cp -L ${KERNEL_PACKAGES_PATH}/images/moducop-cpu01/imx8mm-verdin-wifi-moducop-cpu01.dtb ${ROOTFS_DIR}/boot/

# create BSP version file
${ROOTFS_DIR}/etc/bsp.version:
	@echo "=== Creating BSP Version File ==="
	@echo "BSP_VERSION=${BSP_VERSION}\nBSP_VARIANT=${VARIANT}" > $@

# create the rootfs tarball
${BUILD_DIR}/rootfs.tgz: ${ROOTFS_DIR}/boot/Image ${ROOTFS_DIR}/usr/bin/qemu-aarch64-static ${ROOTFS_DIR}/etc/bsp.version ${BUILD_DIR}/.postinst.done
	@rm -f ${ROOTFS_DIR}/usr/bin/qemu-aarch64-static ${ROOTFS_DIR}/root/postinst.sh
	@echo "=== Creating Rootfs Tarball ==="
	tar -C ${ROOTFS_DIR} -czf ${BUILD_DIR}/rootfs.tgz .

clean:
	rm -rf ${BUILD_DIR}

.PHONY: build clean