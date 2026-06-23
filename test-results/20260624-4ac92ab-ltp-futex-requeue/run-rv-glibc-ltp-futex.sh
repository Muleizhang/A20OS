#!/usr/bin/env bash
set -euo pipefail

MODE=${1:-}
case "$MODE" in
  base|mul4) ;;
  *) echo "usage: $0 base|mul4" >&2; exit 2 ;;
esac
LABEL=${LABEL:-$MODE}

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=$(cd "$(dirname "$0")" && pwd)

KERNEL="$ROOT/kernel-rv"
BASE_DISK="$ROOT/disk.img"
SDCARD="$ROOT/sdcard-rv.img"
CONTEST="$ROOT/user/contest_init/contest.sh"
WORK_DISK="$OUT/work/disk-rv-glibc-ltp-futex-$LABEL.img"
SERIAL="$OUT/probe-serial-rv-glibc-ltp-futex-$LABEL.txt"
QEMU_SERIAL="$OUT/probe-qemu-serial-rv-glibc-ltp-futex-$LABEL.txt"
STATUS="$OUT/qemu-rv-glibc-ltp-futex-$LABEL-status.txt"
GUEST="$OUT/work/contest-rv-glibc-ltp-futex-$LABEL.sh"
CANDIDATE_FILE=${CANDIDATE_FILE:-"$OUT/candidates-futex.txt"}

for f in "$KERNEL" "$BASE_DISK" "$SDCARD" "$CONTEST" "$CANDIDATE_FILE"; do
  [[ -f "$f" ]] || { echo "[HOST][ERROR] missing $f" >&2; exit 1; }
done

mapfile -t CANDIDATES <"$CANDIDATE_FILE"
(( ${#CANDIDATES[@]} > 0 )) || { echo "[HOST][ERROR] empty candidate list" >&2; exit 1; }

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

print "[LTP-FUTEX] syntax_check=/bin/contest-under-test.sh"
if /bin/sh -n /bin/contest-under-test.sh; then
    print "[LTP-FUTEX][PASS] syntax"
else
    print "[LTP-FUTEX][FAIL] syntax"
    poweroff
fi
GUEST_HEAD

  awk '
    /^run_ltp_case_with_timeout\(\) \{/ || /^ltp_case_timeout\(\) \{/ || /^run_ltp_bounded_case\(\) \{/ { emit=1 }
    emit { print }
    emit && /^}$/ { emit=0 }
  ' "$CONTEST"

  cat <<GUEST_MODE

typeset mode="$MODE"
if [[ "\$mode" == "mul4" ]]; then
    export LTP_TIMEOUT_MUL=4
    print "[LTP-FUTEX][mul4] LTP_TIMEOUT_MUL=\$LTP_TIMEOUT_MUL"
fi

print "[LTP-FUTEX][\$mode] running futex residual"
print "#### OS COMP TEST GROUP START ltp-glibc ####"
cd /test/glibc/ltp/testcases/bin || {
    print "[LTP-FUTEX][\$mode][FAIL] cd"
    print "#### OS COMP TEST GROUP END ltp-glibc ####"
    poweroff
}
typeset -i pass=0 fail=0
GUEST_MODE

  for case_name in "${CANDIDATES[@]}"; do
    printf 'if [[ -x ./%q ]]; then if run_ltp_bounded_case %q; then (( pass++ )); else (( fail++ )); fi; else print "FAIL LTP CASE %q : missing"; (( fail++ )); fi\n' "$case_name" "$case_name" "$case_name"
  done

  cat <<'GUEST_TAIL'
print "[LTP-FUTEX][$mode][SUMMARY] pass=$pass fail=$fail"
print "#### OS COMP TEST GROUP END ltp-glibc ####"
if (( fail == 0 )); then
    print "[CONTEST][PASS] ltp-futex-$mode"
else
    print "[CONTEST][FAIL] ltp-futex-$mode"
fi

poweroff
GUEST_TAIL
} >"$GUEST"
chmod 755 "$GUEST"

mcopy -o -i "$WORK_DISK" "$CONTEST" ::/contest-under-test.sh
mcopy -o -i "$WORK_DISK" "$GUEST" ::/contest.sh
printf 'auto\n' | mcopy -o -i "$WORK_DISK" - ::/etc/contest-mode

if [[ ${PREP_ONLY:-0} == 1 ]]; then
  echo "[HOST] prepared $WORK_DISK and $GUEST"
  exit 0
fi

printf '[HOST] START rv glibc ltp-futex %s %s\n' "$MODE" "$(date -Is)" | tee "$SERIAL"
: >"$QEMU_SERIAL"
set +e
timeout 1200s qemu-system-riscv64 -machine virt -m 1G -display none -serial file:"$QEMU_SERIAL" -monitor none -smp 1 -bios default \
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
printf '[HOST] END rv glibc ltp-futex %s status=%s %s\n' "$MODE" "$status" "$(date -Is)" | tee -a "$SERIAL"
printf '%s\n' "$status" > "$STATUS"
exit "$status"
