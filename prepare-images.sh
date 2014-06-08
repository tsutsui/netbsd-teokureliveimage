#! /bin/sh

if [ -f REVISION ]; then
	. ./REVISION
fi
if [ "${REVISION}"X = "X" ]; then
	REVISION=`date +%C%y%m%d`
fi

USBMB=3308
RELDIR=./images

dd if=work.i386.usb/liveimage-i386-usb-${REVISION}.img count=${USBMB} bs=1m \
    | gzip -9c > ${RELDIR}/liveimage-i386-usb-${REVISION}.img.gz

dd if=work.amd64.usb/liveimage-amd64-usb-${REVISION}.img count=${USBMB} bs=1m \
    | gzip -9c > ${RELDIR}/liveimage-amd64-usb-${REVISION}.img.gz

gzip -9c work.i386.emu/liveimage-i386-emu-${REVISION}.img \
    > ${RELDIR}/liveimage-i386-emu-${REVISION}.img.gz

gzip -9c work.setupliveimage/setupliveimage-${REVISION}.fs \
    > ${RELDIR}/setupliveimage-${REVISION}.fs.gz
