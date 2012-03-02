#!/bin/sh

data=`mktemp`
cmds=`mktemp`

while [ -n "$1" ]
do
	case "$1" in
	-*)
		opts="$opts $1"
		;;
	*)
		args="$args $1"
		;;
	esac
	shift
done

while read line
do
	nf=`echo $line | wc -w`
	echo $line
done >$data

if [ -z "$args" ]
then
	for i in `seq $nf`
	do
		args="$args $i:l"
	done
fi

awk -v args="$args" -v opts="$opts" -v nf=$nf -v data=$data '
BEGIN {
	stderr = "/dev/stderr"
	flagtrans["l"] = "w l"
	flagtrans["d"] = "w d"
	
	nopts = split(opts, o)
	for (i = 1; i <= nopts; ++i) {
		if (o[i] == "-ylog") {
			print("set logscale y");
		}
	}
	
	nargs = split(args, a)
	cmd = "plot "
	for (i = 1; i <= nargs; ++i) {
		n = split(a[i], f, ":")
		if (n == 1) {
			using = f[1]
			flags = ""
			name = ""
		} else if (match(f[1], "^[0-9]+$") && match(f[2], "^[0-9]+$")) {
			using = f[1] ":" f[2]
			flags = f[3]
			name = f[4]
		} else if (match(f[1], "^[0-9]+$")) {
			using = f[1]
			flags = f[2]
			name = f[3]
		}
		
		if (i == 1) {
			cmd = sprintf("plot \"%s\" using %s ", data, using)
		} else {
			cmd = sprintf("%s,\"\" using %s ", cmd, using)
		}

		for (flag in flagtrans) {
			if (flags ~ flag) {
				cmd = cmd " " flagtrans[flag]
			}
		}
		
		if (name == "") {
			name = i
		}
		cmd = cmd " t \"" name "\""
	}
	print cmd
	exit
}' > $cmds

gnuplot -p $cmds
rm -f $data $cmds
