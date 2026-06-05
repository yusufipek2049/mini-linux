#!/usr/bin/env sh
set -eu

ROOTFS_DIR=${1:-build/rootfs}
OVERLAY_DIR=${OVERLAY_DIR:-rootfs-overlay}
APPLETS_FILE=${APPLETS_FILE:-configs/busybox-applets.txt}

if [ -n "${BUSYBOX:-}" ]; then
    BUSYBOX_BIN=$BUSYBOX
else
    BUSYBOX_BIN=$(command -v busybox || true)
fi

if [ -z "$BUSYBOX_BIN" ] || [ ! -x "$BUSYBOX_BIN" ]; then
    echo "busybox not found. Set BUSYBOX=/path/to/static/busybox" >&2
    exit 1
fi

rm -rf "$ROOTFS_DIR"
mkdir -p "$ROOTFS_DIR"
cp -a "$OVERLAY_DIR"/. "$ROOTFS_DIR"/

for dir in \
    bin sbin etc etc/init.d etc/network etc/dropbear lib usr/bin usr/sbin \
    usr/share/udhcpc dev proc sys run tmp var data data/config data/log \
    data/app data/etc-overlay boot root
do
    mkdir -p "$ROOTFS_DIR/$dir"
done

chmod 1777 "$ROOTFS_DIR/tmp"
cp "$BUSYBOX_BIN" "$ROOTFS_DIR/bin/busybox"
chmod 0755 "$ROOTFS_DIR/bin/busybox"

TMP_APPLETS="build/busybox-applets.detected"
mkdir -p build
if "$BUSYBOX_BIN" --list > "$TMP_APPLETS" 2>/dev/null; then
    APPLETS=$TMP_APPLETS
else
    APPLETS=$APPLETS_FILE
fi

while IFS= read -r applet; do
    [ -n "$applet" ] || continue
    [ "$applet" = "busybox" ] && continue

    case "$applet" in
        init|reboot|poweroff|halt|getty|mdev|syslogd|klogd|udhcpc|ifconfig|route|watchdog|modprobe|insmod|rmmod|lsmod)
            dest="$ROOTFS_DIR/sbin/$applet"
            ;;
        *)
            dest="$ROOTFS_DIR/bin/$applet"
            ;;
    esac

    ln -sf /bin/busybox "$dest"
done < "$APPLETS"

ln -sfn /run "$ROOTFS_DIR/var/run"
ln -sfn /run/log "$ROOTFS_DIR/var/log"
ln -sfn /proc/mounts "$ROOTFS_DIR/etc/mtab"
ln -sfn /run/resolv.conf "$ROOTFS_DIR/etc/resolv.conf"
ln -sfn /data/dropbear/ssh "$ROOTFS_DIR/root/.ssh"

find "$ROOTFS_DIR/etc/init.d" -type f -exec chmod 0755 {} \;
find "$ROOTFS_DIR/usr/bin" "$ROOTFS_DIR/usr/sbin" "$ROOTFS_DIR/usr/share/udhcpc" -type f -exec chmod 0755 {} \;

{
    echo "name=mini-linux"
    echo "target_arch=${TARGET_ARCH:-aarch64}"
    echo "rootfs=read-only"
    echo "datafs=writable"
    echo "busybox=$BUSYBOX_BIN"
    command -v file >/dev/null 2>&1 && file "$BUSYBOX_BIN" || true
} > "$ROOTFS_DIR/etc/build-info"

echo "rootfs created at $ROOTFS_DIR"
