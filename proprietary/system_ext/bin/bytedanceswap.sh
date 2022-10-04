#! /vendor/bin/sh

function read_var_from_string() {
    echo $1 > ${sdir}/tmp_enable.txt
    while IFS=" " read -r rva rvb rvc rvd; do
	break
    done < ${sdir}/tmp_enable.txt
}

function get_disk_swap_size() {
    local tmp
    # /sys/class/block/sda/size also return sectors, could be another option
    disk_size=`getprop persist.vendor.bytedanceswap.disksize`
    if ! [ "${disk_size}" -ge 1 ]; then
	disk_size=`grep -E "sda$" /proc/partitions | awk '{print $3}'`
	divide1000 ${disk_size}
	for dummy in 1
	do
	    if [ "${divide1000_result}" -ge 1200000 ];then
		disk_size=2048
		break
	    fi
	    if [ "${divide1000_result}" -ge 530000 ];then
		disk_size=1024
		break
	    fi
	    if [ "${divide1000_result}" -ge 270000 ];then
		disk_size=512
		break
	    fi
	    if [ "${divide1000_result}" -ge 140000 ];then
		disk_size=256
		break
	    fi
	    disk_size=128
	done
	setprop persist.vendor.bytedanceswap.disksize ${disk_size}
    fi
    cloud_config=`grep "swap.cloud" /data/vendor/swap/ufs_swap_config`
    tmp=`echo "${cloud_config}" | sed -n '/swapsize/p'|sed 's/^.*" *: *"//'|sed 's/[",]/ /g'`
    read_var_from_string "${tmp}"
    case ${disk_size} in
	128) swap_size=$rva;;
	256) swap_size=$rvb;;
	512) swap_size=$rvc;;
	1024) swap_size=$rvd;;
    esac

    if ! [ "${swap_size}" -ge 1 ]; then
	swap_size=`getprop persist.vendor.bytedanceswap.size`
	if ! [ "${swap_size}" -ge 1 ]; then
	    case ${disk_size} in
		128) swap_size=6144;;
		256) swap_size=8192;;
		512) swap_size=8192;;
		1024) swap_size=8192;;
		*) swap_size=6144;;
	    esac
	fi
    fi

    return ${disk_size}
}

function divide1000() {
    local  len=${#1}
    if [ "${len}" -gt 3 ]; then
	let len=$len-3
	divide1000_result=${1:0:${len}}
	return 0
    else
	divide1000_result=0
	return 1
    fi
}

function bytedance_enable_swap() {
    local dd_seek
    local dd_bs
    local dd_all
    local dd_force=0
    local need_create=0
    local need_delete=0
    local tmp1=0
    local tmp2=0
    local exist=0
    local status=0
    local local_uptime=0
    local final_success=0
    swap_enable=`getprop persist.vendor.bytedanceswap.enable`
    swap_enabled=`getprop ro.vendor.bytedanceswap.enabled`
    # swap_enabled=`false`
    swap_unavailable=`getprop persist.vendor.bytedanceswap.unavailable`
    swap_file_path="/data/vendor/swap/swapfile"
    debug_enable_path="/data/vendor/swap/debug_enable.txt"
    sdir=/data/vendor/swap
    echo  "***starting enable swap****\ndate=`date`\n" > ${debug_enable_path}
    chmod 640 ${debug_enable_path}
    if [ "${swap_unavailable}" != "true" ]; then
	if [ "${swap_enable}" == "true" ] && [ "${swap_enabled}" != "true" ]; then
	    setprop ro.vendor.bytedanceswap.enabled true
	    get_disk_swap_size
	    echo "disk_size=${disk_size} swap_size=${swap_size}\n" >> ${debug_enable_path}

	    uptime=`awk '{print $1}' /proc/uptime`
	    divide1000 ${uptime}
	    uptime=${divide1000_result}
	    echo "uptime:" >> ${debug_enable_path}
	    echo "${uptime}\n" >> ${debug_enable_path}

	    if [ ! -f ${swap_file_path} ]; then
		exist=0
		swap_file_size=0
		echo "swap file does not exist" >> ${debug_enable_path}
	    else
		exist=1
		swap_file_size=`stat -c %s ${swap_file_path}`
		# now is Bytes
		echo "file exist swap_file_size:" >> ${debug_enable_path}
		echo ${swap_file_size} >> ${debug_enable_path}
		divide1000 ${swap_file_size}
		swap_file_size=${divide1000_result}
		divide1000 ${swap_file_size}
		# till now is mB
		swap_file_size=${divide1000_result}
		echo "${swap_file_size}\n" >> ${debug_enable_path}
	    fi

	    let "tmp1 = swap_size - swap_file_size"
	    let "tmp2 = swap_size / 10"
	    let "tmp3 = tmp2 + swap_size"
	    if [ "${tmp1}" -ge "${tmp2}" ] || [ "${swap_file_size}" -ge "${tmp3}" ]; then
		partition_free=`stat -f "%f" /data`
		echo "${partition}" >> ${debug_enable_path}
		partition_free=`echo "${partition_free}"|sed -n '/Blocks: Total:/p'|awk '{print $5}'`
		# till now is 4KB as unit
		divide1000 ${partition_free}
		# till now is MB as unit
		let partition_free=${divide1000_result}*4
		let "tmp1 = swap_file_size + partition_free - swap_size - 2000"
		echo "free=${partition_free}\n" >> ${debug_enable_path}
		if [ "${tmp1}" -ge 0 ]; then
		    if [ "${exist}" -eq 1 ]; then
			need_delete=1
		    fi
		    need_create=1
		fi
	    fi
	    ddcomplete=`getprop persist.vendor.bytedanceswap.ddcomplete`
	    if [ "${ddcomplete}" != "true" ] ; then
		echo "last dd didn't complete(or not set before), failed at ${ddcomplete}, setting dd_force=1" >> ${debug_enable_path}
		dd_force=1;
		setprop persist.vendor.bytedanceswap.ddcomplete false
	    fi

	    # my experience, after dd complete, swapon failes at 1/20 chance.
	    # this could be OK as after the reboot we will do swapfile generation and mkswap+swapon again
	    # but retry immediately might have better user experience.
	    for trycount in 1 2
	    do
		echo "------trycount=${trycount}------" >> ${debug_enable_path}
		if [ "${trycount}" -eq 2 ]; then
		    need_delete=1
		fi
		if [ "${need_delete}" -eq 1 ]; then
		    rm -f ${swap_file_path}
		    need_create=1
		fi
		if [ "${need_create}" -eq 1 ]; then
		    # use fallocate to occupy the disk blocks.
		    setprop persist.vendor.bytedanceswap.ddcomplete false
		    echo "doing fallocate" >> ${debug_enable_path}
		    fallocate -l ${swap_size}M ${swap_file_path}
		    status=$?
		    if [ "${status}" -ne 0 ]; then
			echo "fallocate error status=${status}" >> ${debug_enable_path}
			continue
		    fi
		    dd_force=1;
		fi

		if [ "${dd_force}" -eq 1 ]; then
		    let local_uptime=480-$uptime
		    if [ "${local_uptime}" -gt 0 ]; then
			dd_bs=128
		    else
			dd_bs=128
		    fi
		    dd_seek=0

		    let dd_all=${swap_size}/${dd_bs}
		    echo "doing dd: dd_all=${dd_all} dd_bs=${dd_bs} swap_size=${swap_size}" >> ${debug_enable_path}
		    while [ "${dd_seek}" -lt "${dd_all}" ]
		    do
			dd if=/dev/zero of=${swap_file_path} bs=${dd_bs}m count=1 seek=${dd_seek} conv=notrunc
			status=$?
			if [ "${status}" -ne 0 ]; then
			    echo "dd error at dd_seek=${dd_seek} status=${status}" >> ${debug_enable_path}
			    setprop persist.vendor.bytedanceswap.ddcomplete ${dd_seek}
			    continue
			fi
			let dd_seek=${dd_seek}+1
			# for darwin 512G devices of 8G swapfile, when 0.3/0.4, use 31/38 seconds, if manually dd to create swapfile, use 10.8 seconds, so use about 1/3 bandwidth
			# for darwin 128G devices of 6G swapfile, when 1/0.3/0.4, use 59/25/29 seconds, if manually dd to create swapfile, use 10.5 seconds, so use about 40/36% bandwidth
			sleep 0.4
		    done
		    echo "dd done" >> ${debug_enable_path}
		    setprop persist.vendor.bytedanceswap.ddcomplete true
		fi
		mkswap ${swap_file_path}
		status=$?
		if [ "${status}" -ne 0 ]; then
		    rm -f ${swap_file_path}
		    echo "mkswap error status=${status}" >> ${debug_enable_path}
		    continue
		fi
		swapon ${swap_file_path} -p 10000
		status=$?
		if [ "${status}" -ne 0 ]; then
		    rm -f ${swap_file_path}
		    echo "swapon error status=${status}" >> ${debug_enable_path}
		    continue
		fi
		final_success=1
		break
	    done

    	    if [ "${final_success}" -eq 0 ]; then
		return 1
	    fi
	    echo "bytedance_enable_swap complete" >> ${debug_enable_path}
	    return 0
	fi
	echo "prop enable = ${swap_enable} or enabled = ${swap_enabled}" >> ${debug_enable_path}
	return 1
    else
	echo "swap_unavailable=${swap_unavailable}" >> ${debug_enable_path}
	return 0
    fi
}


sdir=/data/vendor/swap
tdir=/data/syslog/monitor/mem_swap
bytedance_enable_swap
status=$?
if [ "${status}" -ne 0 ]; then
    echo "bytedance_enable_swap error" >> ${debug_enable_path}
    # for unavailable=true the update of 0 budget would be in report.sh
    if [ "${swap_enable}" == "false" ]; then
	# date with nanosecond
	echo "swap_enable=${swap_enable} so set budget to 0 at `date +"%T.%N"`" >> ${debug_enable_path}
	echo 0 > /proc/sys/kernel/swap_budget
    fi
else
    uptime_done=`awk '{print $1}' /proc/uptime`
    divide1000 ${uptime_done}
    let uptime_done=${uptime_done}-${uptime}
    # date with nanosecond
    echo "bytedance_enable_swap() time: ${uptime}->${uptime_done} at `date +"%T.%N"`" >> ${debug_enable_path}
    # user build would show screen after 18 seconds of booting, since the running
    # of report.sh seems take some time so add a delay to avoid possibility of
    # slowing down first screen
    let "uptime_done=20-${uptime_done}"
    if [ "${uptime_done}" -gt 0 ]; then
    	echo "sleep ${uptime_done} seconds until screen on" >> ${debug_enable_path}
    	sleep ${uptime_done}
    fi
    if [ "${swap_unavailable}" != "true" ]; then
	setprop ro.vendor.bytedanceswap.ready true
	setprop ro.vendor.bytedanceswap.free.report true
    fi
    setprop ro.vendor.bytedanceswap.enable_done true
    setprop persist.vendor.bytedanceswap.report true
fi
exit 0
