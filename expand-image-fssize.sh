#! /bin/sh
#
# Copyright (c) 2013, 2023 Izumi Tsutsui.  All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

BOOTDISK=$(dmesg -t | sed -n -e '/^boot device: /s/.*: //p' | tail -1)

echo Start expanding fs size upto the actual disk size...

# make sure we are on ${BOOTDISK} on root
ROOTDEV=$(sysctl -n kern.root_device)

case "${ROOTDEV}" in
(dk[0-9]*)
	USE_GPT=yes
	BLOCKDEV=$(dkctl ${ROOTDEV} getwedgeinfo | head -1 | sed 's/://' | awk '{print $3}')
	ROOTPART=${ROOTDEV}
	;;
(*)
	USE_GPT=no
	BLOCKDEV=${ROOTDEV}
	ROOTPART=${ROOTDEV}a
	;;
esac

if [ "${BLOCKDEV}"X != "${BOOTDISK}"X ] ; then
	echo "Error: root file system device (${BLOCKDEV}) is not ${BOOTDISK}"
	exit 1
fi

# make sure target disk is not mounted
if (mount | grep -q ^/dev/${ROOTPART}) ; then
	echo Error: /dev/${ROOTPART} is already mounted
	exit 1
fi

# get actual disk size from dmesg
BOOTDISKDMSG=$(dmesg -t | grep "^${BOOTDISK}: .* sectors$" | tail -1)
if [ "${BOOTDISKDMSG}"X = "X" ]; then
	echo Error: cannot find ${BOOTDISK} in dmesg
	exit 1
fi

IMAGESECTORS=$(echo ${BOOTDISKDMSG} | awk '{print $(NF-1)}')

ORIGIMAGEMB=5120
ORIGSWAPMB=512
ORIGGPTMB=1

ORIGIMAGESECTORS=$((${ORIGIMAGEMB} * 1024 * 1024 / 512))
ORIGSWAPSECTORS=$((${ORIGSWAPMB} * 1024 * 1024 / 512))
ORIGGPTSECTORS=$((${ORIGGPTMB} * 1024 * 1024 / 512))

if [ "${USE_GPT}" = "yes" ]; then

GPTROOTLABEL=TeokureLiveImage_root
GPTSWAPLABEL=TeokureLiveImage_swap

# check label names
ROOTLABEL=$(gpt show -i 2 ${BLOCKDEV} | grep ^Label: | sed -e 's/Label: //g')
SWAPLABEL=$(gpt show -i 3 ${BLOCKDEV} | grep ^Label: | sed -e 's/Label: //g')
if [ "${ROOTLABEL}"X != "${GPTROOTLABEL}"X ]; then
	echo Error: unexpected root label : \"${ROOTLABEL}\"
	exit 1
fi
if [ "${SWAPLABEL}"X != "${GPTSWAPLABEL}"X ]; then
	echo Error: unexpected swap label : \"${SWAPLABEL}\"
	exit 1
fi

echo ${GPTROOTLABEL} found in ${BOOTDISK} GPT partition.

LASTSECTORS=$(($(gpt show ${BLOCKDEV} | grep 'Sec GPT header' | awk '{print $1}') + 1))

if [ ${LASTSECTORS} -ne ${ORIGIMAGESECTORS} ]; then
	echo Error: unexpected image size in GPT partition : ${LASTSECTORS}
	echo Expected original image size: ${ORIGIMAGESECTORS}
	exit 1
fi

echo Original image size: ${ORIGIMAGESECTORS} sectors
echo Target ${BLOCKDEV} disk size: ${IMAGESECTORS} sectors

if [ ${ORIGIMAGESECTORS} -gt ${IMAGESECTORS} ]; then
	echo Error: ${BLOCKDEV} is too small?
	exit 1
fi

# calculate new disk parameters
SWAPSECTORS=${ORIGSWAPSECTORS}
SWAPOFFSET=$((${IMAGESECTORS} - ${ORIGGPTSECTORS} - ${ORIGSWAPSECTORS}))

# check original fs
echo Checking file system...
fsck_ffs -p /dev/r${ROOTPART}

# update GPT partitions
echo Updating GPT partitions...
gpt resizedisk ${BLOCKDEV}
gpt remove -i 3 ${BLOCKDEV}		# remove original swap partitoin
gpt add -a 1m -b ${SWAPOFFSET} -s ${SWAPSECTORS} -i 3 \
    -t swap -l ${SWAPLABEL} ${BLOCKDEV}	# add new swap partition at the end
gpt resize -i 2 ${BLOCKDEV}		# expand FFS partition

else # "${USE_GPT}" = "no"

# mount tmpfs to create work file
if ! (mount | grep -q '^tmpfs on /tmp') ; then
	mount_tmpfs -s 1M tmpfs /tmp
fi

# get current disklabel
disklabel -r ${BOOTDISK} > /tmp/disklabel.${BOOTDISK}

# check disk name in disklabel
DISKNAME=$(sed -n -e '/^disk: /s/.*: //p' /tmp/disklabel.${BOOTDISK})
if [ "${DISKNAME}"X != "TeokureLiveImage"X ]; then
	echo Error: unexpected disk name: ${DISKNAME}
	exit 1
fi

echo ${DISKNAME} found in ${BOOTDISK} disklabel.

# get MBR label
fdisk -S ${BOOTDISK} > /tmp/mbrlabel.${BOOTDISK}
. /tmp/mbrlabel.${BOOTDISK}

# check MBR part id
if [ ${PART0ID} != "169" ]; then
	echo Error: unexpected MBR partition ID: ${PART0ID}
	exit 1
fi

# check fdisk partition size
PART0END=$((${PART0START} + ${PART0SIZE}))
if [ ${PART0END} -ne ${ORIGIMAGESECTORS} ]; then
	echo Error: unexpected MBR partition size: ${PART0END}
	echo Expected original image size: ${ORIGIMAGESECTORS}
	exit 1
fi

# check original image size in label
TOTALSECTORS=$(sed -n -e '/^total sectors: /s/.*: //p' /tmp/disklabel.${BOOTDISK})
if [ ${TOTALSECTORS} -ne ${ORIGIMAGESECTORS} ]; then
	echo Error: unexpected total sectors in disklabel: ${TOTALSECTORS}
	echo Expected original total sectors: ${ORIGIMAGESECTORS}
	exit 1
fi

echo Original image size: ${ORIGIMAGESECTORS} sectors
echo Target ${BOOTDISK} disk size: ${IMAGESECTORS} sectors

if [ ${ORIGIMAGESECTORS} -gt ${IMAGESECTORS} ]; then
	echo Error: ${BOOTDISK} is too small?
	exit 1
fi

# calculate new disk parameters
SWAPSECTORS=${ORIGSWAPSECTORS}

FSOFFSET=${PART0START}
BSDPARTSECTORS=$((${IMAGESECTORS} - ${FSOFFSET}))
FSSECTORS=$((${IMAGESECTORS} - ${SWAPSECTORS} - ${FSOFFSET}))
SWAPOFFSET=$((${FSOFFSET} + ${FSSECTORS}))
HEADS=64
SECTORS=32
CYLINDERS=$((${IMAGESECTORS} / (${HEADS} * ${SECTORS} ) ))

MBRCYLINDERS=$((${IMAGESECTORS} / ( ${BHEAD} * ${BSEC} ) ))

# prepare new disklabel proto
sed -e "s/^cylinders: [0-9]*$/cylinders: ${CYLINDERS}/" \
    -e "s/^total sectors: [0-9]*$/total sectors: ${IMAGESECTORS}/" \
    -e "s/^ a:  *[0-9]* *[0-9]* / a: ${FSSECTORS} ${FSOFFSET} /" \
    -e "s/^ b:  *[0-9]* *[0-9]* / b: ${SWAPSECTORS} ${SWAPOFFSET} /" \
    -e "s/^ c:  *[0-9]* *[0-9]* / c: ${BSDPARTSECTORS} ${FSOFFSET} /" \
    -e "s/^ d:  *[0-9]* / d: ${IMAGESECTORS} /" \
    /tmp/disklabel.${BOOTDISK} > /tmp/disklabel.${BOOTDISK}.new

# check original fs
echo Checking file system...
fsck_ffs -p /dev/r${ROOTPART}

# update MBR label
echo Updating partition size in MBR label...
fdisk -f -u -b ${MBRCYLINDERS}/${BHEAD}/${BSEC} \
    -0 -s ${PART0ID}/${FSOFFSET}/${BSDPARTSECTORS} \
    ${BOOTDISK}

# write updated disklabel
echo Updating partition size in disklabel...
disklabel -R ${BOOTDISK} /tmp/disklabel.${BOOTDISK}.new

fi # "${USE_GPT}" = "yes"

# update fs size
echo Perform resize_ffs...
resize_ffs -p -y /dev/r${ROOTPART}
echo Done!
echo
echo Hit Enter to reboot...
read key
exec reboot
