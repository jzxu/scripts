#!/bin/sh

case "$1" in
+[0-9]*)
	# gdb style +line file
	file="$2"
	line="${1:1}"
	;;
*:[0-9]|*:[0-9][0-9]|*:[0-9][0-9][0-9]|*:[0-9][0-9][0-9][0-9]|*:[0-9][0-9][0-9][0-9][0-9])
	# file:line
	OIFS="$IFS"
	IFS=":"
	set $1
	IFS="$OIFS"
	file="$1"
	line="$2"
	;;
*)
	file="$1"
	line="$2"
esac

ps a | awk '$5 == "svn" || $5 == "git" { exit 1 }'
block=$?

# chase symlinks
if [ -s "$file" ]
then
	file=`readlink -e $file`
fi

if [ -z "$line" ]
then
	line=1
fi

vim=`which vim`
acme=`ps x | grep [a]cme`

if [ "$block" -eq 0 -a -n "$DISPLAY" -a -n "$vim" ]
then
	vimservers=`vim --serverlist`
	if [ -n "$vimservers" ]
	then
		exec vim --remote +$line $file
	fi
fi

if [ "$block" -eq 0 -a -n "$DISPLAY" -a -n "$acme" ]
then
	if [ -f "$file" ]
	then
		exec 9 B $file:$line
	else
		exec 9 B $file
	fi
fi

if [ -n "$vim" ]
then
	exec vim +$line $file
fi

exec vi $file

