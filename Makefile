SHELL := /bin/sh

BUILD_DIR ?= build
ROOTFS_DIR ?= $(BUILD_DIR)/rootfs
IMAGE_DIR ?= $(BUILD_DIR)/images

.PHONY: all check rootfs images initramfs qemu-kernel arm64-assets run-qemu run-qemu-local run-qemu-arm64 update-init update-status update-install update-good update-bad tree clean

all: images initramfs

check:
	./scripts/check-deps.sh

rootfs:
	./scripts/build-rootfs.sh "$(ROOTFS_DIR)"

images: rootfs
	./scripts/build-images.sh "$(ROOTFS_DIR)" "$(IMAGE_DIR)"

initramfs: rootfs
	./scripts/build-initramfs.sh "$(ROOTFS_DIR)" "$(IMAGE_DIR)/initramfs.cpio.gz"

qemu-kernel:
	./scripts/fetch-qemu-kernel.sh "$(BUILD_DIR)/kernel"

arm64-assets:
	./scripts/fetch-arm64-assets.sh "$(BUILD_DIR)/arm64"

run-qemu: initramfs
	./scripts/run-qemu.sh "$(IMAGE_DIR)/initramfs.cpio.gz"

run-qemu-local: qemu-kernel initramfs
	KERNEL="$(CURDIR)/$(BUILD_DIR)/kernel/vmlinuz" ./scripts/run-qemu.sh "$(IMAGE_DIR)/initramfs.cpio.gz"

run-qemu-arm64: arm64-assets
	ARCH=aarch64 BUSYBOX="$(CURDIR)/$(BUILD_DIR)/arm64/busybox" ./scripts/build-rootfs.sh "$(ROOTFS_DIR)-arm64"
	ARCH=aarch64 BUSYBOX="$(CURDIR)/$(BUILD_DIR)/arm64/busybox" ./scripts/build-initramfs.sh "$(ROOTFS_DIR)-arm64" "$(IMAGE_DIR)/initramfs-arm64.cpio.gz"
	ARCH=aarch64 KERNEL="$(CURDIR)/$(BUILD_DIR)/arm64/Image" ./scripts/run-qemu.sh "$(IMAGE_DIR)/initramfs-arm64.cpio.gz"

update-init:
	./scripts/simulate-update.sh init

update-status:
	./scripts/simulate-update.sh status

update-install: images
	./scripts/simulate-update.sh install "$(IMAGE_DIR)/rootfs_b.squashfs"

update-good:
	./scripts/simulate-update.sh mark-good

update-bad:
	./scripts/simulate-update.sh mark-bad

tree: rootfs
	find "$(ROOTFS_DIR)" -maxdepth 3 -print | sort

clean:
	rm -rf "$(BUILD_DIR)"
