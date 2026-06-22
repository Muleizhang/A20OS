#!/bin/sh
set -eu

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT="$ROOT/test-results/20260623-fbfffc5-basic-pipe"
WORK="$OUT/work"
mkdir -p "$WORK"

write_guest_script() {
    dst="$1"
    cat > "$dst" <<'EOF'
#!/bin/sh
run_smoke() {
    root="$1"
    echo "#### OS COMP TEST GROUP START busybox-$root ####"
    cd "/test/$root" || poweroff
    ./busybox echo "testcase busybox echo success"
    ./busybox printf "testcase busybox printf success\n"
    ./busybox true
    echo "busybox true status: $?"
    echo "#### OS COMP TEST GROUP END busybox-$root ####"
}
run_smoke glibc
run_smoke musl
poweroff
EOF
}

run_rv() {
    img="$WORK/busybox-smoke-rv.img"
    cp "$ROOT/disk.img" "$img"
    write_guest_script "$WORK/contest-busybox-smoke-rv.sh"
    printf 'auto\n' | mcopy -o -i "$img" - ::/etc/contest-mode
    mcopy -o -i "$img" "$WORK/contest-busybox-smoke-rv.sh" ::/contest.sh
    set +e
    timeout --foreground 120s qemu-system-riscv64 \
        -machine virt -m 1G -nographic -smp 1 -bios default \
        -global virtio-mmio.force-legacy=false \
        -kernel "$ROOT/kernel-rv" \
        -drive "file=$img,if=none,format=raw,id=x0" \
        -device virtio-blk-device,drive=x0,bus=virtio-mmio-bus.0 \
        -netdev user,id=net,hostfwd=tcp::12064-:80 \
        -device virtio-net-device,netdev=net,bus=virtio-mmio-bus.4 \
        -drive "file=$ROOT/sdcard-rv.img,if=none,format=raw,id=x1" \
        -device virtio-blk-device,drive=x1,bus=virtio-mmio-bus.1 \
        -no-reboot > "$OUT/after-rv-busybox-smoke.txt" 2>&1
    rc=$?
    set -e
    echo "$rc" > "$OUT/after-rv-busybox-smoke.status"
}

run_la() {
    img="$WORK/busybox-smoke-la.img"
    cp "$ROOT/disk-la.img" "$img"
    write_guest_script "$WORK/contest-busybox-smoke-la.sh"
    printf 'auto\n' | mcopy -o -i "$img" - ::/etc/contest-mode
    mcopy -o -i "$img" "$WORK/contest-busybox-smoke-la.sh" ::/contest.sh
    set +e
    timeout --foreground 120s qemu-system-loongarch64 \
        -machine virt -m 1G -nographic -smp 1 \
        -kernel "$ROOT/kernel-la" \
        -drive "file=$img,if=none,format=raw,id=x0" \
        -device virtio-blk-pci,drive=x0 \
        -netdev user,id=net,hostfwd=tcp::12065-:80 \
        -device virtio-net-pci,netdev=net \
        -drive "file=$ROOT/sdcard-la.img,if=none,format=raw,id=x1" \
        -device virtio-blk-pci,drive=x1 \
        -no-reboot > "$OUT/after-la-busybox-smoke.txt" 2>&1
    rc=$?
    set -e
    echo "$rc" > "$OUT/after-la-busybox-smoke.status"
}

run_rv
run_la
