#!/bin/sh
run_smoke() {
    root="$1"
    echo "#### OS COMP TEST GROUP START busybox-$root ####"
    cd "/test/$root" || poweroff
    ./busybox echo "testcase busybox echo success"
    ./busybox printf "testcase busybox printf success\n"
    ./busybox true
    echo "busybox true status: $?"
    echo "#### OS COMP TEST GROUP END busybox-$root ####"
}
run_smoke glibc
run_smoke musl
poweroff
