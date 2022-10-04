#! /vendor/bin/sh

if [ ! -f /data/vendor/swap/budget ]; then
    touch /data/vendor/swap/budget
    chmod 666 /data/vendor/swap/budget
fi

exit 0


