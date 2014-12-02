# Link to the build root tar file.
# It should contain a folder named "target" that has a complete linux system
# with a working C/C++ compiler and boost and libtorrent-rasterbar installed.
BUILDROOT=http://uz.sns.it/~veluca93/LFS_20141127_musl_libtorrent.tar.xz

# Name of the file where we save the buildroot tar.
ROOTFILE=$(notdir ${BUILDROOT})

# Kernel config to use.
# You can either use an existing config, or set the variable "KCUSTOMCONFIG"
# to y to use the default config and then call a make menuconfig in the kernel
# source directory.
KCONFIG=default
KCUSTOMCONFIG=

# Kernel version.
KVERS=3.17.4

# Busybox config to use.
# You can either use an existing config, or set the variable "BCUSTOMCONFIG"
# to y to use the default config and then call a make menuconfig in the 
# busybox build directory
BCONFIG=default
BCUSTOMCONFIG=

# Busybox version.
BVERS=1.22.1

# Parallelism level.
PARALL=8

# xz compression level.
LVL=6

all: sources/linux-${KVERS}/arch/x86_64/boot/bzImage sources/init sources/gettorrent sources/kexec sources/busybox-${BVERS}/busybox
	mkdir -p output
	cp sources/linux-${KVERS}/arch/x86/boot/bzImage output/kernel.img
	mkdir -p initrd
	cp sources/init initrd/
	mkdir initrd/bin -p
	cp sources/gettorrent sources/kexec sources/busybox-${BVERS}/busybox initrd/bin/
	cd initrd && find ./ | cpio -H newc -o | xz -C crc32 --x86 -${LVL} > ../output/initrd.img

${ROOTFILE}: 
	wget ${BUILDROOT} -O ${ROOTFILE}

target: ${ROOTFILE}
	tar xf ${ROOTFILE}

define mount_chroot
	mount -o bind /dev target/dev
	mount -t devpts none target/dev/pts
	mount -t proc none target/proc
	mkdir -p target/build
	mount -o bind sources target/build
endef

define umount_chroot
	-umount -l target/dev/pts
	-umount -l target/dev
	-umount -l target/proc
	-umount -l target/build
endef

config/linux-${KCONFIG}: 
	test -f config/linux-${KCONFIG} || test "y" = "${KCUSTOMCONFIG}" && cp config/linux-default config/linux-${KCONFIG}

sources/linux-${KVERS}.tar.xz: 
	wget https://kernel.org/pub/linux/kernel/v3.x/linux-${KVERS}.tar.xz -O sources/linux-${KVERS}.tar.xz

sources/linux-${KVERS}: sources/linux-${KVERS}.tar.xz 
	tar xf sources/linux-${KVERS}.tar.xz -C sources/

sources/linux-${KVERS}/arch/x86_64/boot/bzImage: sources/linux-${KVERS} target config/linux-${KCONFIG} Makefile 
	$(mount_chroot)
	cp config/linux-${KCONFIG} sources/linux-${KVERS}/.config
	chroot target /bin/bash -c "cd /build/linux-${KVERS}; yes '' | make -j${PARALL} oldconfig"
	test "y" != "${KCUSTOMCONFIG}" || chroot target /bin/bash -c "cd /build/linux-${KVERS}; make -j${PARALL} menuconfig" && cp sources/linux-${KVERS}/.config config/linux-${KCONFIG}
	chroot target /bin/bash -c "cd /build/linux-${KVERS}; yes '' | make -j${PARALL}"
	$(umount_chroot)

config/busybox-${BCONFIG}: 
	test -f config/busybox-${BCONFIG} || test "y" = "${BCUSTOMCONFIG}" && cp config/busybox-default config/busybox-${BCONFIG}

sources/busybox-${BVERS}.tar.bz2: 
	wget http://busybox.net/downloads/busybox-${BVERS}.tar.bz2 -O sources/busybox-${BVERS}.tar.bz2

sources/busybox-${BVERS}: sources/busybox-${BVERS}.tar.bz2
	tar xf sources/busybox-${BVERS}.tar.bz2 -C sources/

sources/busybox-${BVERS}/busybox: sources/busybox-${BVERS} target config/busybox-${BCONFIG} Makefile
	$(mount_chroot)
	cp config/busybox-${BCONFIG} sources/busybox-${BVERS}/.config
	chroot target /bin/bash -c "cd /build/busybox-${BVERS}; yes '' | make -j${PARALL} oldconfig"
	test "y" != "${BCUSTOMCONFIG}" || chroot target /bin/bash -c "cd /build/busybox-${BVERS}; make -j${PARALL} menuconfig" && cp sources/busybox-${BVERS}/.config config/busybox-${BCONFIG}
	chroot target /bin/bash -c "cd /build/busybox-${BVERS}; yes '' | make -j${PARALL}"
	$(umount_chroot)

sources/gettorrent:
	$(mount_chroot)
	chroot target g++ -static -Os -flto -fwhole-program /build/gettorrent.cpp -ltorrent-rasterbar -lboost_system -lc -o /build/gettorrent
	chroot target strip /build/gettorrent
	$(umount_chroot)

sources/kexec:
	$(mount_chroot)
	chroot target gcc -static -Os -flto -fwhole-program /build/kexec.c -o /build/kexec
	chroot target strip /build/kexec
	$(umount_chroot)

clean:
	$(umount_chroot)
	rm -rf target output sources/busybox-${BVERS}.tar.bz2 sources/busybox-${BVERS} sources/linux-${KVERS} sources/linux-${KVERS}.tar.xz LFS_20141127_musl_libtorrent.tar.xz
