#! /vendor/bin/sh
ready=`getprop ro.vendor.bytedanceswap.ready`
if [ "${ready}" == "true" ]; then
    echo 100000000 > /proc/sys/kernel/swap_budget
fi

exit 0


