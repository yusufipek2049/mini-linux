#!/usr/bin/env sh
set -eu

ROOTFS_DIR=${1:-build/rootfs}
OUT=${2:-build/images/initramfs.cpio.gz}

[ -d "$ROOTFS_DIR" ] || {
    echo "rootfs directory not found: $ROOTFS_DIR" >&2
    exit 1
}

command -v cpio >/dev/null 2>&1 || {
    echo "cpio is required to build initramfs" >&2
    exit 1
}

mkdir -p "$(dirname "$OUT")"
(
    cd "$ROOTFS_DIR"
    find . -print | cpio -o -H newc 2>/dev/null
) | gzip -9 > "$OUT"

echo "initramfs created at $OUT"

