#!/bin/sh
echo "#### OS COMP TEST GROUP START basic-glibc ####"
cd /test/glibc || poweroff
./basic_testcode.sh
echo "#### OS COMP TEST GROUP END basic-glibc ####"
echo "#### OS COMP TEST GROUP START basic-musl ####"
cd /test/musl || poweroff
./basic_testcode.sh
echo "#### OS COMP TEST GROUP END basic-musl ####"
poweroff
