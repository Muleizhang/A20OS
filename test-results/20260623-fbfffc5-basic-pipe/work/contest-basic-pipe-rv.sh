#!/bin/sh
run_pipe() {
    root="$1"
    echo "#### OS COMP TEST GROUP START basic-$root ####"
    cd "/test/$root/basic" || poweroff
    i=1
    while [ "$i" -le 8 ]; do
        echo "Testing pipe iteration $i :"
        ./pipe
        echo "pipe status: $?"
        i=$((i + 1))
    done
    echo "#### OS COMP TEST GROUP END basic-$root ####"
}
run_pipe glibc
run_pipe musl
poweroff
