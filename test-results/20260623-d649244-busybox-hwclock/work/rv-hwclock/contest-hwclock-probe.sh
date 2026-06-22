#!/bin/mksh
mkdir -p /tmp /root
export HOME=/root
export TMPDIR=/tmp
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}/bin/lib:/lib:/test/glibc/lib:/test/musl/lib"

print "#### OS COMP TEST GROUP START busybox-hwclock-probe-rv ####"
for runtime in glibc musl; do
  print "[PROBE] runtime=$runtime"
  cd "/test/$runtime" || {
    print "[PROBE][FAIL] cd /test/$runtime"
    continue
  }
  ./busybox ls -l /dev
  ./busybox ls -l /dev/misc
  for dev in default /dev/rtc /dev/rtc0 /dev/misc/rtc; do
    if [[ $dev == default ]]; then
      print "[PROBE] $runtime hwclock default"
      ./busybox hwclock
      print "[PROBE] $runtime default rc=$?"
    else
      print "[PROBE] $runtime hwclock -f $dev"
      ./busybox hwclock -f "$dev"
      print "[PROBE] $runtime $dev rc=$?"
    fi
  done
done
print "#### OS COMP TEST GROUP END busybox-hwclock-probe-rv ####"
poweroff
