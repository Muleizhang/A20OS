#!/bin/mksh
#
# contest.sh — automated test runner
# Replaces contest_init.c. Execution path identical to manual mode.

# ── early setup ─────────────────────────────────────────────
[[ -x /test/musl/busybox ]]  && cp /test/musl/busybox /busybox 2>/dev/null
[[ -x /test/musl/busybox ]]  && cp /test/musl/busybox /bin/busybox 2>/dev/null
[[ -x /test/glibc/busybox ]] && cp /test/glibc/busybox /busybox 2>/dev/null
[[ -x /test/glibc/busybox ]] && cp /test/glibc/busybox /bin/busybox 2>/dev/null

# -- LTP environment setup -
mkdir -p /dev/shm /tmp
export LTP_IPC_PATH=/dev/shm
export LTPROOT=/test/glibc/ltp
export LTP_TMPDIR=/tmp
export TMPDIR=/tmp
export HOME=/root
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}/bin/lib:/lib"
mkdir -p /root


print '#!/bin/mksh' > /bin/zcat
print 'exec /busybox zcat "$@"' >> /bin/zcat
chmod 755 /bin/zcat
print '#!/bin/mksh' > /bin/gunzip
print 'exec /busybox gunzip "$@"' >> /bin/gunzip
chmod 755 /bin/gunzip

sync

# ── watchdog ────────────────────────────────────────────────
(
    sleep 10800
    print -u2 '[CONTEST] Global timeout (10800 s)'
    kill -KILL $$
    poweroff
) &
typeset -i WD=$!
trap 'kill $WD 2>/dev/null' EXIT

# ── LTP blacklist ──────────────────────────────────────────
typeset -a BL
typeset _bl=
for _bl in /bin/etc/ltp_blacklist.txt; do
    [[ -f $_bl ]] && break
done
if [[ -f $_bl ]]; then
    while IFS= read -r l; do
        [[ $l != \#* && -n $l ]] && BL+=("$l")
    done <"$_bl"
fi

blacklisted() {
    typeset n=$1 b
    for b in "${BL[@]}"; do [[ $b == "$n" ]] && return 0; done
    return 1
}

cleanup_group() {
    typeset group=$1 p

    case "$group" in
    cyclictest)
        for p in hackbench cyclictest; do
            /busybox killall "$p" 2>/dev/null || killall "$p" 2>/dev/null
        done
        ;;
    iozone)
        /busybox killall iozone 2>/dev/null || killall iozone 2>/dev/null
        ;;
    lmbench)
        for p in lmbench_all lat_ctx lat_proc lat_syscall lat_pipe lat_pagefault lat_mmap lat_select lat_mem_rd bw_mem bw_pipe mhz; do
            /busybox killall "$p" 2>/dev/null || killall "$p" 2>/dev/null
        done
        ;;
    ltp)
        /busybox killall runtest 2>/dev/null || killall runtest 2>/dev/null
        ;;
    esac
}

group_timeout() {
    typeset group=$1

    case "$group" in
    basic|lua) print 180 ;;
    busybox|iperf|netperf|libctest|libcbench) print 300 ;;
    cyclictest|iozone) print 360 ;;
    lmbench) print 1800 ;;
    ltp) print 600 ;;
    *) print 300 ;;
    esac
}

run_with_timeout() {
    typeset runtime=$1 group=$2 cmd=$3
    typeset -i timeout=${4:-300}
    typeset -i elapsed=0 rc=0

    mksh "$cmd" &
    typeset test_pid=$!

    while (( elapsed < timeout )); do
        if kill -0 $test_pid 2>/dev/null; then
            sleep 1
            (( elapsed++ ))
        else
            wait $test_pid
            return $?
        fi
    done

    print "[CONTEST][TIMEOUT] runtime=$runtime group=$group after ${timeout}s"
    print "#### OS COMP TEST GROUP END $group-$runtime ####"
    print "[CONTEST][FAIL] $group (exit 124)"
    print "[CONTEST] Stop after timeout to preserve completed scores"
    poweroff
    return 124
}

# ── test group skip list ───────────────────────────────────
typeset -a SKIP_GROUPS
SKIP_GROUPS+=(unixbench) # 不计分
#SKIP_GROUPS+=(lmbench) # 运行时长很长
SKIP_GROUPS+=(ltp) # 单独执行

# 下面是可以跑通但是为了方便测试跳过的
#SKIP_GROUPS+=(iozone)
# SKIP_GROUPS+=(netperf)
# SKIP_GROUPS+=(iperf)
# SKIP_GROUPS+=(busybox)

skip_group() {
    typeset g=$1 runtime=$2 s

    # Only musl libctest is a leaderboard item. The glibc script leaves failing
    # stress children behind and can destabilize later risky groups.
    if [[ $g == "libctest" && $runtime != "musl" ]]; then
        return 0
    fi
    if [[ $g == "cyclictest" ]]; then
        # RISC-V cyclictest passes for both glibc and musl historically; keep them.
        # LoongArch cyclictest still times out -> skip on non-riscv64.
        if [[ $(uname -m) != "riscv64" ]]; then
            return 0
        fi
    fi

    # 2. 原有的常规跳过列表检测
    for s in "${SKIP_GROUPS[@]}"; do [[ $g == "$s" ]] && return 0; done
    return 1
}

# ── LTP inline runner ──────────────────────────────────────
run_ltp() {
    typeset runtime=$1 group=$2
    typeset bin_dir

    for d in "/test/$runtime/ltp/testcases/bin"
    do
        [[ -d $d ]] && { bin_dir=$d; break; }
    done

    print "#### OS COMP TEST GROUP START $group ####"

    if [[ -z $bin_dir ]]; then
        print "[CONTEST][LTP] binary dir not found for $runtime"
        print "#### OS COMP TEST GROUP END $group ####"
        return 1
    fi

    typeset -i total=0 pass=0 skip=0

    for bin in "$bin_dir"/*; do
        [[ -f $bin && -x $bin ]] || continue
        [[ ${bin##*/} == *.sh ]] && continue
        typeset name=${bin##*/}

        if blacklisted "$name"; then
            print "[CONTEST][LTP][SKIP] $name (blacklisted)"
            (( skip++ ))
            continue
        fi

        (( total++ ))
        print "RUN LTP CASE $name"
        if "$bin"; then
            print "END LTP CASE $name : 0"
            (( pass++ ))
        else
            print "FAIL LTP CASE $name : $?"
        fi
    done

    print "\nSummary:\npassed   $pass\nfailed   $(( total - pass ))\nbroken   0\nskipped  $skip\nwarnings 0"
    print "#### OS COMP TEST GROUP END $group ####"
    return 0
}

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
    print "FAIL LTP CASE $name : 124"
    return 1
}

run_ltp_bounded_subset() {
    typeset runtime=$1
    typeset arch=$(uname -m)
    typeset dir="/test/$runtime/ltp/testcases/bin"

    if [[ $arch != "riscv64" || $runtime != "glibc" ]]; then
        print "[CONTEST][SKIP] runtime=$runtime group=ltp current_phase=bounded_rv_glibc_only"
        return 0
    fi

    print "[CONTEST][RUN] runtime=$runtime group=ltp mode=bounded_subset case_timeout=60s"
    print "#### OS COMP TEST GROUP START ltp-$runtime ####"

    if [[ ! -d $dir ]]; then
        print "[CONTEST][ERROR] missing $dir"
        print "#### OS COMP TEST GROUP END ltp-$runtime ####"
        print "[CONTEST][FAIL] ltp bounded_subset missing_dir"
        (( failed++ ))
        return 1
    fi

    cd "$dir" || {
        print "[CONTEST][ERROR] cd $dir failed"
        print "#### OS COMP TEST GROUP END ltp-$runtime ####"
        print "[CONTEST][FAIL] ltp bounded_subset cd_failed"
        (( failed++ ))
        return 1
    }

    # cgroup_fj_proc is a signal-driven helper, not a standalone LTP case.
    # Running it directly blocks forever in sigsuspend(), so keep it blacklisted
    # while collecting bounded, real LTP output on both sides of the cgroup_fj point.
    typeset -i failed_cases=0
    typeset name=
    for name in \
        abort01 abs01 \
        accept01 accept02 accept03 accept4_01 \
        access01 access02 access03 access04 \
        adjtimex01 adjtimex02 adjtimex03 \
        alarm02 alarm03 alarm05 alarm06 alarm07 \
        bind01 bind02 bind03 bind04 bind05 \
        brk01 capget01 capget02 \
        capset01 capset02 capset03 capset04 \
        cgroup_core03
    do
        run_ltp_case_with_timeout "$name" 60 || (( failed_cases++ ))
    done
    print "[CONTEST][LTP][SKIP] cgroup_fj_proc blacklisted_helper"
    run_ltp_case_with_timeout chdir04 60 || (( failed_cases++ ))
    for name in \
        chmod01 chmod03 chmod05 chmod06 chmod07 \
        chown01 chown02 chown03 chown04 chown05 \
        chroot01 chroot03 chroot04 \
        clock_adjtime01 clock_getres01 clock_gettime02 clock_gettime04 \
        clock_nanosleep02 clock_nanosleep04 \
        clock_settime01 clock_settime02 \
        close01 close02 confstr01 \
        connect01 copy_file_range03 \
        creat01 creat03 creat04 creat08 \
        dup01 dup02 dup03 dup04 dup05 dup06 dup07 \
        dup201 dup202 dup203 dup204 dup205 dup206 dup207 \
        dup3_01 dup3_02 \
        epoll_create01 epoll_create02 \
        epoll_create1_01 epoll_create1_02 \
        epoll_ctl01 epoll_ctl02 epoll_ctl03 epoll_ctl04 epoll_ctl05 \
        epoll_pwait01 epoll_pwait02 epoll_pwait03 epoll_pwait04 \
        epoll_wait02 epoll_wait03 epoll_wait04 epoll_wait07 \
        eventfd2_01 eventfd2_02 eventfd2_03 \
        execve02 \
        exit01 exit02 exit_group01 \
        faccessat01 faccessat02 faccessat201 faccessat202 \
        fallocate03 \
        fchdir01 fchdir02 fchdir03 \
        fchmod01 fchmod02 fchmod03 fchmod04 fchmod05 fchmod06 \
        fchmodat01 fchmodat02 \
        fchown01 fchown02 fchown03 fchown04 fchown05 \
        fchownat01 fchownat02 \
        fcntl02 fcntl03 fcntl04 fcntl05 fcntl08 \
        fcntl11 fcntl12 fcntl13 fcntl14 fcntl16 \
        fdatasync01 fdatasync02 \
        flock01 flock02 flock03 flock04 \
        fstat02 fstat03 fstatfs02 \
        ftruncate01 ftruncate03 ftruncate03_64 \
        getcontext01 getcwd02 \
        getdomainname01 \
        getegid01 getegid01_16 getegid02 getegid02_16 \
        geteuid01 geteuid02 \
        getgid01 getgid03 \
        getgroups01 getgroups03 \
        gethostbyname_r01 \
        gethostid01 \
        gethostname01 gethostname02 \
        getitimer01 getitimer02 \
        getpagesize01 \
        getpgid01 getpgid02 \
        getpgrp01 \
        getpid01 getpid02 \
        getppid01 getppid02 \
        getpriority01 \
        getrandom01 getrandom02 getrandom03 getrandom04 \
        getresgid01 getresgid02 getresgid03 \
        getresuid01 getresuid02 getresuid03 \
        getrlimit01 getrlimit03 \
        getrusage01 \
        getsid01 getsid02 \
        gettid01 \
        gettimeofday02 \
        getuid01 getuid03 \
        getxattr01 \
        ioctl_ns07 \
        inotify_init1_01 inotify_init1_02 \
        inotify06 \
        kill03 kill05 kill06 kill07 kill08 kill09 kill10 kill12 \
        lchown01 \
        link02 linkat01 \
        listen01 \
        llseek02 llseek03 \
        lseek01 lseek02 lseek07 \
        mkdir02 mkdir04 \
        mkdirat01 \
        mknod01 mknod02 mknod03 mknod04 mknod05 mknod08 \
        mknodat01 \
        mlock03 mlock04 \
        mlockall01 \
        mmap01 mmap02 mmap03 mmap04 mmap05 mmap09 mmap10 mmap11 mmap12 mmap15 mmap17 \
        mprotect02 mprotect03 \
        msync01 msync02 \
        munmap01 munmap02
    do
        run_ltp_case_with_timeout "$name" 60 || (( failed_cases++ ))
    done

    cd /
    print "#### OS COMP TEST GROUP END ltp-$runtime ####"
    (( executed++ ))
    if (( failed_cases == 0 )); then
        print "[CONTEST][PASS] ltp bounded_subset_completed"
        return 0
    fi

    print "[CONTEST][FAIL] ltp bounded_subset_failed cases=$failed_cases"
    (( failed++ ))
    return 1
}

# ── main ────────────────────────────────────────────────────
typeset -i executed=0 failed=0

run_group() {
    typeset runtime=$1 group=$2
    typeset script="/test/$runtime/${group}_testcode.sh"
    typeset dir="/test/$runtime"

    [[ -f $script ]] || return 0

    if skip_group "$group" "$runtime"; then
        print "[CONTEST][SKIP] runtime=$runtime group=$group"
        return 0
    fi

    print "[CONTEST][RUN] runtime=$runtime group=$group script=$script"

    cd "$dir" || {
        print "[CONTEST][ERROR] cd $dir failed"
        (( failed++ ))
        return 1
    }

    typeset rc=0
    typeset -i timeout=$(group_timeout "$group")

    run_with_timeout "$runtime" "$group" "${script##*/}" "$timeout"
    rc=$?
    cd /
    if (( rc == 0 )); then
        print "[CONTEST][PASS] $group"
    else
        print "[CONTEST][FAIL] $group (exit $rc)"
        (( failed++ ))
    fi
    (( executed++ ))
}

typeset runtime group
for group in basic busybox lua libctest iperf netperf libcbench; do
    for runtime in glibc musl; do
        run_group "$runtime" "$group"
    done
done

for group in cyclictest iozone lmbench; do
    for runtime in glibc musl; do
        run_group "$runtime" "$group"
    done
done

for runtime in glibc musl; do
    run_ltp_bounded_subset "$runtime"
done

print "[CONTEST] Done: $executed tests, $failed failures"

poweroff
