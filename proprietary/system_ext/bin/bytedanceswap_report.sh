#! /vendor/bin/sh

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

function read_var_from_string() {
    echo $1 > ${sdir}/tmp_report.txt
    while IFS=" " read -r rva rvb rvc rvd; do
	break
    done < ${sdir}/tmp_report.txt
}

function get_cloud_parameter() {
    local tmp
    local config_content
    local cloud_config_file
    local local_config_file
    disk_size=`getprop persist.vendor.bytedanceswap.disksize`
    cloud_config_file=/sdcard/smartisan/datasync/ufs_swap_config/ufs_swap_config
    local_config_file=/data/vendor/swap/ufs_swap_config

    if ! [ -f "${cloud_config_file}" ]; then
    	uptime=`awk '{print $1}' /proc/uptime`
    	divide1000 ${uptime}
    	uptime=${divide1000_result}
    	echo "wait cloud config: start uptime=${uptime}\n" >> ${sdir}/debug_report.txt
    	let "uptime = (90-$uptime)/2"
    	if [ "${uptime}" -gt 0 ]; then
    	    for dummy in $(seq ${uptime})
    	    do
    		if ! [ -f "${cloud_config_file}" ]; then
    		    sleep 2
    		else
		    echo "wait cloud config: end, waited time=${dummy}*5\n" >> ${sdir}/debug_report.txt
    		    break
    		fi
    	    done
    	fi
    fi

    for trycount in 1 2
    do
	if [ -f "${cloud_config_file}" ]; then
	    config_content=`cat ${cloud_config_file}`
	    echo "config_content:\n${config_content}\n" >> ${sdir}/debug_report.txt
	    tmp=`echo "${config_content}" | grep good_file_end_signature`
	    if [ -n "${tmp}" ]; then
		echo "-> good cloud config file end signature\n"  >> ${sdir}/debug_report.txt
		echo "${config_content}" > ${local_config_file}
		break
	    else
		echo "-> bad cloud config file end signature\n"  >> ${sdir}/debug_report.txt
		sleep 15
	    fi
	fi
    done
    # the cloud config mechanism officially usage mode is:
    # 1. when there is no config file, server create the file with the content from cloud config
    # 2. client read the file, send an intern to server that it has use up the file.
    # 3. server then mark in its database that next time when there is update on cloud, this file could be updated.
    # however we are shell script so work around are tried
    # 1. initially server want us to delete the config file so the cloud updated config could get into the config file.
    #    but it was found that the file is protected by capalibity
    # 2. so finally server decide to do specifically for our case that any time any update from cloud would forcely update the config file.
    #
    # so below the w/a of 1 is commented out, and we need to ensure the config content integrity by ourself, which is "good_file_end_signature" on above.
    #
    # if [ -f "${cloud_config_file}" ]; then
    # 	rm -f ${cloud_config_file}
    # fi

    config_content=`grep "swap.cloud" ${local_config_file}`

    tmp=`echo "${config_content}" | sed -n '/erasenum/p'|sed 's/^.*" *: *"//'|sed 's/[",]/ /g'`
    read_var_from_string "${tmp}"
    case ${disk_size} in
	128) erase_num=$rva;;
	256) erase_num=$rvb;;
	512) erase_num=$rvc;;
	1024) erase_num=$rvd;;
    esac
    if ! [ "${erase_num}" -ge 1 ]; then
	case ${disk_size} in
	    128) erase_num=1000;;
	    256) erase_num=1000;;
	    512) erase_num=1000;;
	    1024) erase_num=1000;;
	    *) erase_num=1000;;
	esac
    fi
    tmp=`echo "${config_content}" | sed -n '/percent/p'|sed 's/^.*" *: *"//'|sed 's/[",]/ /g'`
    read_var_from_string "${tmp}"
    case ${disk_size} in
	128) percent=$rva;;
	256) percent=$rvb;;
	512) percent=$rvc;;
	1024) percent=$rvd;;
    esac
    if ! [ "${percent}" -ge 1 ]; then
	case ${disk_size} in
	    128) percent=20;;
	    256) percent=30;;
	    512) percent=30;;
	    1024) percent=30;;
	    *) percent=20;;
	esac
    fi
    tmp=`echo "${config_content}" | sed -n '/months/p'|sed 's/^.*" *: *"//'|sed 's/[",]/ /g'`
    read_var_from_string "${tmp}"
    case ${disk_size} in
	128) months=$rva;;
	256) months=$rvb;;
	512) months=$rvc;;
	1024) months=$rvd;;
    esac
    if ! [ "${months}" -ge 1 ]; then
	case ${disk_size} in
	    128) months=36;;
	    256) months=36;;
	    512) months=36;;
	    1024) months=36;;
	    *) months=36;;
	esac
    fi

    tmp=`echo "${config_content}" | sed -n '/swapsize/p'|sed 's/^.*" *: *"//'|sed 's/[",]/ /g'`
    read_var_from_string "${tmp}"
    case ${disk_size} in
	128) swap_size=$rva;;
	256) swap_size=$rvb;;
	512) swap_size=$rvc;;
	1024) swap_size=$rvd;;
    esac

    if ! [ "${swap_size}" -ge 1 ]; then
	case ${disk_size} in
	    128) swap_size=6144;;
	    256) swap_size=8192;;
	    512) swap_size=8192;;
	    1024) swap_size=8192;;
	    *) swap_size=6144;;
	esac
    else
	setprop persist.vendor.bytedanceswap.size ${swap_size}
    fi
    health_config_valid=1
    tmp=`echo "${config_content}" | sed -n '/criticalhealtha/p'|sed 's/^.*" *: *"//'|sed 's/[",]/ /g'`
    read_var_from_string "${tmp}"
    case ${disk_size} in
	128) critical_health_a=$rva;;
	256) critical_health_a=$rvb;;
	512) critical_health_a=$rvc;;
	1024) critical_health_a=$rvd;;
    esac

    if ! [ "${critical_health_a}" -ge 1 ]; then
	case ${disk_size} in
	    128) critical_health_a=8;;
	    256) critical_health_a=8;;
	    512) critical_health_a=8;;
	    1024) critical_health_a=8;;
	    *) critical_health_a=8;;
	esac
	health_config_valid=0
    fi
    # critical_health_a=-1

    tmp=`echo "${config_content}" | sed -n '/criticalhealthb/p'|sed 's/^.*" *: *"//'|sed 's/[",]/ /g'`
    read_var_from_string "${tmp}"
    case ${disk_size} in
	128) critical_health_b=$rva;;
	256) critical_health_b=$rvb;;
	512) critical_health_b=$rvc;;
	1024) critical_health_b=$rvd;;
    esac

    if ! [ "${critical_health_b}" -ge 1 ]; then
	case ${disk_size} in
	    128) critical_health_b=8;;
	    256) critical_health_b=8;;
	    512) critical_health_b=8;;
	    1024) critical_health_b=8;;
	    *) critical_health_b=8;;
	esac
	health_config_valid=0
    fi

    tmp=`echo "${config_content}" | sed -n '/maxbudget/p'|sed 's/^.*" *: *"//'|sed 's/[",]/ /g'`
    read_var_from_string "${tmp}"
    case ${disk_size} in
	128) max_budget=$rva;;
	256) max_budget=$rvb;;
	512) max_budget=$rvc;;
	1024) max_budget=$rvd;;
    esac

    if ! [ "${max_budget}" -ge 1 ]; then
	case ${disk_size} in
	    128) max_budget=80;;
	    256) max_budget=80;;
	    512) max_budget=80;;
	    1024) max_budget=80;;
	    *) max_budget=80;;
	esac
    fi

    tmp=`echo "${config_content}" | sed -n '/minbudget/p'|sed 's/^.*" *: *"//'|sed 's/[",]/ /g'`
    read_var_from_string "${tmp}"
    case ${disk_size} in
	128) min_budget=$rva;;
	256) min_budget=$rvb;;
	512) min_budget=$rvc;;
	1024) min_budget=$rvd;;
    esac

    if ! [ "${min_budget}" -ge 1 ]; then
	case ${disk_size} in
	    128) min_budget=50;;
	    256) min_budget=50;;
	    512) min_budget=50;;
	    1024) min_budget=50;;
	    *) min_budget=50;;
	esac
    fi

    echo cloud parameters: >> ${sdir}/debug_report.txt
    echo "disk_size=${disk_size} erase_num=${erase_num} percent=${percent} months=${months} max_budget=${max_budget} min_budget=${min_budget}\n" >> ${sdir}/debug_report.txt
    echo "swap_size=${swap_size} health_config_valid=${health_config_valid} critical_health_a=${critical_health_a} critical_health_b=${critical_health_b}\n" >> ${sdir}/debug_report.txt
}
function budget() {
    local line_swap=0
    local line_all=0
    local str
    local recent_write_swap_M=0
    local recent_write_all_M=0
    local swap_diff=0
    local all_diff=0
    local diff=0
    local est_orig=0
    local tmp=0


    # base budget caculation:
    # unit disk_size=G
    let daily_swap_budget=${disk_size}*${erase_num}
    # by default suppose we could use this swap function for about 3 years
    let daily_swap_budget=${daily_swap_budget}/$months
    let daily_swap_budget=${daily_swap_budget}/30
    let daily_all_budget=${daily_swap_budget}
    let daily_swap_budget=${daily_swap_budget}*${percent}/100
    echo base caculation result: >> ${sdir}/debug_report.txt
    echo "daily_swap_budget=${daily_swap_budget} daily_all_budget=${daily_all_budget}\n"  >> ${sdir}/debug_report.txt

    # long term budget caculation(base on disk health value):
    if [ "${esta}" -gt "${estb}" ] ; then
	est=${esta}
    else
	est=${estb}
    fi
    est_orig=${est}
    let est=${est}*10-10
    let est=100-${est}/3
    if [ "${est_orig}" -lt 5 ] ; then
	let est=${est}+20
    fi

    let daily_swap_budget=${daily_swap_budget}*${est}/100
    let daily_swap_longterm_budget=${daily_swap_budget}
    echo long term caculation result:  >> ${sdir}/debug_report.txt
    echo "daily_swap_budget=${daily_swap_budget} esta=${esta} estb=${estb} est=${est}\n"  >> ${sdir}/debug_report.txt

    # short term budget caculation(base on recent storage swap usage):
    line_swap=0
    while read str ; do
	let recent_write_swap_M=${recent_write_swap_M}+${str}
	let "line_swap=${line_swap}+1"
    done < ${sdir}/recent_write_swap.txt
    let swap_diff=${daily_swap_budget}*${line_swap}-${recent_write_swap_M}/1000
    if [ "${line_swap}" -gt 0 ] ; then
	let swap_diff=${swap_diff}/${line_swap}
    fi

    line_all=0
    while read str ; do
	let recent_write_all_M=${recent_write_all_M}+${str}
	let "line_all=${line_all}+1"
    done < ${sdir}/recent_write_all.txt
    let all_diff=${daily_all_budget}*${line_all}-${recent_write_all_M}/1000
    if [ "${line_all}" -gt 0 ] ; then
	let all_diff=${all_diff}/${line_all}
    fi

    # setting:
    # 1) if both >0, use 1/2 of both diff
    # 2) if both <0, use larger one (but means use less one of diff to reduce from budget)
    # 3) if one<0 another>0, use 1/2 of the larger one.
    if [ "${swap_diff}" -gt "${all_diff}" ] ; then
    	diff=${swap_diff}
    else
    	diff=${all_diff}
    fi
    if [ "${all_diff}" -le 0 ] && [ "${swap_diff}" -gt 0 ] ; then
    	let diff=${swap_diff}/2
    fi
    if [ "${all_diff}" -gt 0 ] && [ "${swap_diff}" -le 0 ] ; then
    	let diff=${all_diff}/3
    fi
    if [ "${all_diff}" -gt 0 ] && [ "${swap_diff}" -gt 0 ] ; then
	let "diff=${swap_diff}/2+${all_diff}/3"
    fi

    # final fixup the diff
    if [ "${diff}" -gt 0 ]; then
	let "diff=${diff}*3/2"
    fi

    let daily_swap_budget=${daily_swap_budget}+${diff}


    # last min/max fixup.
    let "tmp=${min_budget}*${daily_swap_longterm_budget}/100"
    if [ "${daily_swap_budget}" -lt "${tmp}" ]; then
	let "daily_swap_budget=${tmp}"
    fi
    let "tmp=${max_budget}*${daily_all_budget}/100"
    if [ "${daily_swap_budget}" -gt "${tmp}" ]; then
	let "daily_swap_budget=${tmp}"
    fi

    echo final caculation result:  >> ${sdir}/debug_report.txt
    echo recent_write_all_M=${recent_write_all_M} all_diff=${all_diff} line_all=${line_all} recent_write_swap_M=${recent_write_swap_M} swap_diff=${swap_diff} line_swap=${line_swap} >> ${sdir}/debug_report.txt
    echo "daily_swap_budget=${daily_swap_budget} diff=${diff}\n" >> ${sdir}/debug_report.txt


    if [ "${daily_swap_budget}" -lt 0 ] ; then
	daily_swap_budget=0
    fi

    if [ "${eol}" -gt 1 ] || [ "${swap_unavailable}" == "true" ] ; then
	# 10000000 is a communicate code with kernel that ufs has wear out

	setprop persist.vendor.bytedanceswap.enable false

	daily_swap_budget=10000000
	echo "daily_swap_budget=10000000 because eol=${eol} unavailable=${swap_unavailable} at `date +"%T.%N"`\n"  >> ${sdir}/debug_report.txt
    fi

    if [ ! -f /data/vendor/swap/budget ]; then
    	touch /data/vendor/swap/budget
	# this 666 of here is necessory as the same 666 in kernel only create file with 600, and swap enable sh of root role need access this file
    	chmod 666 /data/vendor/swap/budget
    fi
    echo ${daily_swap_budget} > /proc/sys/kernel/swap_budget
    sleep 5
    echo "/proc/sys/kernel/swap_budget" >> ${sdir}/debug_report.txt
    cat /proc/sys/kernel/swap_budget >> ${sdir}/debug_report.txt
    echo "/data/vendor/swap/budget" >> ${sdir}/debug_report.txt
    cat /data/vendor/swap/budget >> ${sdir}/debug_report.txt
    echo "" >> ${sdir}/debug_report.txt
}


# $1=today data
# $2=file
function process_statistic() {
    local line=`wc -l $2 2>/dev/null|awk '{print $1}'`
    local now=0
    local last=0
    local diff=0
    local remainder=0
    # so, else totalxxx is global variable

    if [ -z "$line" ]; then
	echo "$1\t$1\t$1\t$1\t$1\t$1\t${timestr}\trebooted=1" > $2
	return 0
    fi
    read -r last diff totalM10 totalM30 totalM100 totalMall dummy1 dummy2 last_reboot remainder < $2
    if [ -z "$last" ]; then
	return 0
    fi
    # clean 10days accumulation
    if [ "${day10}" -eq 0 ]; then
	totalM10=0
    fi
    # clean 100days accumulation
    if [ "${day30}" -eq 0 ]; then
	totalM30=0
    fi

    # clean 100days accumulation
    if [ "${day100}" -eq 0 ]; then
	totalM100=0
    fi

    if [ "${rebooted}" -eq 1 ]; then
	last=0
    fi

    let diff=$1-$last

    # ensure diff >=0
    if [ "${diff}" -lt 0 ]; then
	let diff=0
    fi

    let now=$1
    let totalM10=$totalM10+$diff
    let totalM30=$totalM30+$diff
    let totalM100=$totalM100+$diff
    let totalMall=$totalMall+$diff

    sed -i "1s/^/${now}\t${diff}\t${totalM10}\t${totalM30}\t${totalM100}\t${totalMall}\t${timestr}\trebooted=${rebooted}\n/" $2

    if [ "$line" -gt 20 ]; then
	sed -i '$ d' $2
    fi


    # rebooted=0 rebooted=1
    last_reboot=${last_reboot: -1}
    # I only want to include whole day usage for this file that used to caculate average day write data amount
    # if else consider a device that reboot server times each day, then the average value would be hard underestimated
    if [ "${rebooted}" -eq 0 ] && [ "${last_reboot}" -eq 0 ]; then
	line=`wc -l $3 2>/dev/null|awk '{print $1}'`
	if [ -z "$line" ]; then
	    echo "$1" > $3
	else
	    sed -i "1s/^/${diff}\n/" $3
	    let "line=${line}-59"
	    if [ "$line" -ge 1 ]; then
    		for dummy in $(seq ${line})
    		do
		    sed -i '$ d' $3
    		done
	    fi
	fi
    fi
}


function main() {
    # the below is only necessary for anroid q,  that use restart_period way to restart this serices for each day
    # swap_stat=`grep pswpout /proc/vmstat |awk '{print $2}'`
    # # when service got run after first boot, it could be very early of booting so no this /proc/vmstat is not ready, so just quit
    # # actually we also do not want the data just after reboot
    # if [ -z "${swap_stat}" ]; then
    #     exit 0
    # fi

    # A delay would necessary when in android Q that use restart_period in init.rc
    # 1) avoid any possibility for the stat node not get ready
    # 2) in case thing get too bad this give user time to open the setup app to disable the ufs swap feature
    # sleep 80

    sdir=/data/vendor/swap
    tdir=/data/syslog/monitor/mem_swap
    rebooted=0

    echo > ${sdir}/debug_report.txt
    swap_enable=`getprop persist.vendor.bytedanceswap.enable`
    if ! [ "${swap_enable}" == "true" ]; then
	exit 0
    fi

    rebooted=`getprop ro.vendor.bytedanceswap.rebooted`
    if [ "${rebooted}" != "true" ]; then
	setprop ro.vendor.bytedanceswap.rebooted true
	rebooted=1
    else
	rebooted=0
    fi

    get_cloud_parameter

    cat /sys/bus/platform/drivers/ufshcd-qcom/1d84000.ufshc/health_descriptor/* |awk '{print}' ORS=' ' > ${sdir}/ufs_health.txt
    echo >> ${sdir}/ufs_health.txt
    sed "1s/0x//gi" ${sdir}/ufs_health.txt >${sdir}/tmp_report.txt
    while IFS=" " read -r eol esta estb remainder; do
	let "eol=$((16#${eol}))"
	let "esta=$((16#${esta}))"
	let "estb=$((16#${estb}))"
	break
    done < ${sdir}/tmp_report.txt
    echo orig:  eol=${eol} esta=${esta} estb=${estb} >> ${sdir}/ufs_health.txt
    # add below checking as once I saw blank esta/estb due to either
    # 1) using [let estb=$((16#${estb}))] that without the quote wrapper
    # 2) the tmp.txt is not accessible for this script that run as system role
    if [ "${eol}" -ge 1 ] && [ "${eol}" -le 3 ] ; then
	:
    else
	eol=1
    fi
    if [ "${esta}" -ge 1 ] && [ "${esta}" -le 11 ] ; then
	:
    else
	esta=1
    fi
    if [ "${estb}" -ge 1 ] && [ "${estb}" -le 11 ] ; then
	:
    else
	estb=1
    fi
    echo "fixup: eol=${eol} esta=${esta} estb=${estb}" >> ${sdir}/ufs_health.txt

    # health_config_valid is to avoid case of
    # 1) health is above health_a health_b(that i.e 6) values of config file, that is unavailable=true
    # 2) on rebooting, enable sh would delete the swapfile
    # 3) still on rebooting, this sh can be run when config file of (vendor) is not available yet, so we might use default config value
    # 3) the default value is 8, then this sh set unavailable=false
    # 4) reboot, then we would create the swapfile again
    if [ "${health_config_valid}" -eq 0 ] ; then
	swap_unavailable=`getprop persist.vendor.bytedanceswap.unavailable`
	if [ "${swap_unavailable}" == "true" ] || [ "${swap_unavailable}" == "false" ] ; then
	    :
	else
	    # if no previous unavailable setting, then still use our default value.
	    health_config_valid=1
	fi
    fi
    if [ "${health_config_valid}" -eq 1 ] ; then
    	if [ "$eol" -gt 1 ] || [ "${esta}" -gt "${critical_health_a}" ] || [ "${estb}" -gt "${critical_health_b}" ] ; then
	    setprop persist.vendor.bytedanceswap.unavailable true
	    swap_unavailable=true
	else
	    setprop persist.vendor.bytedanceswap.unavailable false
	    swap_unavailable=false
	fi
    fi

    budget

    # report even with swap_unavailable=true, so that crashreport has info that the device has disabled swap

    day10=1
    day30=1
    day100=1
    day=`date +%j`
    let "day10 = $day % 10"
    let "day30 = $day % 30"
    let "day100 = $day % 100"
    timestr=`date  +"%Y-%m-%d %T"`
    uptime_h="`uptime -s`"

    # *********************** Collecting Data **************************

    echo "now=\t${timestr}\nuptime=\t${uptime_h}" > ${sdir}/date.txt


    swap_stat=`grep pswpout /proc/vmstat |awk '{print $2}'`
    if [ -z "${swap_stat}" ]; then
	exit 0
    fi
    zram_stat=`grep "zram0" /proc/diskstats |awk '{print $10}'`
    if [ -z "${zram_stat}" ]; then
	exit 0
    fi

    # tranlate data to MB size
    divide1000 ${swap_stat}
    let swap_stat=${divide1000_result}*4
    divide1000 ${zram_stat}
    let zram_stat=${divide1000_result}/2

    let swap_stat=${swap_stat}-${zram_stat}

    if [ "${swap_stat}" -lt 0 ]; then
	let swap_stat=0
    fi

    process_statistic ${swap_stat} "${sdir}/swap_stat.txt" "${sdir}/recent_write_swap.txt"
    # comment out these as assuming the budget() function should work
    # if [ "${totalM30}" -gt 8000000 ] || [ "${totalM100}" -gt 16000000 ] || [ "${totalMall}" -gt 50000000 ]; then
    # 	setprop persist.vendor.bytedanceswap.unavailable true
    # fi


    sda_stat=`grep "sda " /proc/diskstats |awk '{print $10}'`
    divide1000 ${sda_stat}
    let sda_stat=${divide1000_result}/2
    process_statistic ${sda_stat} "${sdir}/sda_stat.txt" "${sdir}/recent_write_all.txt"

    grep pswpout /proc/vmstat  > ${sdir}/all_stat.txt
    grep "zram0" /proc/diskstats >> ${sdir}/all_stat.txt
    grep "sda " /proc/diskstats >> ${sdir}/all_stat.txt


    cat /proc/swaps  > ${sdir}/mem.txt
    cat /proc/meminfo >> ${sdir}/mem.txt



    # *********************** Report Data **************************
    mkdir ${tdir}
    echo "******************************* date.txt *******************************" > ${tdir}/report.txt
    cat ${sdir}/date.txt >> ${tdir}/report.txt
    echo "******************************* swap_stat.txt *******************************" >> ${tdir}/report.txt
    cat ${sdir}/swap_stat.txt >> ${tdir}/report.txt
    echo "******************************* sda_stat.txt *******************************" >> ${tdir}/report.txt
    cat ${sdir}/sda_stat.txt >> ${tdir}/report.txt
    echo "******************************* all_stat.txt *******************************" >> ${tdir}/report.txt
    cat ${sdir}/all_stat.txt >> ${tdir}/report.txt
    echo "******************************* ufs_health.txt *******************************" >> ${tdir}/report.txt
    cat ${sdir}/ufs_health.txt >> ${tdir}/report.txt
    echo "******************************* mem.txt *******************************" >> ${tdir}/report.txt
    cat ${sdir}/mem.txt >> ${tdir}/report.txt
    echo "******************************* recent_write_all.txt *******************************" >> ${tdir}/report.txt
    cat ${sdir}/recent_write_all.txt >> ${tdir}/report.txt
    echo "******************************* recent_write_swap.txt *******************************" >> ${tdir}/report.txt
    cat ${sdir}/recent_write_swap.txt >> ${tdir}/report.txt
    echo "******************************* debug_enable.txt *******************************" >> ${tdir}/report.txt
    cat ${sdir}/debug_enable.txt >> ${tdir}/report.txt
    echo "******************************* debug_report.txt *******************************" >> ${tdir}/report.txt
    cat ${sdir}/debug_report.txt >> ${tdir}/report.txt

    chmod 775 ${tdir}
    chmod 666 ${tdir}/report.txt
}



enable_done=`getprop ro.vendor.bytedanceswap.enable_done`
if [ "${enable_done}" == "true" ]; then
    main
fi


exit 0


