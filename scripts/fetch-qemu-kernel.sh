#!/usr/bin/env sh
set -eu

OUT_DIR=${1:-build/kernel}
PACKAGE=${KERNEL_PACKAGE:-}

command -v apt-cache >/dev/null 2>&1 || {
    echo "apt-cache is required to discover a local QEMU kernel package" >&2
    exit 1
}

command -v apt-get >/dev/null 2>&1 || {
    echo "apt-get is required to download a local QEMU kernel package" >&2
    exit 1
}

command -v dpkg-deb >/dev/null 2>&1 || {
    echo "dpkg-deb is required to extract a local QEMU kernel package" >&2
    exit 1
}

if [ -z "$PACKAGE" ]; then
    PACKAGE=$(
        apt-cache depends linux-image-virtual 2>/dev/null |
            awk '/Depends:/ && $2 ~ /^linux-image-[0-9].*-generic$/ { print $2; exit }'
    )
fi

[ -n "$PACKAGE" ] || {
    echo "could not discover linux-image package; set KERNEL_PACKAGE=linux-image-..." >&2
    exit 1
}

mkdir -p "$OUT_DIR"

if ! find "$OUT_DIR" -maxdepth 1 -name "$PACKAGE"'_*.deb' | grep -q .; then
    (
        cd "$OUT_DIR"
        apt-get download "$PACKAGE"
    )
fi

DEB=$(find "$OUT_DIR" -maxdepth 1 -name "$PACKAGE"'_*.deb' | sort | tail -n 1)

rm -rf "$OUT_DIR/extracted"
mkdir -p "$OUT_DIR/extracted"
dpkg-deb -x "$DEB" "$OUT_DIR/extracted"

KERNEL=$(find "$OUT_DIR/extracted/boot" -maxdepth 1 -name 'vmlinuz-*' | sort | tail -n 1)

[ -n "$KERNEL" ] || {
    echo "no vmlinuz found inside $DEB" >&2
    exit 1
}

ln -sfn "$(basename "$KERNEL")" "$OUT_DIR/extracted/boot/vmlinuz"
ln -sfn "extracted/boot/vmlinuz" "$OUT_DIR/vmlinuz"

echo "kernel package: $PACKAGE"
echo "kernel image: $OUT_DIR/vmlinuz"
