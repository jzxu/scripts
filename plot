#!/bin/sh

data=`mktemp`
cmds=`mktemp`

while read line
do
	echo $line
done >$data

if [ -z "$*" ]
then
	echo "plot '$data' using 1" >$cmds
else
	for arg; do echo $arg; done | awk '
	BEGIN {
		data = "'$data'"
		FS=":"
		flagtrans["l"] = "w l"
		flagtrans["d"] = "w d"
	}
	/-ylog/ {
		print("set logscale y");
	}
	/^[0-9]+/ {
		if (cmd != "") {
			cmd = cmd ", "
		}
		
		if ($0 ~ /^[0-9]+:[0-9]+/) {
			# <x>:<y>:<flags>:<name>
			cmd = cmd sprintf("\"%s\" using %d:%d", data, $1, $2)
			flags = $3
			name = $4
		} else {
			# <y>:<flags>:<name>
			cmd = cmd sprintf("\"%s\" using %d", data, $1)
			flags = $2
			name = $3
		}
		
		for (f in flagtrans) {
			if (flags ~ f) {
				cmd = cmd " " flagtrans[f]
			}
		}
		
		if (name != "") {
			cmd = cmd " t \"" name "\""
		}
	}
	END {
		print("plot " cmd)
	}' > $cmds
fi

gnuplot -p $cmds
rm -f $data $cmds
