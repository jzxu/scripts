#!/bin/bash

stopped() {
	ps -o pid,stat a | awk -v pid="$1" 'BEGIN{s=1} $1==pid && $2~/^T/{s=0;exit} END{exit(s)}'
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
			exit 1
			;;
		esac
	fi
	
	queue_dir="$1"
	mkdir -p $queue_dir || { echo "queue directory creation failed" 1>&2; exit 1; }
	fifo="$queue_dir/fifo"
	mkfifo $fifo || { echo "fifo creation failed" 1>&2; exit 1; }
	
	if [ -z "$2" ]
	then
		echo 1 >"$queue_dir/nprocs"
	else
		echo "$2" >"$queue_dir/nprocs"
	fi
}

clear_queue() {
	if [ ! -d "$1" ]
	then
		echo "specify queue directory" >&2
		exit 1
	fi
	queue="$1"
	run_pids=`cat "$queue/running"`
	wait_pids=`cat "$queue/waiting"`
	echo Killing remaining jobs: $run_pids $wait_pids 1>&2
	kill -9 $run_pids $wait_pids
}

exit_queue() {
	queue="$1"
	pid="$2"
	code="$3"
	job_dir="$queue/$pid"
	echo `date` exit $code >>"$job_dir/status"
	echo exit $pid $code >"$queue/fifo"
}

init_job() {
	if [ ! -d "$1" ]
	then
		echo "specify queue directory" >&2
		exit 1
	fi
	queue="$1"

	trap "exit_queue $queue $BASHPID \$?" EXIT
	
	job_dir="$queue/$BASHPID"
	mkdir "$job_dir" || { echo "Cannot create $job_dir"; exit 1; }
	exec 1>"$job_dir/stdout"
	exec 2>"$job_dir/stderr"
	
	if [ -n "$*" ]
	then
		echo $* >"$job_dir/label"
	fi
	echo `date` queued >>"$job_dir/status"
	kill -s SIGSTOP $BASHPID
	echo `date` running >>"$job_dir/status"
}

reg_queue() {
	pid=$!
	if [ ! -d "$1" ]
	then
		echo "specify queue directory" >&2
		exit 1
	fi
	echo $pid >>$1/waiting
}

wait_queue() {
	if [ ! -d "$1" ]
	then
		echo "specify queue directory" >&2
		exit 1
	fi

	queue="$1"
	fifo="$queue/fifo"
	wait_list="$queue/waiting"
	run_list="$queue/running"
	done_list="$queue/done"
	fail_list="$queue/failed"
	nprocs=`cat $queue/nprocs`

	if [ ! -f "$wait_list" ]
	then
		return 0
	fi
	
	trap "{ clear_queue $queue; exit 1; }" SIGINT
	
	nwait=`wc -l <"$wait_list"`
	nrun=0
	while [ "$nwait" -gt 0 -o "$nrun" -gt 0 ]
	do
		while [ "$nrun" -lt $nprocs -a "$nwait" -gt 0 ]
		do
			pid=`head -n 1 "$wait_list"`
			
			# make sure process is stopped before issuing SIGCONT
			while ! stopped $pid
			do
				sleep 1
			done
			kill -s SIGCONT $pid

			nwait=$((nwait-1))
			nrun=$((nrun+1))
			sed -i "/^$pid\$/d" "$wait_list"
			echo $pid >>"$run_list"
		done
		printf "        %3d running, %3d queued\n" $nrun $nwait

		while read event pid status
		do
			case "$event" in
			exit)
				if ! grep -q "$pid" "$run_list"
				then
					echo "WARNING: unknown job $pid exited with status $status" 1>&2
				else
					if [ $status != 0 ]
					then
						echo "WARNING: Job $pid exited with status $status" 1>&2
						echo $pid >>"$fail_list"
					else
						echo $pid >>"$done_list"
					fi
					sed -i "/^$pid\$/d" "$run_list"
					nrun=$((nrun-1))
				fi
				;;
			esac
		done <"$fifo"
	done
	if [ -f "$fail_list" ]
	then
		failed=`cat $fail_list`
		echo "These processes had nonzero exit status: " $failed
		nfail=`wc -l <"$fail_list"`
		return $nfail
	fi

	trap - SIGINT
	return 0
}
