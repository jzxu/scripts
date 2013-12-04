#!/bin/sh

SEARCH="$HOME/svs/Core/SVS/src:$HOME/svs/Core/SVS/src/models:$HOME/svs_experiments:$HOME/svs_experiments/physics2"

vim_remote() {
	file=`readlink -m $1`

	case "$file" in
	*.tex)
		for d in `seq 3`
		do
			if DISPLAY=:$d vim --serverlist | grep -q THESIS
			then
				DISPLAY=:$d vim --servername THESIS --remote-send "<C-\><C-N>:n +$2 $file<CR>"
				exit 0
			fi
		done
		;;
	esac
	# use remote-send instead of remote to prevent changing working directory
	if vim --serverlist | grep -q VIM
	then
		vim --servername VIM --remote-send "<C-\><C-N>:n +$2 $file<CR>"
		exit 0
	fi
	zen info finish
}

find_file() {
	if [ -f "$1" ]
	then
		echo "$1"
		return
	fi
	
	f="$1"
	old_ifs="$IFS"
	IFS=:
	for p in $SEARCH
	do
		if [ -f "$p/$1" ]
		then
			f="$p/$1"
			echo "$f" >&2
			break
		fi
	done
	IFS="$old_ifs"
	echo "$f"
}

# parse line address

set `echo "$*" | awk '
	# +linenum file
	$1 ~ /\+[0-9]*/ && system("test -f " $2)==0 { print $2, substr($1, 2); exit }

	# file:linenum
	match($0, ":[0-9]+") {
		f = substr($0, 1, RSTART-1)
		n = substr($0, RSTART+1, RLENGTH-1)
		if (system("test -f " f) == 0) {
			print f, n
			exit
		}
	}

	# default
	{ print $1, $2 }
'`
file=`find_file "$1"`
line=$2

case "$file" in
*.pdf)
	qpdfview "$file" &
	exit
	;;
*.png|*.jpg|*.gif)
	display "$file" &
	exit
	;;
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
	vim_remote "$file" "$line" THESIS
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

