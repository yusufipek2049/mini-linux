#!/usr/bin/env sh
set -eu

OUT_DIR=${1:-build/arm64}
BASE_URL=${UBUNTU_PORTS_URL:-https://ports.ubuntu.com/ubuntu-ports}
DIST=${UBUNTU_DIST:-jammy-updates}
COMPONENT=${UBUNTU_COMPONENT:-main}
ARCH=${UBUNTU_ARCH:-arm64}
PACKAGES_GZ="$BASE_URL/dists/$DIST/$COMPONENT/binary-$ARCH/Packages.gz"

command -v curl >/dev/null 2>&1 || {
    echo "curl is required" >&2
    exit 1
}

command -v gzip >/dev/null 2>&1 || {
    echo "gzip is required" >&2
    exit 1
}

command -v dpkg-deb >/dev/null 2>&1 || {
    echo "dpkg-deb is required" >&2
    exit 1
}

mkdir -p "$OUT_DIR/cache" "$OUT_DIR/extracted"

PACKAGES="$OUT_DIR/cache/Packages"
if [ ! -s "$PACKAGES" ]; then
    curl -fsSL "$PACKAGES_GZ" | gzip -dc > "$PACKAGES"
fi

package_field() {
    package=$1
    field=$2
    awk -v package="$package" -v field="$field" '
        BEGIN { in_pkg = 0 }
        $0 == "Package: " package { in_pkg = 1 }
        in_pkg && index($0, field ": ") == 1 {
            sub(field ": ", "")
            print
            exit
        }
        in_pkg && $0 == "" { in_pkg = 0 }
    ' "$PACKAGES"
}

download_package() {
    package=$1
    filename=$(package_field "$package" Filename)
    sha256=$(package_field "$package" SHA256)

    [ -n "$filename" ] || {
        echo "package not found in ports index: $package" >&2
        exit 1
    }

    deb="$OUT_DIR/cache/$(basename "$filename")"
    if [ ! -s "$deb" ]; then
        curl -fL "$BASE_URL/$filename" -o "$deb"
    fi

    if [ -n "$sha256" ]; then
        actual=$(sha256sum "$deb" | awk '{ print $1 }')
        [ "$actual" = "$sha256" ] || {
            echo "sha256 mismatch for $deb" >&2
            echo "expected $sha256" >&2
            echo "actual   $actual" >&2
            exit 1
        }
    fi

    echo "$deb"
}

BUSYBOX_PACKAGE=${BUSYBOX_ARM64_PACKAGE:-busybox-static}
KERNEL_PACKAGE=${KERNEL_ARM64_PACKAGE:-linux-image-5.15.0-181-generic}

BUSYBOX_DEB=$(download_package "$BUSYBOX_PACKAGE")
KERNEL_DEB=$(download_package "$KERNEL_PACKAGE")

rm -rf "$OUT_DIR/extracted/busybox" "$OUT_DIR/extracted/kernel"
mkdir -p "$OUT_DIR/extracted/busybox" "$OUT_DIR/extracted/kernel"
dpkg-deb -x "$BUSYBOX_DEB" "$OUT_DIR/extracted/busybox"
dpkg-deb -x "$KERNEL_DEB" "$OUT_DIR/extracted/kernel"

BUSYBOX_BIN=$(find "$OUT_DIR/extracted/busybox" -type f -name busybox | sort | tail -n 1)
KERNEL_IMAGE=$(find "$OUT_DIR/extracted/kernel/boot" -maxdepth 1 -name 'vmlinuz-*' | sort | tail -n 1)

[ -n "$BUSYBOX_BIN" ] || {
    echo "busybox binary not found in $BUSYBOX_DEB" >&2
    exit 1
}

[ -n "$KERNEL_IMAGE" ] || {
    echo "kernel image not found in $KERNEL_DEB" >&2
    exit 1
}

cp "$BUSYBOX_BIN" "$OUT_DIR/busybox"
cp "$KERNEL_IMAGE" "$OUT_DIR/Image"
chmod 0755 "$OUT_DIR/busybox"

{
    echo "busybox_package=$BUSYBOX_PACKAGE"
    echo "busybox_deb=$BUSYBOX_DEB"
    echo "kernel_package=$KERNEL_PACKAGE"
    echo "kernel_deb=$KERNEL_DEB"
    echo "busybox=$OUT_DIR/busybox"
    echo "kernel=$OUT_DIR/Image"
    command -v file >/dev/null 2>&1 && file "$OUT_DIR/busybox" "$OUT_DIR/Image" || true
} > "$OUT_DIR/assets.env"

cat "$OUT_DIR/assets.env"
