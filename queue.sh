#!/bin/bash

del_elem() {
	for e in $1
	do
		if [ "$e" != "$2" ]
		then
			echo -n "$e "
		fi
	done
}

stopped() {
	stat=`ps -o pid,stat | grep $1 | awk '{print substr($2,1,1)}'`
	[ "$stat" = T ]
}

make_queue() {
	if [ -z "$1" ]
	then
		echo "Specify control directory" 1>&2
		exit 1
	fi
	
	if [ -d "$1" ]
	then
		echo -n "Control directory exists, overwrite? "
		read resp
		case "$resp" in
		y|Y|yes)
			rm -rf "$1"
			;;
		*)
			return 1
			;;
		esac
	fi
	
	QUEUE_DIR="$1"
	mkdir -p $QUEUE_DIR || { echo "directory creation failed" 1>&2; exit 1; }
	QUEUE_FIFO="$QUEUE_DIR/fifo"
	mkfifo $QUEUE_FIFO || { echo "fifo creation failed" 1>&2; exit 1; }
	
	if [ -z "$2" ]
	then
		QUEUE_MAX_PROCS=1
	else
		QUEUE_MAX_PROCS="$2"
	fi
	WAITING_PIDS=""
}

clear_queue() {
	echo Killing remaining jobs: $ACTIVE_PIDS $WAITING_PIDS 1>&2
	kill -9 $ACTIVE_PIDS $WAITING_PIDS
}

exit_queue() {
	echo `date` exit $2 >>"$JOB_DIR/status"
	echo exit $1 $2 >$QUEUE_FIFO
}

init_job() {
	trap "exit_queue $BASHPID \$?" EXIT
	
	JOB_DIR="$QUEUE_DIR/$BASHPID"
	mkdir "$JOB_DIR" || { echo "Cannot create $JOB_DIR"; exit 1; }
	exec 1>"$JOB_DIR/stdout"
	exec 2>"$JOB_DIR/stderr"
	
	if [ -n "$*" ]
	then
		echo $* >"$JOB_DIR/label"
	fi
	echo `date` queued >>"$JOB_DIR/status"
	kill -s SIGSTOP $BASHPID
	echo `date` running >>"$JOB_DIR/status"
}

reg_queue() {
	WAITING_PIDS="$WAITING_PIDS $!"
}

wait_queue() {
	if [ -z "$WAITING_PIDS" ]
	then
		return 0
	fi
	
	trap "{ clear_queue; exit 1; }" SIGINT
	
	ACTIVE_PIDS=""
	NACTIVE=0
	BAD_PIDS=""
	set $WAITING_PIDS
	while [ $# -gt 0 -o $NACTIVE -gt 0 ]
	do
		while [ "$NACTIVE" -lt $QUEUE_MAX_PROCS -a "$#" -gt 0 ]
		do
			ACTIVE_PIDS="$ACTIVE_PIDS $1"
			NACTIVE=$((NACTIVE+1))
			
			# make sure process is stopped before issuing SIGCONT
			while ! stopped $1
			do
				sleep 1
			done
			kill -s SIGCONT $1
			shift
		done
		WAITING_PIDS="$*"
		echo "        " $NACTIVE running, $# queued
		badstatus=0
		while read event pid status
		do
			case "$event" in
			exit)
				if [ $status != 0 ]
				then
					echo "WARNING: Job $pid exited with status $status" 1>&2
					badstatus=$status
					BAD_PIDS="$BAD_PIDS $pid"
				fi
				ACTIVE_PIDS=`del_elem "$ACTIVE_PIDS" $pid`
				NACTIVE=$((NACTIVE-1))
				;;
			esac
		done <$QUEUE_FIFO
	done
	if [ -n "$BAD_PIDS" ]
	then
		echo "These processes had nonzero exit status: " $BAD_PIDS
		set $BAD_PIDS
		return $#
	fi
	return 0
}
