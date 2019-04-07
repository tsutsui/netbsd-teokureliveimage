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

err()
{
	echo $1 failed!
	exit 1
}

CURDIR=`pwd`
# assume proper symlinks are prepared in ${CURDIR}
NETBSDSRCDIR=${CURDIR}/src
OBJDIR=${CURDIR}
if [ -e ${CURDIR}/obj ]; then
	OBJDIR=${CURDIR}/obj
fi
VDIDIR=${CURDIR}/vdi
VMDKDIR=${CURDIR}/vmdk

# host binaries
AWK=/usr/pkg/bin/gawk	# GNU awk is necessary for "%'d" format
DD=dd
MKDIR=mkdir
RM=rm
#GZIP=/usr/bin/gzip
GZIP=/usr/bin/pigz	# for threads
MD5=/usr/bin/md5
#MD5=/usr/bin/md5sum
SH=/bin/sh
WC=/usr/bin/wc
ZIP=/usr/pkg/bin/zip
#ZIP=/usr/local/bin/zip

# qemu binaries to setup images
QEMU_I386=/usr/pkg/bin/qemu-system-i386
QEMU_X86_64=/usr/pkg/bin/qemu-system-x86_64
QEMU_OPT="-m 1024 -nographic"

# qemu and virtual box binaries to convert images
QEMU_IMG=/usr/pkg/bin/qemu-img
VBOXDIR=${CURDIR}/vbox
VBOX_IMG=${VBOXDIR}/vbox-img

# tooldir settings
_HOST_OSNAME=`uname -s`
_HOST_OSREL=`uname -r`
_HOST_ARCH=`uname -p 2> /dev/null || uname -m`
# XXX see PR toolchain/54100
if [ "${_HOST_ARCH}"X = "x86_64X" ]; then
	_HOST_ARCH=`uname -m`
fi
TOOLDIRNAME=tooldir.${_HOST_OSNAME}-${_HOST_OSREL}-${_HOST_ARCH}

TOOLDIR_I386=${NETBSDSRCDIR}/obj.i386/${TOOLDIRNAME}
TOOLDIR_AMD64=${NETBSDSRCDIR}/obj.amd64/${TOOLDIRNAME}
#TOOLDIR_I386=/usr/tools/i386
#TOOLDIR_AMD64=/usr/tools/x86_64

# image file names
IMAGEDIR=${CURDIR}/images/${REVISION}
IMG_AMD64_QEMU=liveimage-amd64-qemu-${REVISION}.img
IMG_AMD64_USB=liveimage-amd64-usb-${REVISION}.img
IMG_I386_QEMU=liveimage-i386-qemu-${REVISION}.img
IMG_I386_EMU=liveimage-i386-emu-${REVISION}.img
IMG_I386_USB=liveimage-i386-usb-${REVISION}.img
IMG_I386_VDI=liveimage-i386-vbox-${REVISION}.vdi
IMG_I386_VMDK=liveimage-i386-vmdk-${REVISION}.vmdk
IMG_SETUP=setupliveimage-${REVISION}.fs

# image file build dir
WRK_AMD64_QEMU=${OBJDIR}/work.amd64.qemu
WRK_AMD64_USB=${OBJDIR}/work.amd64.usb
WRK_I386_QEMU=${OBJDIR}/work.i386.qemu
WRK_I386_EMU=${OBJDIR}/work.i386.emu
WRK_I386_USB=${OBJDIR}/work.i386.usb
WRK_I386_VDI=${VDIDIR}
WRK_I386_VMDK=${VMDKDIR}
WRK_SETUP=${OBJDIR}/work.setupliveimage

# build "setup liveimage" image
TOOLDIR=${TOOLDIR_I386} OBJDIR=${OBJDIR} ${SH} mksetupliveimage.sh \
    || err mksetupliveimage.sh

# build amd64 USB liveimage
TOOLDIR=${TOOLDIR_AMD64} OBJDIR=${OBJDIR} ${SH} mkimagebuilder.sh amd64 \
    || err 'mkimagebuilder.sh amd64'
TOOLDIR=${TOOLDIR_AMD64} OBJDIR=${OBJDIR} ${SH} mkliveimage.sh usb amd64 \
    || err 'mkliveimage.sh usb amd64'

# build i386 USB/emulator/virtualbox/vmdk images
TOOLDIR=${TOOLDIR_I386} OBJDIR=${OBJDIR} ${SH} mkimagebuilder.sh i386 \
    || err 'mkimagebuilder.sh i386'
TOOLDIR=${TOOLDIR_I386} OBJDIR=${OBJDIR} ${SH} mkliveimage.sh usb i386 \
    || err 'mkliveimage.sh usb i386'
TOOLDIR=${TOOLDIR_I386} OBJDIR=${OBJDIR} ${SH} mkliveimage.sh emu i386 \
    || err 'mkliveimage.sh emu i386'

# setup amd64 USB liveimage
echo Setting up amd64 USB liveimage by QEMU...
${QEMU_X86_64} ${QEMU_OPT} \
 -drive file=${WRK_AMD64_QEMU}/${IMG_AMD64_QEMU},index=0,media=disk,format=raw,cache=unsafe \
 -drive file=${WRK_AMD64_USB}/${IMG_AMD64_USB},index=1,media=disk,format=raw,cache=unsafe \
 -drive file=${WRK_SETUP}/${IMG_SETUP},index=2,media=disk,format=raw,cache=unsafe

# setup i386 USB image
echo Setting up i386 USB liveimage by QEMU...
${QEMU_I386} ${QEMU_OPT} \
 -drive file=${WRK_I386_QEMU}/${IMG_I386_QEMU},index=0,media=disk,format=raw,cache=unsafe \
 -drive file=${WRK_I386_USB}/${IMG_I386_USB},index=1,media=disk,format=raw,cache=unsafe \
 -drive file=${WRK_SETUP}/${IMG_SETUP},index=2,media=disk,format=raw,cache=unsafe

# setup i386 emulator/virtualbox/vmdk images
echo Setting up i386 emulator liveimage by QEMU...
${QEMU_I386} ${QEMU_OPT} \
 -drive file=${WRK_I386_QEMU}/${IMG_I386_QEMU},index=0,media=disk,format=raw,cache=unsafe \
 -drive file=${WRK_I386_EMU}/${IMG_I386_EMU},index=1,media=disk,format=raw,cache=unsafe \
 -drive file=${WRK_SETUP}/${IMG_SETUP},index=2,media=disk,format=raw,cache=unsafe

echo Converting from raw image to vmdk...
${RM} -f ${VDIDIR}/${IMG_I386_VMDK}
${QEMU_IMG} convert -O vmdk \
 ${WRK_I386_EMU}/${IMG_I386_EMU} \
 ${VMDKDIR}/${IMG_I386_VMDK} \
    || err ${QEMU_IMG}

echo Converting from raw image to vdi...
${RM} -f ${VDIDIR}/${IMG_I386_VDI}
#LD_LIBRARY_PATH=${VBOXDIR}/usr/lib/virtualbox \
# ${VBOXDIR}/usr/lib/virtualbox/VBoxManage convertfromraw --format VDI \
# ${WRK_I386_EMU}/${IMG_I386_EMU} \
# ${VDIDIR}/${IMG_I386_VDI}
${VBOX_IMG} convert --srcformat RAW --dstformat VDI \
 --srcfilename ${WRK_I386_EMU}/${IMG_I386_EMU} \
 --dstfilename ${VDIDIR}/${IMG_I386_VDI} \
    || err ${VBOX_IMG}

# prepare compressed images (and omit swap for USB images) for distribution

echo Preparing compressed image files...
IMAGEMB=5120			# 5120MB (4GB isn't enough for 8.0 + 2018Q2)
SWAPMB=512			# 512MB
USBMB=$((${IMAGEMB} - ${SWAPMB}))

${RM} -rf ${IMAGEDIR}
${MKDIR} -p ${IMAGEDIR}

echo Compressing ${IMG_I386_VDI}...
(cd ${VDIDIR} && \
 ${ZIP} -9 ${IMAGEDIR}/`basename ${IMG_I386_VDI} .vdi`.zip  \
  ${IMG_I386_VDI})

echo Compressing liveimage-i386-vmdk-${REVISION}.vmdk...
(cd ${VMDKDIR} && \
 ${ZIP} -9 ${IMAGEDIR}/`basename ${IMG_I386_VMDK} .vmdk`.zip  \
  ${IMG_I386_VMDK})

echo Compressing ${IMG_I386_USB}...
${DD} if=${WRK_I386_USB}/${IMG_I386_USB} count=${USBMB} bs=1m \
    | ${GZIP} -9c > ${IMAGEDIR}/${IMG_I386_USB}.gz

echo Compressing ${IMG_AMD64_USB}...
${DD} if=${WRK_AMD64_USB}/${IMG_AMD64_USB} count=${USBMB} bs=1m \
    | ${GZIP} -9c > ${IMAGEDIR}/${IMG_AMD64_USB}.gz

echo Compressing ${IMG_I386_EMU}...
${GZIP} -9c ${WRK_I386_EMU}/${IMG_I386_EMU} \
    > ${IMAGEDIR}/${IMG_I386_EMU}.gz

echo Compressing setupliveimage-${REVISION}.img...
${GZIP} -9c ${WRK_SETUP}/${IMG_SETUP} \
    > ${IMAGEDIR}/${IMG_SETUP}.gz

echo Calculating distinfo...
IMAGES="${IMG_AMD64_USB}.gz ${IMG_I386_EMU}.gz ${IMG_I386_USB}.gz `basename ${IMG_I386_VDI} .vdi`.zip `basename ${IMG_I386_VMDK} .vmdk`.zip ${IMG_SETUP}.gz"
TARGET=distinfo

rm -f ${IMAGEDIR}/${TARGET}
touch ${IMAGEDIR}/${TARGET}

# Put MD5 and sizes of compressed images
for image in ${IMAGES}; do
echo ${image}
 (cd ${IMAGEDIR} && ${MD5} ${image} >> ${TARGET})
 (cd ${IMAGEDIR} && ${WC} -c ${image} | \
  LANG=ja_JP.UTF-8 ${AWK} '{printf "Size (%s) = %\047d bytes\n","'${image}'",$1 }' >> ${TARGET})
done

# put sizes of uncompressed images
echo >> ${IMAGEDIR}/${TARGET}
#  for ${IMG_AMD64_USB}
 (cd ${WRK_AMD64_USB} && ${WC} -c ${IMG_AMD64_USB} | \
  LANG=ja_JP.UTF-8 ${AWK} '{printf "Size (%s) = %\047d bytes\n","'${IMG_AMD64_USB}'",$1 }' >> ${IMAGEDIR}/${TARGET})
#  for ${IMG_I386_EMU}
 (cd ${WRK_I386_EMU} && ${WC} -c ${IMG_I386_EMU} | \
  LANG=ja_JP.UTF-8 ${AWK} '{printf "Size (%s) = %\047d bytes\n","'${IMG_I386_EMU}'",$1 }' >> ${IMAGEDIR}/${TARGET})
#  for ${IMG_I386_USB}
 (cd ${WRK_I386_USB} && ${WC} -c ${IMG_I386_USB} | \
  LANG=ja_JP.UTF-8 ${AWK} '{printf "Size (%s) = %\047d bytes\n","'${IMG_I386_USB}'",$1 }' >> ${IMAGEDIR}/${TARGET})
#  for ${IMG_I386_VDI}
 (cd ${WRK_I386_VDI} && ${WC} -c ${IMG_I386_VDI} | \
  LANG=ja_JP.UTF-8 ${AWK} '{printf "Size (%s) = %\047d bytes\n","'${IMG_I386_VDI}'",$1 }' >> ${IMAGEDIR}/${TARGET})
#  for ${IMG_I386_VMDK}
 (cd ${WRK_I386_VMDK} && ${WC} -c ${IMG_I386_VMDK} | \
  LANG=ja_JP.UTF-8 ${AWK} '{printf "Size (%s) = %\047d bytes\n","'${IMG_I386_VMDK}'",$1 }' >> ${IMAGEDIR}/${TARGET})
#  for ${IMG_SETUP}
 (cd ${WRK_SETUP} && ${WC} -c ${IMG_SETUP} | \
  LANG=ja_JP.UTF-8 ${AWK} '{printf "Size (%s) = %\047d bytes\n","'${IMG_SETUP}'",$1 }' >> ${IMAGEDIR}/${TARGET})

echo Building ${REVISION} liveimages complete!
