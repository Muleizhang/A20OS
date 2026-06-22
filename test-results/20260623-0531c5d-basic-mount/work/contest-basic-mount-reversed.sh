#!/bin/sh
echo "#### OS COMP TEST GROUP START basic-glibc ####"
cd /test/glibc/basic || poweroff
echo "Testing mount :"
./mount
echo "mount status: $?"
echo "Testing umount :"
./umount
echo "umount status: $?"
echo "#### OS COMP TEST GROUP END basic-glibc ####"
echo "#### OS COMP TEST GROUP START basic-musl ####"
cd /test/musl/basic || poweroff
echo "Testing mount :"
./mount
echo "mount status: $?"
echo "Testing umount :"
./umount
echo "umount status: $?"
echo "#### OS COMP TEST GROUP END basic-musl ####"
poweroff
