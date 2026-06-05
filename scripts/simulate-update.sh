#!/usr/bin/env sh
set -eu

STATE_DIR=${STATE_DIR:-build/update}
STATE=$STATE_DIR/state.env
BOOTLIMIT=${BOOTLIMIT:-3}

log() {
    printf '[mini-update] %s\n' "$*" >&2
}

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
    log "Durum dosyası güncellendi: $STATE"
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
    log "A/B güncelleme simülasyonu temiz bir başlangıç durumuna alındı."
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
        echo "Güncelleme durumu hazırlandı: $STATE"
        ;;
    status)
        load_state
        log "Mevcut slot durumu okunuyor. Aktif slot: $active_slot"
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
        log "Aktif slot '$active_slot'. Yeni imaj pasif slot '$slot' üzerine hazırlanıyor."
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
        log "İmaj kopyalandı: $dest"
        log "SHA256 özeti kaydedildi: $sha"
        echo "Güncelleme adayı simüle edilen '$slot' slotuna kuruldu."
        ;;
    mark-good)
        load_state
        if [ -z "$pending_slot" ]; then
            echo "Onaylanacak bekleyen slot yok. Aktif slot aynı kaldı: $active_slot"
            exit 0
        fi
        log "Bekleyen slot '$pending_slot' başarılı açılmış kabul ediliyor."
        active_slot=$pending_slot
        pending_slot=
        bootcount=0
        last_result=confirmed
        write_state
        echo "Yeni slot onaylandı. Aktif slot artık: $active_slot"
        ;;
    mark-bad)
        load_state
        if [ -z "$pending_slot" ]; then
            echo "Bekleyen slot yok. Aktif slot aynı kaldı: $active_slot"
            exit 0
        fi
        bootcount=$((bootcount + 1))
        log "Bekleyen slot '$pending_slot' için başarısız boot kaydedildi: $bootcount/$bootlimit"
        if [ "$bootcount" -ge "$bootlimit" ]; then
            failed_slot=$pending_slot
            pending_slot=
            bootcount=0
            last_result="rollback_from_$failed_slot"
            echo "Boot deneme limiti doldu. Sistem '$active_slot' slotuna geri döndü."
        else
            last_result="boot_failed_$bootcount"
            echo "Boot başarısız sayıldı. Yeniden deneme: $bootcount/$bootlimit"
        fi
        write_state
        ;;
    *)
        usage
        exit 2
        ;;
esac
