#!/bin/sh
run_brk() {
    root="$1"
    echo "#### OS COMP TEST GROUP START basic-$root-brk ####"
    cd "/test/$root/basic" || poweroff
    i=1
    while [ "$i" -le 8 ]; do
        echo "Testing brk iteration $i :"
        ./brk
        echo "brk status: $?"
        i=$((i + 1))
    done
    echo "#### OS COMP TEST GROUP END basic-$root-brk ####"
}
run_brk glibc
run_brk musl
poweroff
