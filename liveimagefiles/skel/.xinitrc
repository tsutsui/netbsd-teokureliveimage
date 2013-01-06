#! /bin/sh
#
# .xinitrc
#
export LANG=ja_JP.UTF-8
export XAPPLRESDIR=/usr/pkg/lib/X11/app-defaults

host=`hostname`

xset s noblank
xset fp+ /usr/pkg/lib/X11/fonts/TTF/

# X keymap settings
#setxkbmap -layout jp
#setxkbmap -option ctrl:swapcaps
#setxkbmap -layout jp -option ctrl:swapcaps

# uncomment to use Yen key as backslash/bar on jp keyboard with us layout
#xmodmap -e 'keycode 133 = backslash bar'

resources=$HOME/.Xresources
if [ -r "$resources" ]; then
	xrdb -load "$resources"
fi

# iBus
export XMODIFIERS="@im=ibus"
export GTK_IM_MODULE=ibus
ibus-daemon -d -x ; sleep 2

mlterm -ls -geometry 80x25+0+30 -title $host &
jwm
