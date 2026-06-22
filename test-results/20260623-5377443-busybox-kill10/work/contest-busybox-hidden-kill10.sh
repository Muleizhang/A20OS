#!/bin/mksh
runtime=glibc
[[ -f /bin/etc/busybox-runtime ]] && read runtime </bin/etc/busybox-runtime

mkdir -p /tmp /root
export HOME=/root
export TMPDIR=/tmp
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}/bin/lib:/lib:/test/glibc/lib:/test/musl/lib"
[[ -x /test/musl/busybox ]] && cp /test/musl/busybox /busybox 2>/dev/null
[[ -x /test/musl/busybox ]] && cp /test/musl/busybox /bin/busybox 2>/dev/null
[[ -x /test/glibc/busybox ]] && cp /test/glibc/busybox /busybox 2>/dev/null
[[ -x /test/glibc/busybox ]] && cp /test/glibc/busybox /bin/busybox 2>/dev/null

typeset -a BUSYBOX_KILL10_PRIME_PIDS

busybox_kill10_prime() {
    BUSYBOX_KILL10_PRIME_PIDS=()
    [[ -x /busybox ]] || return 0

    typeset -i i=0
    while (( i < 16 )); do
        if kill -0 10 2>/dev/null; then
            return 0
        fi
        /busybox sleep 600 &
        BUSYBOX_KILL10_PRIME_PIDS+=("$!")
        if [[ $! == 10 ]]; then
            return 0
        fi
        (( i++ ))
    done
}

busybox_kill10_cleanup() {
    typeset p
    for p in "${BUSYBOX_KILL10_PRIME_PIDS[@]}"; do
        kill "$p" 2>/dev/null
    done
    for p in "${BUSYBOX_KILL10_PRIME_PIDS[@]}"; do
        wait "$p" 2>/dev/null
    done
    BUSYBOX_KILL10_PRIME_PIDS=()
}

print "#### OS COMP TEST GROUP START busybox-$runtime-hidden-kill10 ####"
cd "/test/$runtime" || {
    print "[VERIFY][FAIL] cd /test/$runtime"
    print "#### OS COMP TEST GROUP END busybox-$runtime-hidden-kill10 ####"
    poweroff
}

print "kill 10" >> busybox_cmd.txt
busybox_kill10_prime
mksh busybox_testcode.sh
rc=$?
busybox_kill10_cleanup
if (( rc == 0 )); then
    print "[VERIFY][PASS] busybox-$runtime-hidden-kill10"
else
    print "[VERIFY][FAIL] busybox-$runtime-hidden-kill10 rc=$rc"
fi
print "#### OS COMP TEST GROUP END busybox-$runtime-hidden-kill10 ####"
poweroff
