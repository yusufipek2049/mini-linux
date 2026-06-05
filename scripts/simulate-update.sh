#!/usr/bin/env sh
set -eu

STATE_DIR=${STATE_DIR:-build/update}
STATE=$STATE_DIR/state.env
BOOTLIMIT=${BOOTLIMIT:-3}

usage() {
    echo "usage: $0 {init|status|install IMAGE|mark-good|mark-bad}" >&2
}

write_state() {
    mkdir -p "$STATE_DIR"
    {
        echo "active_slot=$active_slot"
        echo "pending_slot=$pending_slot"
        echo "bootcount=$bootcount"
        echo "bootlimit=$bootlimit"
        echo "version_a=$version_a"
        echo "version_b=$version_b"
        echo "last_update_sha=$last_update_sha"
        echo "last_result=$last_result"
    } > "$STATE"
}

init_state() {
    active_slot=a
    pending_slot=
    bootcount=0
    bootlimit=$BOOTLIMIT
    version_a=1.0.0
    version_b=empty
    last_update_sha=
    last_result=initialized
    write_state
}

load_state() {
    [ -f "$STATE" ] || init_state
    . "$STATE"
}

inactive_slot() {
    if [ "$active_slot" = "a" ]; then
        echo b
    else
        echo a
    fi
}

cmd=${1:-}

case "$cmd" in
    init)
        init_state
        echo "update state initialized at $STATE"
        ;;
    status)
        load_state
        cat "$STATE"
        ;;
    install)
        image=${2:-}
        [ -n "$image" ] || {
            usage
            exit 2
        }
        [ -r "$image" ] || {
            echo "image not readable: $image" >&2
            exit 1
        }
        load_state
        slot=$(inactive_slot)
        dest="$STATE_DIR/rootfs_$slot.squashfs"
        mkdir -p "$STATE_DIR"
        cp "$image" "$dest"
        sha=$(sha256sum "$dest" | awk '{print $1}')
        pending_slot=$slot
        bootcount=0
        last_update_sha=$sha
        last_result="pending_slot_$slot"
        if [ "$slot" = "a" ]; then
            version_a="staged"
        else
            version_b="staged"
        fi
        write_state
        echo "installed update candidate to simulated slot $slot"
        ;;
    mark-good)
        load_state
        if [ -z "$pending_slot" ]; then
            echo "no pending slot to confirm"
            exit 0
        fi
        active_slot=$pending_slot
        pending_slot=
        bootcount=0
        last_result=confirmed
        write_state
        echo "pending slot confirmed"
        ;;
    mark-bad)
        load_state
        if [ -z "$pending_slot" ]; then
            echo "no pending slot; active slot remains $active_slot"
            exit 0
        fi
        bootcount=$((bootcount + 1))
        if [ "$bootcount" -ge "$bootlimit" ]; then
            failed_slot=$pending_slot
            pending_slot=
            bootcount=0
            last_result="rollback_from_$failed_slot"
            echo "bootlimit reached; rolled back to slot $active_slot"
        else
            last_result="boot_failed_$bootcount"
            echo "boot failed; retry $bootcount/$bootlimit"
        fi
        write_state
        ;;
    *)
        usage
        exit 2
        ;;
esac

