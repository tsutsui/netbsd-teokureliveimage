#! /bin/sh
#
# Copyright (c) 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018,
#  2019, 2020, 2023, 2025 Izumi Tsutsui.
# All rights reserved.
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
	REVISION=$(date +%C%y%m%d)
fi

DISKNAME=TeokureLiveImage
IMAGEHOSTNAME=teokure
TIMEZONE=Japan

#TESTIMAGE=yes

usage()
{
	echo "usage: $0 <machine>"
	echo "supported machine: amd64, i386"
	exit 1
}

err()
{
	echo $1 failed!
	exit 1
}

if [ $# != 1 ]; then
	usage
fi

IMAGE_TYPE=raw
MACHINE=$1

HAVE_EXPANDFS_SCRIPT=yes	# put a script to expand image fssize
EXPANDFS_SH=expand-image-fssize.sh

#
# target dependent info
#
if [ "${MACHINE}" = "amd64" ]; then
 MACHINE_ARCH=x86_64
 MACHINE_GNU_PLATFORM=x86_64--netbsd		# for fdisk(8)
 TARGET_ENDIAN=le
 KERN_SET=kern-GENERIC
 SUFFIX_SETS=tar.xz
 EXTRA_SETS= # nothing
 #USE_MBR=yes
 USE_MBR=no
 USE_GPT=yes
 USE_GPTMBR=yes
 OMIT_SWAPIMG=no	# include swap partition in output image for emulators
 RTC_LOCALTIME=yes	# use rtclocaltime=YES in rc.d(8) for Windows machines
 MAKEFSOPTIONS="-o version=2"
 PRIMARY_BOOT=bootxx_ffsv2
 SECONDARY_BOOT=boot
 SECONDARY_BOOT_ARG= # nothing
 EFIBOOT="bootx64.efi bootia32.efi"
fi

if [ "${MACHINE}" = "i386" ]; then
 MACHINE_ARCH=i386
 MACHINE_GNU_PLATFORM=i486--netbsdelf		# for fdisk(8)
 TARGET_ENDIAN=le
 KERN_SET=kern-GENERIC
 SUFFIX_SETS=tgz
 EXTRA_SETS= # nothing
 USE_MBR=yes
 #USE_MBR=no
 #USE_GPT=yes
 #USE_GPTMBR=yes
 OMIT_SWAPIMG=no	# include swap partition in output image for emulators
 RTC_LOCALTIME=yes	# use rtclocaltime=YES in rc.d(8) for Windows machines
 MAKEFSOPTIONS="-o version=2"
 PRIMARY_BOOT=bootxx_ffsv2
 SECONDARY_BOOT=boot
 SECONDARY_BOOT_ARG= # nothing
 EFIBOOT="bootia32.efi"	# XXX: NetBSD/i386 doesn't provide bootx64.efi
fi

if [ -z ${MACHINE_ARCH} ]; then
	echo "Unsupported MACHINE (${MACHINE})"
	exit 1
fi

if [ "${USE_GPT}" = "yes" ] && [ "${OMIT_SWAPIMG}" = "yes" ]; then
	echo "Cannot omit swap if USE_GPT=yes"
	exit 1
fi

#
# tooldir settings
#
#NETBSDSRCDIR=/usr/src
CURDIR=$(pwd)
NETBSDSRCDIR=${CURDIR}/src
#TOOLDIR=/usr/tools/${MACHINE_ARCH}

if [ -z ${NETBSDSRCDIR} ]; then
	NETBSDSRCDIR=/usr/src
fi

if [ -z ${TOOLDIR} ]; then
	_HOST_OSNAME=$(uname -s)
	_HOST_OSREL=$(uname -r)
	_HOST_ARCH=$(uname -p 2> /dev/null || uname -m)
	TOOLDIRNAME=tooldir.${_HOST_OSNAME}-${_HOST_OSREL}-${_HOST_ARCH}
	TOOLDIR=${NETBSDSRCDIR}/obj.${MACHINE}/${TOOLDIRNAME}
	if [ ! -d ${TOOLDIR} ]; then
		TOOLDIR=${NETBSDSRCDIR}/${TOOLDIRNAME}
	fi
fi

if [ ! -d ${TOOLDIR} ]; then
	echo "set TOOLDIR first (${TOOLDIR})"; exit 1
fi
if [ ! -x ${TOOLDIR}/bin/nbmake-${MACHINE} ]; then
	echo 'build tools in ${TOOLDIR} first'; exit 1
fi

#
# info about ftp to get binary sets
#
#FTPHOST=ftp.NetBSD.org
#FTPHOST=ftp.jp.NetBSD.org
#FTPHOST=ftp7.jp.NetBSD.org
FTPHOST=cdn.NetBSD.org
#FTPHOST=nycdn.NetBSD.org
RELEASE=10.1
RELEASEDIR=pub/NetBSD/NetBSD-${RELEASE}
#RELEASEDIR=pub/NetBSD-daily/netbsd-10/latest

#
# misc build settings
#

# tools binaries
TOOL_DISKLABEL=${TOOLDIR}/bin/nbdisklabel
TOOL_FDISK=${TOOLDIR}/bin/${MACHINE_GNU_PLATFORM}-fdisk
TOOL_GPT=${TOOLDIR}/bin/nbgpt
TOOL_INSTALLBOOT=${TOOLDIR}/bin/nbinstallboot
TOOL_MAKEFS=${TOOLDIR}/bin/nbmakefs
TOOL_SED=${TOOLDIR}/bin/nbsed
TOOL_SUNLABEL=${TOOLDIR}/bin/nbsunlabel

# host binaries
CAT=cat
CP=cp
DD=dd
FTP=ftp
#FTP=tnftp
FTP_OPTIONS=-V
MKDIR=mkdir
RM=rm
SH=sh
TAR=tar
TOUCH=touch

# working directories
if [ "${OBJDIR}"X = "X" ]; then
	OBJDIR=.
fi
TARGETROOTDIR=${OBJDIR}/targetroot.${MACHINE}.${IMAGE_TYPE}
DOWNLOADDIR=download.${RELEASE}.${MACHINE}
WORKDIR=${OBJDIR}/work.${MACHINE}.${IMAGE_TYPE}
IMAGE=${WORKDIR}/liveimage-${MACHINE}-${IMAGE_TYPE}-${REVISION}.img

#
# target image size settings
#
IMAGEMB=5120			# 5120MB (4GB isn't enough for 8.0 + 2018Q2)
SWAPMB=512			# 512MB

if [ "${USE_GPT}" = "yes" ]; then
	EFIMB=36		# min size of FAT32 (recommended for sanity)
	GPTMB=1			# 1MB (for the secondary GPT table/header)
else
	EFIMB=0
	GPTMB=0
fi

IMAGESECTORS=$((IMAGEMB * 1024 * 1024 / 512))
EFISIZE=$((EFIMB * 1024 * 1024))
EFISECTORS=$((EFISIZE / 512))
GPTSECTORS=$((GPTMB * 1024 * 1024 / 512))
SWAPSECTORS=$((SWAPMB * 1024 * 1024 / 512))

LABELSECTORS=0
if [ "${USE_MBR}" = "yes" ] || [ "${USE_GPT}" = "yes" ]; then
#	LABELSECTORS=63		# historical
#	LABELSECTORS=32		# aligned
	LABELSECTORS=2048	# align 1MiB for modern flash
fi
BSDPARTSECTORS=$((IMAGESECTORS - LABELSECTORS - EFISECTORS - GPTSECTORS))
FSSECTORS=$((IMAGESECTORS - SWAPSECTORS - LABELSECTORS - EFISECTORS - GPTSECTORS))
FSOFFSET=$((LABELSECTORS + EFISECTORS))
SWAPOFFSET=$((LABELSECTORS + FSSECTORS))
FSSIZE=$((FSSECTORS * 512))
HEADS=64
SECTORS=32
CYLINDERS=$((IMAGESECTORS / (HEADS * SECTORS) ))
FSCYLINDERS=$((FSSECTORS / (HEADS * SECTORS) ))
SWAPCYLINDERS=$((SWAPSECTORS / (HEADS * SECTORS) ))

# fdisk(8) parameters
MBRSECTORS=63
MBRHEADS=255
MBRCYLINDERS=$((IMAGESECTORS / ( MBRHEADS * MBRSECTORS ) ))
MBRNETBSD=169

# makefs(8) parameters
BLOCKSIZE=16384
FRAGSIZE=4096
DENSITY=8192

# temporary image work files
WORKMBR=${WORKDIR}/work.mbr
WORKMBRTRUNC=${WORKDIR}/work.mbr.truncated
WORKSWAP=${WORKDIR}/work.swap
WORKEFI=${WORKDIR}/work.efi
WORKEFIDIR=${WORKDIR}/work.efidir
WORKGPT=${WORKDIR}/work.gpt
WORKFS=${WORKDIR}/work.rootfs
WORKLABEL=${WORKDIR}/work.diskproto
WORKIMG=${WORKDIR}/work.img

# temprary work files for rootfs
WORKFSTAB=${WORKDIR}/work.fstab
WORKSPEC=${WORKDIR}/work.spec

# GPT label names for fstab(5)
GPTROOTLABEL=${DISKNAME}_root
GPTSWAPLABEL=${DISKNAME}_swap

echo creating ${IMAGE_TYPE} image for ${MACHINE}...

echo Removing ${WORKDIR}...
${RM} -rf ${WORKDIR}
${MKDIR} -p ${WORKDIR}

#
# get binary sets
#
URL_SETS=http://${FTPHOST}/${RELEASEDIR}/${MACHINE}/binary/sets
SETS="${KERN_SET} modules base rescue etc comp games gpufw man misc tests text xbase xcomp xetc xfont xserver ${EXTRA_SETS}"
#SETS="${KERN_SET} modules base rescue etc comp ${EXTRA_SETS}"
#SETS="${KERN_SET} base rescue etc comp games man misc tests text xbase xcomp xetc xfont xserver ${EXTRA_SETS}"
#SETS="${KERN_SET} base rescue etc comp ${EXTRA_SETS}"
${MKDIR} -p ${DOWNLOADDIR}
for set in ${SETS}; do
	if [ ! -f ${DOWNLOADDIR}/${set}.${SUFFIX_SETS} ]; then
		echo Fetching ${set}.${SUFFIX_SETS}...
		${FTP} ${FTP_OPTIONS} \
		    -o ${DOWNLOADDIR}/${set}.${SUFFIX_SETS} \
		    ${URL_SETS}/${set}.${SUFFIX_SETS} \
		    || err ${FTP}
	fi
done

#
# create targetroot
#
echo Removing ${TARGETROOTDIR}...
${RM} -rf ${TARGETROOTDIR}
${MKDIR} -p ${TARGETROOTDIR}
for set in ${SETS}; do
	echo Extracting ${set}...
	${TAR} -C ${TARGETROOTDIR} -zxf ${DOWNLOADDIR}/${set}.${SUFFIX_SETS} \
	    || err ${TAR}
done
# XXX /var/spool/ftp/hidden is unreadable
chmod u+r ${TARGETROOTDIR}/var/spool/ftp/hidden

# copy secondary boot for bootstrap
# XXX probabry more machine dependent
if [ ! -z ${SECONDARY_BOOT} ]; then
	echo Copying secondary boot...
	${CP} ${TARGETROOTDIR}/usr/mdec/${SECONDARY_BOOT} ${TARGETROOTDIR}
fi

# prepare MBR partition
if [ "${USE_MBR}" = "yes" ]; then
	echo creating MBR labels...
	${DD} if=/dev/zero of=${WORKMBR} count=1 \
	    seek=$((IMAGESECTORS - 1)) \
	    || err ${DD}
	${TOOL_FDISK} -f -u \
	    -b ${MBRCYLINDERS}/${MBRHEADS}/${MBRSECTORS} \
	    -0 -a -s ${MBRNETBSD}/${FSOFFSET}/${BSDPARTSECTORS} \
	    -i -c ${TARGETROOTDIR}/usr/mdec/mbr \
	    -F ${WORKMBR} \
	    || err ${TOOL_FDISK}
	${DD} if=${WORKMBR} of=${WORKMBRTRUNC} count=${LABELSECTORS} \
	    || err ${DD}
fi

# prepare the primary and secondary GPT partition
if [ "${USE_GPT}" = "yes" ]; then
	echo creating GPT headers and tables...
	${DD} if=/dev/zero of=${WORKMBR} count=1 \
	    seek=$((IMAGESECTORS - 1)) \
	    || err ${DD}
	${TOOL_GPT} ${WORKMBR} create || err ${TOOL_GPT}
	${TOOL_GPT} ${WORKMBR} add -a 1m -s ${EFISECTORS} \
	    -t efi -l "EFI system" || err ${TOOL_GPT}
	${TOOL_GPT} ${WORKMBR} add -a 1m -s ${FSSECTORS} \
	    -t ffs -l ${GPTROOTLABEL} || err ${TOOL_GPT}
	${TOOL_GPT} ${WORKMBR} add -a 1m -s ${SWAPSECTORS} \
	    -t swap -l ${GPTSWAPLABEL} || err ${TOOL_GPT}
	${DD} if=${WORKMBR} of=${WORKMBRTRUNC} count=${LABELSECTORS} \
	    || err ${DD}
	${DD} if=${WORKMBR} of=${WORKGPT} \
	    skip=$((IMAGESECTORS - GPTSECTORS)) count=${GPTSECTORS} \
	    || err ${DD}
fi

#
# create target fs
#
echo Preparing /etc/fstab...
${CAT} > ${WORKFSTAB} <<EOF
ROOT.a		/		ffs	rw,log		1 1
ROOT.b		none		none	sw		0 0
kernfs		/kern		kernfs	rw		0 0
ptyfs		/dev/pts	ptyfs	rw		0 0
procfs		/proc		procfs	rw		0 0
/dev/cd0a	/cdrom		cd9660	ro,noauto	0 0
tmpfs		/tmp		tmpfs	rw,-s=128M	0 0
tmpfs		/var/shm	tmpfs	rw,-sram%25	0 0
EOF

if [ "${USE_GPT}" = "yes" ]; then
	${TOOL_SED} \
		-e "s/ROOT.a/ROOT./"					\
		-e "s/ROOT.b/NAME=${GPTSWAPLABEL}/"			\
		< ${WORKFSTAB} > ${TARGETROOTDIR}/etc/fstab
else
	${CP} ${WORKFSTAB} ${TARGETROOTDIR}/etc/fstab
fi

echo Setting liveimage specific configurations in /etc/rc.conf...
${CAT} ${TARGETROOTDIR}/etc/rc.conf | \
    ${TOOL_SED} -e 's/rc_configured=NO/rc_configured=YES/' > ${WORKDIR}/rc.conf
if [ ${RTC_LOCALTIME}x = "yesx" ]; then
	echo rtclocaltime=YES		>> ${WORKDIR}/rc.conf
else
	echo \#rtclocaltime=YES		>> ${WORKDIR}/rc.conf
fi
echo hostname=${IMAGEHOSTNAME}		>> ${WORKDIR}/rc.conf
echo dhcpcd=YES				>> ${WORKDIR}/rc.conf
${CP} ${WORKDIR}/rc.conf ${TARGETROOTDIR}/etc

echo Setting localtime...
ln -sf /usr/share/zoneinfo/${TIMEZONE} ${TARGETROOTDIR}/etc/localtime

echo Preparing spec file for makefs...
${CAT} ${TARGETROOTDIR}/etc/mtree/* | \
	${TOOL_SED} -e 's/ size=[0-9]*//' > ${WORKSPEC}
${SH} ${TARGETROOTDIR}/dev/MAKEDEV -s all | \
	${TOOL_SED} -e '/^\. type=dir/d' -e 's,^\.,./dev,' >> ${WORKSPEC}
# spec for optional files/dirs
${CAT} >> ${WORKSPEC} <<EOF
./boot				type=file mode=0444
./cdrom				type=dir  mode=0755
./kern				type=dir  mode=0755
./netbsd			type=file mode=0755
./proc				type=dir  mode=0755
./tmp				type=dir  mode=1777
EOF

if [ ${HAVE_EXPANDFS_SCRIPT}x = "yesx" ]; then
	echo Preparing ${EXPANDFS_SH} script...
	${TOOL_SED} \
		-e "s/@@DISKNAME@@/${DISKNAME}/"			\
		-e "s/@@MBRNETBSD@@/${MBRNETBSD}/"			\
		-e "s/@@IMAGEMB@@/${IMAGEMB}/"				\
		-e "s/@@SWAPMB@@/${SWAPMB}/"				\
		-e "s/@@GPTMB@@/${GPTMB}/"				\
		-e "s/@@HEADS@@/${HEADS}/"				\
		-e "s/@@SECTORS@@/${SECTORS}/"				\
		< ./${EXPANDFS_SH}.in > ${TARGETROOTDIR}/${EXPANDFS_SH}
	echo ./${EXPANDFS_SH}	type=file mode=755 >> ${WORKSPEC}
fi

echo Creating rootfs...
${TOOL_MAKEFS} -M ${FSSIZE} -m ${FSSIZE} \
	-B ${TARGET_ENDIAN} \
	-F ${WORKSPEC} -N ${TARGETROOTDIR}/etc \
	-o bsize=${BLOCKSIZE},fsize=${FRAGSIZE},density=${DENSITY} \
	${MAKEFSOPTIONS} \
	${WORKFS} ${TARGETROOTDIR} \
	|| err ${TOOL_MAKEFS}

if [ ${PRIMARY_BOOT}x != "x" ]; then
echo Installing bootstrap...
${TOOL_INSTALLBOOT} -v -m ${MACHINE} ${WORKFS} \
    ${TARGETROOTDIR}/usr/mdec/${PRIMARY_BOOT} ${SECONDARY_BOOT_ARG} \
    || err ${TOOL_INSTALLBOOT}
fi

#
# create EFI system partition
#
if [ "${USE_GPT}" = "yes" ]; then
	echo Creating EFI system partition...
	echo Removing ${WORKEFIDIR}...
	${RM} -rf ${WORKEFIDIR}
	${MKDIR} -p ${WORKEFIDIR}
	${MKDIR} -p ${WORKEFIDIR}/EFI/boot
	for boot in ${EFIBOOT}; do
		${CP} ${TARGETROOTDIR}/usr/mdec/${boot} ${WORKEFIDIR}/EFI/boot
	done
	${RM} -f ${WORKEFI}
	${TOOL_MAKEFS} -M ${EFISIZE} -m ${EFISIZE} \
	    -B ${TARGET_ENDIAN} -t msdos -o fat_type=32,sectors_per_cluster=1 \
	    ${WORKEFI} ${WORKEFIDIR} \
	    || err ${TOOL_MAKEFS}
fi

if [ "${OMIT_SWAPIMG}x" != "yesx" ]; then
	echo Creating swap fs
	${DD} if=/dev/zero of=${WORKSWAP} \
	    seek=$((SWAPSECTORS - 1)) count=1 \
	    || erro ${DD}
fi

echo Copying target disk image...
rm -f ${WORKIMG}
${TOUCH} ${WORKIMG}
# add MBR and the primary GPT partition region
if [ ${LABELSECTORS} != 0 ]; then
	${CAT} ${WORKMBRTRUNC} >> ${WORKIMG} || err ${CAT}
fi
# add EFI FAT partition
if [ "${USE_GPT}" = "yes" ]; then
	${CAT} ${WORKEFI} >> ${WORKIMG} || err ${CAT}
fi
# add NetBSD root partition
${CAT} ${WORKFS} >> ${WORKIMG} || err ${CAT}
# add swap
if [ "${OMIT_SWAPIMG}x" != "yesx" ]; then
	${CAT} ${WORKSWAP} >> ${WORKIMG} || err ${CAT}
fi
# add the secondary GPT table (at the end of the target image)
if [ "${USE_GPT}" = "yes" ]; then
	${CAT} ${WORKGPT} >> ${WORKIMG} || err ${CAT}
fi

if [ ! -z ${USE_SUNLABEL} ]; then
	echo Creating sun disklabel...
	printf 'V ncyl %d\nV nhead %d\nV nsect %d\na %d %d/0/0\nb %d %d/0/0\nW\n' \
	    ${CYLINDERS} ${HEADS} ${SECTORS} \
	    ${FSOFFSET} ${FSCYLINDERS} ${FSCYLINDERS} ${SWAPCYLINDERS} | \
	    ${TOOL_SUNLABEL} -nq ${WORKIMG} \
	    || err ${TOOL_SUNLABEL}
fi

if [ "${USE_GPT}" = "yes" ]; then
	echo Finalize GPT entries...
	if [ "${USE_GPTMBR}" = "yes" ]; then
		${TOOL_GPT} ${WORKIMG} biosboot -i 2 \
		    -c ${TARGETROOT}/usr/mdec/gptmbr.bin || err ${TOOL_GPT}
	fi
	${TOOL_GPT} ${WORKIMG} set -a bootme -i 2 || err ${TOOL_GPT}
else
	echo Creating disklabel...
	${CAT} > ${WORKLABEL} <<EOF
type: ESDI
disk: ${DISKNAME}
label:
flags:
bytes/sector: 512
sectors/track: ${SECTORS}
tracks/cylinder: ${HEADS}
sectors/cylinder: $((HEADS * SECTORS))
cylinders: ${CYLINDERS}
total sectors: ${IMAGESECTORS}
rpm: 3600
interleave: 1
trackskew: 0
cylinderskew: 0
headswitch: 0		# microseconds
track-to-track seek: 0	# microseconds
drivedata: 0

8 partitions:
#        size    offset     fstype [fsize bsize cpg/sgs]
a:    ${FSSECTORS} ${FSOFFSET} 4.2BSD ${FRAGSIZE} ${BLOCKSIZE} 128
b:    ${SWAPSECTORS} ${SWAPOFFSET} swap
c:    ${BSDPARTSECTORS} ${FSOFFSET} unused 0 0
d:    ${IMAGESECTORS} 0 unused 0 0
EOF

	${TOOL_DISKLABEL} -R -F -M ${MACHINE} ${WORKIMG} ${WORKLABEL} \
	    || err ${TOOL_DISKLABEL}
fi

# XXX some ${MACHINE} needs disklabel for installboot
#${TOOL_INSTALLBOOT} -vm ${MACHINE} ${WORKIMG} \
#    ${TARGETROOTDIR}/usr/mdec/${PRIMARY_BOOT}

mv ${WORKIMG} ${IMAGE}
echo Creating image \"${IMAGE}\" complete.

if [ "${TESTIMAGE}" != "yes" ]; then exit; fi

#
# for test on emulators...
#
if [ "${MACHINE}" = "amd64" -a -x /usr/pkg/bin/qemu-system-x86_64 ]; then
	qemu-system-x86_64 -hda ${IMAGE} -boot c
fi
if [ "${MACHINE}" = "i386" -a -x /usr/pkg/bin/qemu ]; then
	qemu -hda ${IMAGE} -boot c
fi
