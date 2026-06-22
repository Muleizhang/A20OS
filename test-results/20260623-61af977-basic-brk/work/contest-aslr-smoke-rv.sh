#!/bin/sh
mkdir -p /bin
cp /test/musl/busybox /busybox 2>/dev/null
cp /test/musl/busybox /bin/busybox 2>/dev/null
cp /test/glibc/busybox /busybox 2>/dev/null
cp /test/glibc/busybox /bin/busybox 2>/dev/null
run_runtime() {
    root="$1"
    echo "#### OS COMP TEST GROUP START smoke-$root ####"
    cd "/test/$root" || poweroff
    ./busybox echo "testcase busybox echo success"
    ./busybox printf "testcase busybox printf success\n"
    ./busybox true
    echo "busybox true status: $?"
    if [ -x ./lua_testcode.sh ]; then
        ./lua_testcode.sh
    fi
    echo "#### OS COMP TEST GROUP END smoke-$root ####"
}
run_runtime glibc
run_runtime musl
poweroff
