#! /bin/sh
#
# copy necessary binary packages into setupliveimage per packages-YYYYMMDD.list
#

PKGSRC_VER=6.0.1_2013Q1

#PACKAGESDIR_I386=/usr/pkgsrc/packages/i386/${PKGSRC_VER}/All
#PACKAGESDIR_X86_64=/usr/pkgsrc/packages/x86_64/${PKGSRC_VER}/All
PACKAGESDIR_I386=/usr/pkgsrc/packages/i386-${PKGSRC_VER}/All
PACKAGESDIR_X86_64=/usr/pkgsrc/packages/x86_64-${PKGSRC_VER}/All

if [ -f REVISION ]; then
	. ./REVISION
fi
if [ "${REVISION}"X = "X" ]; then
	REVISION=`date +%C%y%m%d`
fi

if [ ! -f list/packages-${REVISION}.list ]; then
	echo Error: no packages-${REVISION}.list file.
	exit 1
fi

PACKAGES=`cat list/packages-${REVISION}.list`

echo Removing old binaries...
rm -f liveimagefiles/packages/i386/*.tgz liveimagefiles/packages/x86_64/*.tgz

for pkg in ${PACKAGES}; do
	echo Copying ${pkg}.tgz
	if [ ! -f ${PACKAGESDIR_I386}/${pkg}.tgz -o \
	     ! -f ${PACKAGESDIR_X86_64}/${pkg}.tgz ]; then
		echo Error: ${pkg} is not found.
		exit 1
	fi
	cp ${PACKAGESDIR_I386}/${pkg}.tgz liveimagefiles/packages/i386
	cp ${PACKAGESDIR_X86_64}/${pkg}.tgz liveimagefiles/packages/x86_64
done

echo Done!
