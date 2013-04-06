#! /bin/sh
#
# Copyright (c) 2012, 2013 Izumi Tsutsui.  All rights reserved.
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

if [ -f REVISION ]; then
	. ./REVISION
fi
if [ "${REVISION}"X = "X" ]; then
	REVISION=`date +%C%y%m%d`
fi

# source and target
INSTSH=inst.sh
FILESDIR=liveimagefiles
IMAGE=setupliveimage-${REVISION}.fs
WORKDIR=/tmp

# tools binaries
MACHINE_ARCH=i386
TOOLDIR=/usr/tools/${MACHINE_ARCH}
DISKLABEL=${TOOLDIR}/bin/nbdisklabel-${MACHINE}
MAKEFS=${TOOLDIR}/bin/nbmakefs

#
# target image size settings
#
FSMB=800
FSSECTORS=$((${FSMB} * 1024 * 1024 / 512))
FSSIZE=$((${FSSECTORS} * 512))
FSOFFSET=0

HEADS=64
SECTORS=32
CYLINDERS=$((${FSSECTORS} / ( ${HEADS} * ${SECTORS} ) ))

# makefs(8) parameters
TARGET_ENDIAN=le
BLOCKSIZE=16384
FRAGSIZE=2048
DENSITY=8192

echo Creating rootfs...
${MAKEFS} -M ${FSSIZE} -B ${TARGET_ENDIAN} \
	-o bsize=${BLOCKSIZE},fsize=${FRAGSIZE},density=${DENSITY} \
	${IMAGE} ${FILESDIR}

echo Creating disklabel...
LABELPROTO=${WORKDIR}/labelproto
cat > ${LABELPROTO} <<EOF
type: ESDI
disk: SetupLiveImage
label: 
flags:
bytes/sector: 512
sectors/track: ${SECTORS}
tracks/cylinder: ${HEADS}
sectors/cylinder: $((${HEADS} * ${SECTORS}))
cylinders: ${CYLINDERS}
total sectors: ${FSSECTORS}
rpm: 3600
interleave: 1
trackskew: 0
cylinderskew: 0
headswitch: 0           # microseconds
track-to-track seek: 0  # microseconds
drivedata: 0 

8 partitions:
#        size    offset     fstype [fsize bsize cpg/sgs]
a:    ${FSSECTORS} ${FSOFFSET} 4.2BSD ${FRAGSIZE} ${BLOCKSIZE} 128
c:    ${FSSECTORS} ${FSOFFSET} unused 0 0
EOF

${DISKLABEL} -R -F ${IMAGE} ${LABELPROTO}
rm -f ${LABELPROTO}

echo Creating image \"${IMAGE}\" complete.
