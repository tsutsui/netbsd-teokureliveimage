#! /bin/sh

MACHINE_ARCH=`uname -p`
MACHINE=`uname -m`

# set directory where this setupliveimage.img is mounted
FILEDIR=/mnt

# target root file system device
BOOTDEV=`sysctl -r kern.root_device`
ROOTFSDEV=/dev/${BOOTDEV}a

# default user settings
UID=100
USER="mikutter"
GROUP="users"
SHELL=/usr/pkg/bin/tcsh
#SHELL=/usr/pkg/bin/bash
PASSWORD="Teokure-"

# packages list
RUBY_PKGPREFIX=ruby200
PACKAGES=" \
	bash tcsh zsh \
	emacs \
	medit \
	firefox firefox-l10n \
	gnash \
	vlgothic-ttf ipafont \
	droid-ttf \
	efont-unicode \
	jwm \
	ibus \
	mozc-server mozc-tool ibus-mozc mozc-elisp \
	kterm mlterm \
	alsa-utils alsa-plugins-oss \
	git-base \
	${RUBY_PKGPREFIX}-mikutter \
	${RUBY_PKGPREFIX}-tw \
	"

echo "mounting target disk image..."
mount -o async ${ROOTFSDEV} /

echo "copying local /etc settings..."
cp ${FILEDIR}/etc.${MACHINE}/ttys /etc

# copy typical mk.conf file
cp ${FILEDIR}/etc/mk.conf /etc

echo "installing packages..."
PACKAGESDIR=${FILEDIR}/packages/${MACHINE_ARCH}
(cd ${PACKAGESDIR}; PKG_RCD_SCRIPTS=YES pkg_add $PACKAGES)

# set mozc as system default of ibus
/usr/pkg/bin/gconftool-2 --direct \
    --config-source xml:write:/usr/pkg/etc/gconf/gconf.xml.defaults \
    --type=list --list-type=string \
    --set /desktop/ibus/general/preload_engines "[mozc-jp]"

# copy firefox addons settings
# XXX: this would make future pkg_delete(1) complain about extra file
cp ${FILEDIR}/firefox/firefox-local.js \
    /usr/pkg/lib/firefox/browser/defaults/preferences

# add rc.conf definitions for xdm
echo wscons=YES				>> /etc/rc.conf
echo xdm=YES				>> /etc/rc.conf

# add rc.conf definitions for packages
echo dbus=YES				>> /etc/rc.conf   
echo hal=YES				>> /etc/rc.conf   
echo avahidaemon=NO			>> /etc/rc.conf
echo nasd=NO				>> /etc/rc.conf

# copy files for asound.conf
cp ${FILEDIR}/etc/asound.conf /etc

echo "updating fontconfig cache..."
/usr/X11R7/bin/fc-cache

echo "updating man database..."
/usr/sbin/makemandb

echo "creating user account..."
useradd -m \
	-k ${FILEDIR}/skel \
	-u $UID \
	-g $GROUP \
	-G wheel \
	-s $SHELL \
	-p `pwhash $PASSWORD` \
	$USER

echo "done."
