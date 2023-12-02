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
RUBY_PKGPREFIX=ruby31
PACKAGES=" \
	bash tcsh zsh \
	emacs \
	medit \
	firefox firefox-l10n \
	alsa-utils \
	alsa-plugins-oss \
	alsa-plugins-pulse \
	w3m \
	vlgothic-ttf ipafont \
	droid-ttf \
	unifont \
	freefont-ttf \
	twemoji-color-font-ttf \
	jisx0212fonts jisx0213fonts \
	jwm \
	wm-icons \
	ibus \
	adwaita-icon-theme \
	arandr \
	wpa_gui \
	mozc-server mozc-tool ibus-mozc mozc-elisp \
	kterm mlterm \
	git-base \
	${RUBY_PKGPREFIX}-mikutter \
	sayaka \
	nanotodon \
	mozilla-rootcerts \
	"

echo "mounting target disk image..."
mount -o async ${ROOTFSDEV} /

echo "copying local /etc settings..."
cp ${FILEDIR}/etc.${MACHINE}/ttys /etc

# copy typical mk.conf file
cp ${FILEDIR}/etc/mk.conf /etc

echo "installing wpa_supplicant(8) settings..."
install -o root -g wheel -m 600 ${FILEDIR}/etc/wpa_supplicant.conf /etc
cp /usr/share/examples/dhcpcd/hooks/10-wpa_supplicant \
    /libexec/dhcpcd-hooks

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
mkdir -p /usr/pkg/lib/firefox/browser/defaults/preferences
cp ${FILEDIR}/firefox/browser/defaults/preferences/firefox-local.js \
    /usr/pkg/lib/firefox/browser/defaults/preferences
cp ${FILEDIR}/firefox/defaults/pref/local-prefs.js \
    /usr/pkg/lib/firefox/defaults/pref

# add rc.conf definitions for xdm
echo wscons=YES				>> /etc/rc.conf
echo xdm=YES				>> /etc/rc.conf

# add rc.conf definitions for packages
echo dbus=YES				>> /etc/rc.conf   
echo avahidaemon=NO			>> /etc/rc.conf

# copy local fontconfig settings for pkgsrc fonts
#cp ${FILEDIR}/etc/fonts/local.conf /etc/fonts

# copy files for asound.conf
#cp ${FILEDIR}/etc/asound.conf /etc

# copy sample xorg.conf settings to workaround accelaration issue
cp ${FILEDIR}/etc/xorg.conf.intel-uxa /etc/X11
cp ${FILEDIR}/etc/xorg.conf.vesa /etc/X11

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
