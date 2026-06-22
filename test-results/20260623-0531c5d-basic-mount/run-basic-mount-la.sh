#!/bin/sh
set -eu

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT="$ROOT/test-results/20260623-0531c5d-basic-mount"
WORK="$OUT/work"
mkdir -p "$WORK"

img="$WORK/after-la.img"
cp "$ROOT/disk-la.img" "$img"
cat > "$WORK/contest-basic-mount-la.sh" <<'EOF'
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
mcopy -o -i "$img" "$WORK/contest-basic-mount-la.sh" ::/contest.sh

set +e
timeout --foreground 180s qemu-system-loongarch64 \
    -machine virt -m 1G -nographic -smp 1 \
    -kernel "$ROOT/kernel-la" \
    -drive "file=$img,if=none,format=raw,id=x0" \
    -device virtio-blk-pci,drive=x0 \
    -netdev user,id=net,hostfwd=tcp::12057-:80 \
    -device virtio-net-pci,netdev=net \
    -drive "file=$ROOT/sdcard-la.img,if=none,format=raw,id=x1" \
    -device virtio-blk-pci,drive=x1 \
    -no-reboot > "$OUT/after-la-basic-mount.txt" 2>&1
rc=$?
set -e
echo "$rc" > "$OUT/after-la-basic-mount.status"
