#!/usr/bin/env sh
set -eu

INITRD=${1:-build/images/initramfs.cpio.gz}
ARCH=${ARCH:-x86_64}
KERNEL=${KERNEL:-}

[ -r "$INITRD" ] || {
    echo "initramfs not found: $INITRD" >&2
    exit 1
}

if [ -z "$KERNEL" ]; then
    echo "KERNEL=/path/to/kernel is required for QEMU boot" >&2
    echo "example: KERNEL=/boot/vmlinuz-\$(uname -r) make run-qemu" >&2
    exit 2
fi

[ -r "$KERNEL" ] || {
    echo "kernel not readable: $KERNEL" >&2
    exit 1
}

case "$ARCH" in
    aarch64|arm64)
        QEMU=qemu-system-aarch64
        command -v "$QEMU" >/dev/null 2>&1 || {
            echo "$QEMU not found" >&2
            exit 1
        }
        exec "$QEMU" \
            -M virt \
            -cpu cortex-a53 \
            -m 512M \
            -kernel "$KERNEL" \
            -initrd "$INITRD" \
            -append "console=ttyAMA0 rdinit=/sbin/init" \
            -nographic \
            -no-reboot
        ;;
    x86_64|amd64)
        QEMU=qemu-system-x86_64
        command -v "$QEMU" >/dev/null 2>&1 || {
            echo "$QEMU not found" >&2
            exit 1
        }
        exec "$QEMU" \
            -m 512M \
            -kernel "$KERNEL" \
            -initrd "$INITRD" \
            -append "console=ttyS0 rdinit=/sbin/init" \
            -nographic \
            -no-reboot
        ;;
    *)
        echo "unsupported ARCH=$ARCH" >&2
        exit 2
        ;;
esac

