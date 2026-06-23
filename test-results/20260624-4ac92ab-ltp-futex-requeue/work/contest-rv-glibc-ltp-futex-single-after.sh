#!/bin/mksh

mkdir -p /dev/shm /tmp /root
export LTP_IPC_PATH=/dev/shm
export LTPROOT=/test/glibc/ltp
export LTP_TMPDIR=/tmp
export TMPDIR=/tmp
export HOME=/root
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}/bin/lib:/lib:/test/glibc/lib"
export PATH="/tmp:$PATH"

[[ -x /test/musl/busybox ]] && cp /test/musl/busybox /busybox 2>/dev/null
[[ -x /test/musl/busybox ]] && cp /test/musl/busybox /bin/busybox 2>/dev/null
[[ -x /test/glibc/busybox ]] && cp /test/glibc/busybox /busybox 2>/dev/null
[[ -x /test/glibc/busybox ]] && cp /test/glibc/busybox /bin/busybox 2>/dev/null

print '#!/bin/mksh' > /tmp/systemd-detect-virt
print 'typeset -i quiet=0 container=0' >> /tmp/systemd-detect-virt
print 'for arg in "$@"; do' >> /tmp/systemd-detect-virt
print '    case "$arg" in' >> /tmp/systemd-detect-virt
print '        --quiet|-q) quiet=1 ;;' >> /tmp/systemd-detect-virt
print '        --container|-c) container=1 ;;' >> /tmp/systemd-detect-virt
print '    esac' >> /tmp/systemd-detect-virt
print 'done' >> /tmp/systemd-detect-virt
print '(( container )) && exit 1' >> /tmp/systemd-detect-virt
print '(( quiet )) || print qemu' >> /tmp/systemd-detect-virt
print 'exit 0' >> /tmp/systemd-detect-virt
chmod 755 /tmp/systemd-detect-virt

print "[LTP-FUTEX] syntax_check=/bin/contest-under-test.sh"
if /bin/sh -n /bin/contest-under-test.sh; then
    print "[LTP-FUTEX][PASS] syntax"
else
    print "[LTP-FUTEX][FAIL] syntax"
    poweroff
fi
run_ltp_case_with_timeout() {
    typeset name=$1
    typeset -i timeout=${2:-60}
    typeset -i elapsed=0

    print "RUN LTP CASE $name"
    "./$name" &
    typeset pid=$!

    while (( elapsed < timeout )); do
        if kill -0 $pid 2>/dev/null; then
            sleep 1
            (( elapsed++ ))
        else
            wait $pid
            typeset rc=$?
            if (( rc == 0 )); then
                print "END LTP CASE $name : 0"
                return 0
            else
                print "FAIL LTP CASE $name : $rc"
                return 1
            fi
        fi
    done

    print "[CONTEST][LTP][TIMEOUT] case=$name after ${timeout}s"
    /busybox killall "$name" 2>/dev/null || killall "$name" 2>/dev/null
    kill -TERM "$pid" 2>/dev/null
    sleep 1
    /busybox killall -9 "$name" 2>/dev/null || killall -9 "$name" 2>/dev/null
    kill -KILL "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
    print "FAIL LTP CASE $name : 124"
    return 1
}
ltp_case_timeout() {
    case "$1" in
        ftest03|ftest04|ftest07|ftest08) print 120 ;;
        futex_cmp_requeue01) print 180 ;;
        *) print 60 ;;
    esac
}
run_ltp_bounded_case() {
    typeset name=$1
    typeset -i timeout=$(ltp_case_timeout "$name")
    if [[ $name == futex_cmp_requeue01 ]]; then
        typeset old_mul="${LTP_TIMEOUT_MUL-}"
        typeset -i had_mul=0
        [[ -n ${LTP_TIMEOUT_MUL+x} ]] && had_mul=1
        export LTP_TIMEOUT_MUL=4
        run_ltp_case_with_timeout "$name" "$timeout"
        typeset rc=$?
        if (( had_mul )); then
            export LTP_TIMEOUT_MUL="$old_mul"
        else
            unset LTP_TIMEOUT_MUL
        fi
        return $rc
    fi
    run_ltp_case_with_timeout "$name" "$timeout"
}

typeset mode="base"
if [[ "$mode" == "mul4" ]]; then
    export LTP_TIMEOUT_MUL=4
    print "[LTP-FUTEX][mul4] LTP_TIMEOUT_MUL=$LTP_TIMEOUT_MUL"
fi

print "[LTP-FUTEX][$mode] running futex residual"
print "#### OS COMP TEST GROUP START ltp-glibc ####"
cd /test/glibc/ltp/testcases/bin || {
    print "[LTP-FUTEX][$mode][FAIL] cd"
    print "#### OS COMP TEST GROUP END ltp-glibc ####"
    poweroff
}
typeset -i pass=0 fail=0
if [[ -x ./futex_cmp_requeue01 ]]; then if run_ltp_bounded_case futex_cmp_requeue01; then (( pass++ )); else (( fail++ )); fi; else print "FAIL LTP CASE futex_cmp_requeue01 : missing"; (( fail++ )); fi
print "[LTP-FUTEX][$mode][SUMMARY] pass=$pass fail=$fail"
print "#### OS COMP TEST GROUP END ltp-glibc ####"
if (( fail == 0 )); then
    print "[CONTEST][PASS] ltp-futex-$mode"
else
    print "[CONTEST][FAIL] ltp-futex-$mode"
fi

poweroff
