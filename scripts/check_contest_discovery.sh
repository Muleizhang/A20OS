#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmpdir=$(mktemp -d /tmp/a20-contest-discovery.XXXXXX)
trap 'rm -rf "$tmpdir"' EXIT HUP INT TERM

test_img="$tmpdir/test.ext4"
disk_overlay="$tmpdir/disk.qcow2"
log="$tmpdir/serial.log"

truncate -s 32M "$test_img"
mkfs.ext4 -q -F "$test_img"
debugfs -w -R "write $root/user/contest_init/run_ltp_resume.sh /smoke_testcode.sh" "$test_img" >/dev/null 2>&1
qemu-img create -q -f qcow2 -F raw -b "$root/disk.img" "$disk_overlay"

timeout --foreground "${CONTEST_DISCOVERY_TIMEOUT:-30s}" \
    qemu-system-riscv64 \
    -machine virt -kernel "$root/kernel-rv" -m 1G -nographic -smp 1 -bios default \
    -drive "file=$test_img,if=none,format=raw,id=x0" \
    -device virtio-blk-device,drive=x0,bus=virtio-mmio-bus.0 \
    -no-reboot -device virtio-net-device,netdev=net -netdev user,id=net \
    -rtc base=utc \
    -drive "file=$disk_overlay,if=none,format=qcow2,id=x1" \
    -device virtio-blk-device,drive=x1,bus=virtio-mmio-bus.1 \
    >"$log" 2>&1

grep -Fq '[CONTEST][RUN] runtime=root group=smoke' "$log"
grep -Fq '[LTP-RESUME] no ltp/testcases/bin found' "$log"
grep -Fq '[CONTEST] Done: 1 tests' "$log"
grep -Fq 'System is going down for power-off NOW.' "$log"

echo "check-contest-discovery: PASS"
