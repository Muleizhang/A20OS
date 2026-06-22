#!/bin/mksh
mkdir -p /tmp /root
export HOME=/root
export TMPDIR=/tmp
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}/bin/lib:/lib:/test/glibc/lib:/test/musl/lib"
[[ -x /test/glibc/busybox ]] && cp /test/glibc/busybox /busybox 2>/dev/null
[[ -x /test/glibc/busybox ]] && cp /test/glibc/busybox /bin/busybox 2>/dev/null

print "#### OS COMP TEST GROUP START busybox-glibc-rv-kill10-primed ####"
cd /test/glibc || {
  print "CD_FAIL"
  print "#### OS COMP TEST GROUP END busybox-glibc-rv-kill10-primed ####"
  poweroff
}

typeset -a pids
typeset -i i=0
while (( i < 12 )); do
  ./busybox sleep 300 &
  pids+=("$!")
  print "PRIME_PID_$i=$!"
  (( i++ ))
done

print "[CASE] busybox kill 10"
./busybox kill 10
print "KILL10_RC=$?"

print "[CASE] busybox kill -0 10"
./busybox kill -0 10
print "KILL0_10_RC=$?"

for p in "${pids[@]}"; do
  ./busybox kill "$p" 2>/dev/null
done
sleep 1
print "#### OS COMP TEST GROUP END busybox-glibc-rv-kill10-primed ####"
poweroff
