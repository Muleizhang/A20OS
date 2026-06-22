#!/bin/mksh
mkdir -p /tmp /root
export HOME=/root
export TMPDIR=/tmp
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}/bin/lib:/lib:/test/glibc/lib:/test/musl/lib"
[[ -x /test/glibc/busybox ]] && cp /test/glibc/busybox /busybox 2>/dev/null
[[ -x /test/glibc/busybox ]] && cp /test/glibc/busybox /bin/busybox 2>/dev/null

print "#### OS COMP TEST GROUP START busybox-glibc-rv-kill10 ####"
cd /test/glibc || {
  print "CD_FAIL"
  print "#### OS COMP TEST GROUP END busybox-glibc-rv-kill10 ####"
  poweroff
}

print "[CASE] ps-before"
./busybox ps

print "[CASE] busybox kill 10"
./busybox kill 10
print "KILL10_RC=$?"

print "[CASE] busybox kill -0 10"
./busybox kill -0 10
print "KILL0_10_RC=$?"

print "[CASE] busybox kill child"
./busybox sh -c 'sleep 5' &
pid=$!
print "BG_PID=$pid"
./busybox kill $pid
print "KILL_BG_RC=$?"

sleep 1
print "[CASE] ps-after"
./busybox ps
print "#### OS COMP TEST GROUP END busybox-glibc-rv-kill10 ####"
poweroff
