#! /bin/sh
#
# a stupid script to automate building images
#

if [ -f REVISION ]; then
	. ./REVISION
fi
if [ "${REVISION}"X = "X" ]; then
	REVISION=`date +%C%y%m%d`
fi

CURDIR=`pwd`
# assume proper symlinks are prepared in ${CURDIR}
NETBSDSRCDIR=${CURDIR}/src
VBOXDIR=${CURDIR}/vbox
VDIDIR=${CURDIR}/vdi
VMDKDIR=${CURDIR}/vmdk

#GZIP=/usr/bin/gzip
GZIP=/usr/bin/pigz	# for threads
MD5=/usr/bin/md5
#MD5=/usr/bin/md5sum
SH=/bin/sh
ZIP=/usr/pkg/bin/zip
#ZIP=/usr/local/bin/zip

QEMU_I386=/usr/pkg/bin/qemu-system-i386
QEMU_X86_64=/usr/pkg/bin/qemu-system-x86_64
QEMU_IMG=/usr/pkg/bin/qemu-img

_HOST_OSNAME=`uname -s`
_HOST_OSREL=`uname -r`
_HOST_ARCH=`uname -p 2> /dev/null || uname -m`
TOOLDIRNAME=tooldir.${_HOST_OSNAME}-${_HOST_OSREL}-${_HOST_ARCH}

TOOLDIR_I386=${NETBSDSRCDIR}/obj.i386/${TOOLDIRNAME}
TOOLDIR_AMD64=${NETBSDSRCDIR}/obj.amd64/${TOOLDIRNAME}
#TOOLDIR_I386=/usr/tools/i386
#TOOLDIR_AMD64=/usr/tools/x86_64

# build "setup liveimage" image
TOOLDIR=${TOOLDIR_I386} ${SH} mksetupliveimage.sh

# build and setup amd64 USB liveimage
TOOLDIR=${TOOLDIR_AMD64} ${SH} mkimagebuilder.sh amd64
TOOLDIR=${TOOLDIR_AMD64} ${SH} mkliveimage.sh usb amd64
${QEMU_X86_64} -m 512 \
 -hda work.amd64.qemu/liveimage-amd64-qemu-${REVISION}.img \
 -hdb work.amd64.usb/liveimage-amd64-usb-${REVISION}.img \
 -hdc setupliveimage-${REVISION}.fs

# build and setup i386 USB/emulator/virtualbox(with vesa xorg.conf)/vmdk images
rm -f ${VDIDIR}/liveimage-i386-vbox-${REVISION}.vdi
TOOLDIR=${TOOLDIR_I386} ${SH} mkimagebuilder.sh i386
TOOLDIR=${TOOLDIR_I386} ${SH} mkliveimage.sh usb i386
TOOLDIR=${TOOLDIR_I386} ${SH} mkliveimage.sh emu i386
cp work.i386.emu/liveimage-i386-emu-${REVISION}.img \
   work.i386.emu/liveimage-i386-vbox-${REVISION}.img
${QEMU_I386} -m 512 \
 -hda work.i386.qemu/liveimage-i386-qemu-${REVISION}.img \
 -hdb work.i386.usb/liveimage-i386-usb-${REVISION}.img \
 -hdc setupliveimage-${REVISION}.fs
${QEMU_I386} -m 512 \
 -hda work.i386.qemu/liveimage-i386-qemu-${REVISION}.img \
 -hdb work.i386.emu/liveimage-i386-emu-${REVISION}.img \
 -hdc setupliveimage-${REVISION}.fs
${QEMU_IMG} convert -O vmdk \
 work.i386.emu/liveimage-i386-emu-${REVISION}.img \
 ${VMDKDIR}/liveimage-i386-vmdk-${REVISION}.vmdk
${QEMU_I386} -m 512 \
 -hda work.i386.qemu/liveimage-i386-qemu-${REVISION}.img \
 -hdb work.i386.emu/liveimage-i386-vbox-${REVISION}.img \
 -hdc setupliveimage-${REVISION}.fs \
 -net nic,model=virtio
LD_LIBRARY_PATH=${VBOXDIR}/usr/lib/virtualbox \
 ${VBOXDIR}/usr/lib/virtualbox/VBoxManage convertfromraw --format VDI \
 work.i386.emu/liveimage-i386-vbox-${REVISION}.img \
 ${VDIDIR}/liveimage-i386-vbox-${REVISION}.vdi

# prepare compressed images (and omit swap for USB images) for distribution

USBMB=3308
IMAGEDIR=${CURDIR}/images

(cd ${VDIDIR} && \
 ${ZIP} -9 ${IMAGEDIR}/liveimage-i386-vbox-${REVISION}.zip  \
  liveimage-i386-vbox-${REVISION}.vdi)

(cd ${VMDKDIR} && \
 ${ZIP} -9 ${IMAGEDIR}/liveimage-i386-vmdk-${REVISION}.zip  \
  liveimage-i386-vmdk-${REVISION}.vmdk)

dd if=work.i386.usb/liveimage-i386-usb-${REVISION}.img count=${USBMB} bs=1m \
    | ${GZIP} -9c > ${IMAGEDIR}/liveimage-i386-usb-${REVISION}.img.gz

dd if=work.amd64.usb/liveimage-amd64-usb-${REVISION}.img count=${USBMB} bs=1m \
    | ${GZIP} -9c > ${IMAGEDIR}/liveimage-amd64-usb-${REVISION}.img.gz

${GZIP} -9c work.i386.emu/liveimage-i386-emu-${REVISION}.img \
    > ${IMAGEDIR}/liveimage-i386-emu-${REVISION}.img.gz

${GZIP} -9c ${CURDIR}/setupliveimage-${REVISION}.fs \
    > ${IMAGEDIR}/setupliveimage-${REVISION}.fs.gz

(cd ${IMAGEDIR} && ${MD5} \
  liveimage-amd64-usb-${REVISION}.img.gz \
  liveimage-i386-emu-${REVISION}.img.gz \
  liveimage-i386-usb-${REVISION}.img.gz \
  liveimage-i386-vbox-${REVISION}.zip \
  liveimage-i386-vmdk-${REVISION}.zip \
  setupliveimage-${REVISION}.fs.gz \
   > MD5)
