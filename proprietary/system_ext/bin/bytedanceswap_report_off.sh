#! /vendor/bin/sh

if [ -f /data/syslog/monitor/mem_swap/report.txt ]; then
            rm /data/syslog/monitor/mem_swap/report.txt
fi

setprop ro.vendor.bytedanceswap.init true

exit 0


