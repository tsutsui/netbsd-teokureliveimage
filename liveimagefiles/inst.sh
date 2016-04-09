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
RUBY_PKGPREFIX=ruby22
PACKAGES=" \
	bash tcsh zsh \
	emacs \
	medit \
	firefox firefox-l10n \
	gst-plugins1-libav gst-plugins1-good \
	w3m \
	vlgothic-ttf ipafont \
	droid-ttf \
	efont-unicode \
	unifont \
	freefont-ttf \
	jwm \
	wm-icons \
	ibus \
	adwaita-icon-theme \
	mozc-server mozc-tool ibus-mozc mozc-elisp \
	kterm mlterm \
	git-base \
	${RUBY_PKGPREFIX}-mikutter \
	${RUBY_PKGPREFIX}-tw \
	mozilla-rootcerts \
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
#  XXX:	ibus-1.5.x is configured to use dbus and dconf(1)
#	requires running Xserver to write configurations,
#	so mozc-jp will be configured on the first startup
#	by gsettings(1) in .xsession and .xinitrc scripts.

# copy firefox addons settings
# XXX: this would make future pkg_delete(1) complain about extra file
cp ${FILEDIR}/firefox/firefox-local.js \
    /usr/pkg/lib/firefox/browser/defaults/preferences

# add rc.conf definitions for xdm
echo wscons=YES				>> /etc/rc.conf
echo xdm=YES				>> /etc/rc.conf

# add rc.conf definitions for packages
echo dbus=YES				>> /etc/rc.conf   
#echo hal=YES				>> /etc/rc.conf   
echo avahidaemon=NO			>> /etc/rc.conf
#echo nasd=NO				>> /etc/rc.conf

# copy local fontconfig settings for pkgsrc fonts
#cp ${FILEDIR}/etc/fonts/local.conf /etc/fonts

# copy files for asound.conf
#cp ${FILEDIR}/etc/asound.conf /etc

echo "installing mozilla CA root certificates..."
/usr/pkg/sbin/mozilla-rootcerts install

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
