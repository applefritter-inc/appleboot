#!/bin/sh +x

TEMPDIR=/temp
APPLEBOOT_PART_NUM=2 # should be 2 in prod
PARTLABEL_PREFIX="appleboot_rootfs:"

SCRIPT_PATH=$(readlink -f -- "$0")
SCRIPT_DIR=$(dirname -- "$SCRIPT_PATH")

mkdir -p "$TEMPDIR"
cp "${SCRIPT_DIR}"/* "$TEMPDIR"

# check for any appleboot_rootfs partitions
found=0
for link in /dev/disk/by-partlabel/${PARTLABEL_PREFIX}*; do
    [ -e "$link" ] && found=1 && break
done

list_partitions() {
    echo "-------------------------------"
    echo "available appleboot_rootfs partitions:"
    count=0
    for link in /dev/disk/by-partlabel/${PARTLABEL_PREFIX}*; do
        [ -e "$link" ] || continue
        count=$((count+1))
        dev=$(readlink -f "$link")
        label=${link##*/}

        if command -v blockdev >/dev/null 2>&1; then
            bytes=$(blockdev --getsize64 "$dev")
        else
            base=$(basename "$dev")
            if [ -r /sys/class/block/"$base"/size ]; then
                sectors=$(cat /sys/class/block/"$base"/size)
                bytes=$((sectors * 512))
            else
                bytes=0
            fi
        fi

        if [ "$bytes" -ge $((1024*1024*1024)) ]; then
            g=$((bytes / $((1024*1024*1024))))
            size="${g}G"
        elif [ "$bytes" -ge $((1024*1024)) ]; then
            m=$((bytes / $((1024*1024))))
            size="${m}M"
        elif [ "$bytes" -ge 1024 ]; then
            k=$((bytes / 1024))
            size="${k}K"
        else
            size="${bytes}B"
        fi

        printf "%2d) %-12s %6s  %s\n" "$count" "$dev" "$size" "$label" # thank u chatgpt cuz miniOS has no column command :sob: <3
    done

    if [ $count -eq 0 ] 2>/dev/null; then
        echo "warning: NO appleboot_rootfs partitions detected!! you will need to either manually select a root disk, or exit this script."
    fi
}

selection_loop(){
    while :; do
        echo "-------------------------------"
        echo "(-1 to exit, 0 to manually specify a root disk)"
        printf "enter selection: "
        read sel

        if [ "$sel" -eq -1 ] 2>/dev/null; then
            echo "exiting by user's choice..."
            exit 0
        fi

        if [ "$sel" -eq 0 ] 2>/dev/null; then
            printf "enter your desired root disk (e.g. /dev/sda2): "
            read DISK
            if [ ! -b "$DISK" ]; then
                clear
                echo "error: $DISK is not a valid disk!" >&2
                echo
                list_partitions
                continue
            fi
            break
        fi

        i=0
        DISK=""
        for link in /dev/disk/by-partlabel/${PARTLABEL_PREFIX}*; do
            [ -e "$link" ] || continue
            i=$((i+1))
            if [ "$i" -eq "$sel" ] 2>/dev/null; then
                DISK=$(readlink -f "$link")
                break
            fi
        done

        if [ -z "$DISK" ]; then
            clear
            echo "you selected an invalid option! please try again." >&2
            echo
            list_partitions
            continue
        fi

        break
    done
}

# start the appleboot root disk selector
clear
list_partitions
selection_loop

echo "selected appleboot_rootfs partition: $DISK"

# hand off to init.sh
exec "${TEMPDIR}/init.sh" "$SCRIPT_DIR" "$TEMPDIR" "$DISK"
