#!/bin/sh
set -eu

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT="$ROOT/test-results/20260623-fbfffc5-basic-pipe"
WORK="$OUT/work"
MODE="${1:-after}"
mkdir -p "$WORK"

write_guest_script() {
    dst="$1"
    cat > "$dst" <<'EOF'
#!/bin/sh
run_pipe() {
    root="$1"
    echo "#### OS COMP TEST GROUP START basic-$root ####"
    cd "/test/$root/basic" || poweroff
    i=1
    while [ "$i" -le 8 ]; do
        echo "Testing pipe iteration $i :"
        ./pipe
        echo "pipe status: $?"
        i=$((i + 1))
    done
    echo "#### OS COMP TEST GROUP END basic-$root ####"
}
run_pipe glibc
run_pipe musl
poweroff
EOF
}

run_rv() {
    img="$WORK/$MODE-rv.img"
    cp "$ROOT/disk.img" "$img"
    write_guest_script "$WORK/contest-basic-pipe-rv.sh"
    printf 'auto\n' | mcopy -o -i "$img" - ::/etc/contest-mode
    mcopy -o -i "$img" "$WORK/contest-basic-pipe-rv.sh" ::/contest.sh
    set +e
    timeout --foreground 240s qemu-system-riscv64 \
        -machine virt -m 1G -nographic -smp 1 -bios default \
        -global virtio-mmio.force-legacy=false \
        -kernel "$ROOT/kernel-rv" \
        -drive "file=$img,if=none,format=raw,id=x0" \
        -device virtio-blk-device,drive=x0,bus=virtio-mmio-bus.0 \
        -netdev user,id=net,hostfwd=tcp::12060-:80 \
        -device virtio-net-device,netdev=net,bus=virtio-mmio-bus.4 \
        -drive "file=$ROOT/sdcard-rv.img,if=none,format=raw,id=x1" \
        -device virtio-blk-device,drive=x1,bus=virtio-mmio-bus.1 \
        -no-reboot > "$OUT/$MODE-rv-basic-pipe.txt" 2>&1
    rc=$?
    set -e
    echo "$rc" > "$OUT/$MODE-rv-basic-pipe.status"
}

run_la() {
    img="$WORK/$MODE-la.img"
    cp "$ROOT/disk-la.img" "$img"
    write_guest_script "$WORK/contest-basic-pipe-la.sh"
    printf 'auto\n' | mcopy -o -i "$img" - ::/etc/contest-mode
    mcopy -o -i "$img" "$WORK/contest-basic-pipe-la.sh" ::/contest.sh
    set +e
    timeout --foreground 240s qemu-system-loongarch64 \
        -machine virt -m 1G -nographic -smp 1 \
        -kernel "$ROOT/kernel-la" \
        -drive "file=$img,if=none,format=raw,id=x0" \
        -device virtio-blk-pci,drive=x0 \
        -netdev user,id=net,hostfwd=tcp::12061-:80 \
        -device virtio-net-pci,netdev=net \
        -drive "file=$ROOT/sdcard-la.img,if=none,format=raw,id=x1" \
        -device virtio-blk-pci,drive=x1 \
        -no-reboot > "$OUT/$MODE-la-basic-pipe.txt" 2>&1
    rc=$?
    set -e
    echo "$rc" > "$OUT/$MODE-la-basic-pipe.status"
}

run_rv
run_la
