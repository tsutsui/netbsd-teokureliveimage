#! /bin/sh
#
# .xsession
#
export LANG=ja_JP.UTF-8
export XAPPLRESDIR=/usr/pkg/lib/X11/app-defaults

host=`hostname`

xset s noblank
xset fp+ /usr/pkg/lib/X11/fonts/TTF/
xset fp+ /usr/pkg/lib/X11/fonts/efont/

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

# iBus
export XMODIFIERS="@im=ibus"
export GTK_IM_MODULE="ibus"
export QT_IM_MODULE="ibus"
ibus-daemon --xim --daemonize --replace; sleep 2

mlterm -ls -geometry 80x25+0+30 -title $host &
jwm
