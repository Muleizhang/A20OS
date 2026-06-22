#!/bin/sh
set -eu

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT="$ROOT/test-results/20260623-0531c5d-basic-mount"
WORK="$OUT/work"
mkdir -p "$WORK"

run_rv() {
    img="$WORK/repro-rv.img"
    cp "$ROOT/disk.img" "$img"
    cat > "$WORK/contest-basic-mount.sh" <<'EOF'
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
EOF
    printf 'auto\n' | mcopy -o -i "$img" - ::/etc/contest-mode
    mcopy -o -i "$img" "$WORK/contest-basic-mount.sh" ::/contest.sh
    set +e
    timeout --foreground 180s qemu-system-riscv64 \
        -machine virt -m 1G -nographic -smp 1 -bios default \
        -global virtio-mmio.force-legacy=false \
        -kernel "$ROOT/kernel-rv" \
        -drive "file=$img,if=none,format=raw,id=x0" \
        -device virtio-blk-device,drive=x0,bus=virtio-mmio-bus.0 \
        -netdev user,id=net,hostfwd=tcp::12055-:80 \
        -device virtio-net-device,netdev=net,bus=virtio-mmio-bus.4 \
        -drive "file=$ROOT/sdcard-rv.img,if=none,format=raw,id=x1" \
        -device virtio-blk-device,drive=x1,bus=virtio-mmio-bus.1 \
        -no-reboot > "$OUT/repro-rv-basic-mount.txt" 2>&1
    rc=$?
    set -e
    echo "$rc" > "$OUT/repro-rv-basic-mount.status"
    return 0
}

run_rv
