#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=$(cd "$(dirname "$0")" && pwd)

KERNEL="$ROOT/kernel-rv"
BASE_DISK="$ROOT/disk.img"
SDCARD="$ROOT/sdcard-rv.img"
CONTEST="$ROOT/user/contest_init/contest.sh"
WORK_DISK="$OUT/work/disk-rv-glibc-ltp-bounded-after-futex.img"
SERIAL="$OUT/after-serial-rv-glibc-ltp-bounded-futex-timeout.txt"
QEMU_SERIAL="$OUT/after-qemu-serial-rv-glibc-ltp-bounded-futex-timeout.txt"
STATUS="$OUT/qemu-rv-glibc-ltp-bounded-after-status.txt"
GUEST="$OUT/work/contest-rv-glibc-ltp-bounded-after-futex.sh"

for f in "$KERNEL" "$BASE_DISK" "$SDCARD" "$CONTEST"; do
  [[ -f "$f" ]] || { echo "[HOST][ERROR] missing $f" >&2; exit 1; }
done

mkdir -p "$OUT/work"
cp -f "$BASE_DISK" "$WORK_DISK"

{
  cat <<'GUEST_HEAD'
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

print "[LTP-BOUNDED-AFTER] syntax_check=/bin/contest-under-test.sh"
if /bin/sh -n /bin/contest-under-test.sh; then
    print "[LTP-BOUNDED-AFTER][PASS] syntax"
else
    print "[LTP-BOUNDED-AFTER][FAIL] syntax"
    poweroff
fi

typeset -i executed=0 failed=0
GUEST_HEAD

  awk '
    /^run_ltp_case_with_timeout\(\) \{/ || /^ltp_case_timeout\(\) \{/ || /^run_ltp_bounded_case\(\) \{/ || /^run_ltp_bounded_subset\(\) \{/ { emit=1 }
    emit { print }
    emit && /^}$/ { emit=0 }
  ' "$CONTEST"

  cat <<'GUEST_TAIL'

print "[LTP-BOUNDED-AFTER] running current bounded subset"
run_ltp_bounded_subset glibc
typeset -i glibc_rc=$?
run_ltp_bounded_subset musl
typeset -i musl_rc=$?
print "[LTP-BOUNDED-AFTER][SUMMARY] executed=$executed failed=$failed glibc_rc=$glibc_rc musl_rc=$musl_rc"
if (( executed == 1 && failed == 0 && glibc_rc == 0 && musl_rc == 0 )); then
    print "[CONTEST][PASS] ltp-bounded-after-futex-timeout"
else
    print "[CONTEST][FAIL] ltp-bounded-after-futex-timeout"
fi

poweroff
GUEST_TAIL
} >"$GUEST"
chmod 755 "$GUEST"

mcopy -o -i "$WORK_DISK" "$CONTEST" ::/contest-under-test.sh
mcopy -o -i "$WORK_DISK" "$GUEST" ::/contest.sh
printf 'auto\n' | mcopy -o -i "$WORK_DISK" - ::/etc/contest-mode

printf '[HOST] START rv glibc ltp-bounded-after futex-timeout %s\n' "$(date -Is)" | tee "$SERIAL"
: >"$QEMU_SERIAL"
set +e
timeout 2400s qemu-system-riscv64 -machine virt -m 1G -display none -serial file:"$QEMU_SERIAL" -monitor none -smp 1 -bios default \
  -global virtio-mmio.force-legacy=false \
  -kernel "$KERNEL" \
  -drive file="$WORK_DISK",if=none,format=raw,id=x0 \
  -device virtio-blk-device,drive=x0,bus=virtio-mmio-bus.0 \
  -drive file="$SDCARD",if=none,format=raw,id=x1,snapshot=on \
  -device virtio-blk-device,drive=x1,bus=virtio-mmio-bus.1 \
  -no-reboot >>"$SERIAL" 2>&1
status=$?
set -e
cat "$QEMU_SERIAL" >>"$SERIAL"
printf '[HOST] END rv glibc ltp-bounded-after futex-timeout status=%s %s\n' "$status" "$(date -Is)" | tee -a "$SERIAL"
printf '%s\n' "$status" > "$STATUS"
exit "$status"
