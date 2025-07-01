#!/bin/sh +x

SCRIPT_VERSION="1.0"
SCRIPT_TYPE="stable" # can be stable, beta, test, PoC
TEMPDIR=/temp
APPLEBOOT_PART_NUM=2 # should be 2 in prod
PREFIX="appleboot_rootfs:"

SCRIPT_PATH=$(readlink -f -- "$0")
SCRIPT_DIR=$(dirname -- "$SCRIPT_PATH")
rescue_status=0

mkdir -p "$TEMPDIR"
cp "${SCRIPT_DIR}"/* "$TEMPDIR"

list_partitions() {
    echo "-------------------------------"
    echo "welcome to the appleboot bootloader!"
    echo "version v${SCRIPT_VERSION}. ${SCRIPT_TYPE} edition"
    echo "rescue mode: ${rescue_status}"
    echo "-------------------------------"
    echo "available appleboot_rootfs volumes:"

    count=0

    for udev_dir in by-partlabel by-label; do
        for link in /dev/disk/$udev_dir/${PREFIX}*; do
            [ -e "$link" ] || continue
            count=$((count+1))
            dev=$(readlink -f "$link")
            label=${link##*/}

            bytes=$(blockdev --getsize64 "$dev")

            if [ "$bytes" -ge $((1024**3)) ]; then
                size="$((bytes / $((1024**3))))G"
            elif [ "$bytes" -ge $((1024**2)) ]; then
                size="$((bytes / $((1024**2))))M"
            elif [ "$bytes" -ge 1024 ]; then
                size="$((bytes / 1024))K"
            else
                size="${bytes}B"
            fi

            printf "%2d) %-12s %6s  %s\n" "$count" "$dev" "$size" "$label" # thank u chatgpt cuz miniOS has no column command :sob: <3
        done
    done

    if [ $count -eq 0 ] 2>/dev/null; then
        echo "warning: NO appleboot_rootfs partitions detected!! you will need to either manually select a root disk, or exit this script."
    fi
}

selection_loop(){
    while :; do
        echo "-------------------------------"
        echo "other options:"
        echo " m) manually specify your root disk"
        echo " r) toggle rescue mode"
        echo " q) exit"
        echo "-------------------------------"
        printf "enter selection: "
        read sel

        if [ "$sel" = "q" ] 2>/dev/null; then
            echo "exiting by user's choice..."
            exit 0
        fi

        if [ "$sel" = "r" ] 2>/dev/null; then
            rescue_status=$(( ! rescue_status ))
            # no need to echo anything, the rescue mode status will update itself when we list the partitions.
            clear
            list_partitions
            continue
        fi

        if [ "$sel" = "m" ] 2>/dev/null; then
            printf "enter your desired root disk (e.g. /dev/sda2): "
            read DISK
            if [ ! -b "$DISK" ]; then
                clear
                echo "error: $DISK is not a valid disk!" >&2
                printf "\n"
                list_partitions
                continue
            fi
            break
        fi

        i=0
        DISK=""
        for udev_dir in by-partlabel by-label; do
            for link in /dev/disk/$udev_dir/${PREFIX}*; do
                [ -e "$link" ] || continue
                i=$((i+1))
                if [ "$i" -eq "$sel" ] 2>/dev/null; then
                    DISK=$(readlink -f "$link")
                    break 2
                fi
            done
        done

        if [ -z "$DISK" ]; then
            clear
            echo "you selected an invalid option! please try again." >&2
            printf "\n"
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

echo "Selected appleboot_rootfs partition: $DISK"

# hand off to init.sh
exec "${TEMPDIR}/init.sh" "$SCRIPT_DIR" "$TEMPDIR" "$DISK" "$rescue_status"
