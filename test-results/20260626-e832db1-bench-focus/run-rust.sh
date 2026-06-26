#!/bin/sh
set -e
KERNEL=/home/fq/project/oskernel2025-a20/.kernel-build/riscv64-both-dev/kernel.elf
FAT32=/home/fq/project/oskernel2025-a20/.kernel-build/riscv64-both-dev/fat32.img
SDCARD=/home/fq/project/oskernel2025-a20/.eval-state/sdcard-rv.img
LOG=/home/fq/project/oskernel2025-a20/test-results/20260626-e832db1-bench-focus/serial-rv-rust.txt
NETDEV="-netdev user,id=net"

timeout --foreground 7200 \
qemu-system-riscv64 -machine virt -m 1G -nographic -smp 1 -bios default \
    -global virtio-mmio.force-legacy=false \
    -kernel "$KERNEL" \
    -drive "file=$FAT32,if=none,format=raw,id=x0" \
    -device virtio-blk-device,drive=x0,bus=virtio-mmio-bus.0 \
    $NETDEV -device virtio-net-device,netdev=net,bus=virtio-mmio-bus.4 \
    -drive "file=$SDCARD,if=none,format=raw,id=x1" \
    -device virtio-blk-device,drive=x1,bus=virtio-mmio-bus.1 \
    -no-reboot \
2>&1 | tee "$LOG" || true

echo "[runner] QEMU exited, log at $LOG"
