#!/usr/bin/env sh
set -eu

ROOTFS_DIR=${1:-build/rootfs}
IMAGE_DIR=${2:-build/images}
DATA_TEMPLATE=${DATA_TEMPLATE:-data-template}
DATA_SIZE_MB=${DATA_SIZE_MB:-64}

[ -d "$ROOTFS_DIR" ] || {
    echo "rootfs directory not found: $ROOTFS_DIR" >&2
    exit 1
}

mkdir -p "$IMAGE_DIR"

mksquashfs "$ROOTFS_DIR" "$IMAGE_DIR/rootfs_a.squashfs" -noappend -comp xz -quiet >/dev/null
cp "$IMAGE_DIR/rootfs_a.squashfs" "$IMAGE_DIR/rootfs_b.squashfs"

DATA_WORK=build/data
rm -rf "$DATA_WORK"
mkdir -p "$DATA_WORK"
if [ -d "$DATA_TEMPLATE" ]; then
    cp -a "$DATA_TEMPLATE"/. "$DATA_WORK"/
fi

DATA_IMG="$IMAGE_DIR/data.ext4"
rm -f "$DATA_IMG"
dd if=/dev/zero of="$DATA_IMG" bs=1M count="$DATA_SIZE_MB" status=none
mkfs.ext4 -q -F -L data -d "$DATA_WORK" "$DATA_IMG"

BOOT_DIR="$IMAGE_DIR/boot"
rm -rf "$BOOT_DIR"
mkdir -p "$BOOT_DIR/extlinux"
cp configs/uEnv.txt "$BOOT_DIR/uEnv.txt"
cp configs/extlinux.conf "$BOOT_DIR/extlinux/extlinux.conf"
{
    echo "Add board-specific Image and board.dtb here."
    echo "This project builds RootFS/data images; kernel and U-Boot come from BSP."
} > "$BOOT_DIR/README.txt"
tar -C "$BOOT_DIR" -cf "$IMAGE_DIR/boot.tar" .

cp configs/partition.layout "$IMAGE_DIR/partition.layout"

(
    cd "$IMAGE_DIR"
    sha256sum rootfs_a.squashfs rootfs_b.squashfs data.ext4 boot.tar > checksums.sha256
)

echo "images created in $IMAGE_DIR"
echo "  rootfs_a.squashfs"
echo "  rootfs_b.squashfs"
echo "  data.ext4"
echo "  boot.tar"

