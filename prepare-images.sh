#! /bin/sh

REVISION=20130119
USBMB=3308
RELDIR=./images

dd if=work.i386.usb/liveimage-i386-usb-${REVISION}.img count=${USBMB} bs=1m \
    | gzip -9c > ${RELDIR}/liveimage-i386-usb-${REVISION}.img.gz

dd if=work.amd64.usb/liveimage-amd64-usb-${REVISION}.img count=${USBMB} bs=1m \
    | gzip -9c > ${RELDIR}/liveimage-amd64-usb-${REVISION}.img.gz

gzip -9c work.i386.emu/liveimage-i386-emu-${REVISION}.img \
    > ${RELDIR}/liveimage-i386-emu-${REVISION}.img.gz

gzip -9c ./setupliveimage-${REVISION}.fs \
    > ${RELDIR}/setupliveimage-${REVISION}.fs.gz
