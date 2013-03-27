#!/bin/sh

if [ -z "$2" ]
then
	OIFS="$IFS"
	IFS=":"
	set $1
	IFS="$OIFS"
fi

file=$1
if [ -n "$2" ]
then
	line=$2
else
	line=1
fi

vim=`which vim`
acme=`ps x | grep [a]cme`

if [ -n "$DISPLAY" -a -n "$vim" ]
then
	vimservers=`vim --serverlist`
	if [ -n "$vimservers" ]
	then
		exec vim --remote $file +$line
	fi
fi

if [ -n "$DISPLAY" -a -n "$acme" ]
then
	exec 9 B $file:$line
fi

if [ -n "$vim" ]
then
	exec vim $file +$line
fi

exec vi $file

