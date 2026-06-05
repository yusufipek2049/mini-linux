#!/usr/bin/env sh
set -eu

fail=0

need() {
    if command -v "$1" >/dev/null 2>&1; then
        printf 'ok      %s\n' "$1"
    else
        printf 'missing %s\n' "$1"
        fail=1
    fi
}

if [ -n "${BUSYBOX:-}" ]; then
    if [ -x "$BUSYBOX" ]; then
        printf 'ok      BUSYBOX=%s\n' "$BUSYBOX"
    else
        printf 'missing BUSYBOX=%s is not executable\n' "$BUSYBOX"
        fail=1
    fi
else
    need busybox
fi

need dd
need find
need gzip
need make
need mkfs.ext4
need mksquashfs
need sha256sum
need tar
need cpio

if command -v qemu-system-x86_64 >/dev/null 2>&1 || command -v qemu-system-aarch64 >/dev/null 2>&1; then
    printf 'ok      qemu optional runtime found\n'
else
    printf 'warn    qemu not found; image build still works\n'
fi

if [ "$fail" -ne 0 ]; then
    echo "dependency check failed" >&2
    exit 1
fi

echo "dependency check passed"

