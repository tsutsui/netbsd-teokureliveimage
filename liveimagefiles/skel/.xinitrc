#! /bin/sh
#
# .xinitrc
#
#export LANG=ja_JP.UTF-8
export XAPPLRESDIR=/usr/pkg/lib/X11/app-defaults

host=`hostname`

xset s noblank
xset fp+ /usr/pkg/share/fonts/X11/TTF/
xset fp+ /usr/pkg/share/fonts/X11/misc/
xset fp+ /usr/pkg/share/fonts/truetype/unifont/

# X keymap settings
#setxkbmap -option ctrl:swapcaps
#setxkbmap -model pc105 -layout us
#setxkbmap -model pc105 -layout us -option ctrl:swapcaps
#setxkbmap -model jp106 -layout jp
#setxkbmap -model jp106 -layout jp -option ctrl:swapcaps

# uncomment to use Yen key as backslash/bar on jp keyboard with us layout
#xmodmap -e 'keycode 133 = backslash bar'

resources=$HOME/.Xresources
if [ -r "$resources" ]; then
	xrdb -load "$resources"
fi

# WiFi status in the tray icon
/usr/pkg/sbin/wpa_gui -t &

# for webkit-gtk and adobe-flash-plugin
#export MOZ_PLUGIN_PATH=/usr/pkg/lib/netscape/plugins

# iBus
if [ ! -f ${HOME}/.config/dconf/user ]; then
	# set mozc-jp as the default inputmethod
	gsettings set org.freedesktop.ibus.general preload-engines "['mozc-jp']"
	# mozc is always enabled and IME is turned on/off on it
	gsettings set org.freedesktop.ibus.general.hotkey triggers "[]"
	# set "hide automatically" for property panel
	gsettings set org.freedesktop.ibus.panel show 1
fi
export XMODIFIERS="@im=ibus"
export GTK_IM_MODULE="ibus"
export QT_IM_MODULE="ibus"
ibus-daemon --xim --daemonize --replace; sleep 2

mlterm -ls -geometry 80x25+0+30 -title $host &
jwm
