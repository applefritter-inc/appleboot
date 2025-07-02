#!/bin/sh +x

SCRIPT_VERSION="1.0"
SCRIPT_TYPE="stable" # can be stable, beta, test, PoC
TEMPDIR=/temp
APPLEBOOT_PART_NUM=2 # should be 2 in prod
PREFIX="appleboot_rootfs:"

SCRIPT_PATH=$(readlink -f -- "$0")
SCRIPT_DIR=$(dirname -- "$SCRIPT_PATH")
rescue_status=0

INTERNET_BOOT_FORCE="$1"
INTERNET_BOOT_FORCE_MAGIC="download_rootfs_force"
internet_install_rootfs=0

if [ "$INTERNET_BOOT_FORCE" = "$INTERNET_BOOT_FORCE_MAGIC" ]; then
    echo "booted from internet bootloader, assuming internet connected."
    internet_install_rootfs=1
fi

if [ $internet_install_rootfs -ne 1 ]; then # if we didnt boot with the usbless script, check our networking.
    if ping -c 1 -W 2 google.com >/dev/null 2>&1; then
        echo "internet connected, enabling download rootfs option..."
        internet_install_rootfs=1
    fi
fi

mkdir -p "$TEMPDIR"
cp "${SCRIPT_DIR}"/* "$TEMPDIR"

list_partitions_raw(){
    local prefix_loc=$1
    count=0
    for udev_dir in by-partlabel by-label; do
        for link in /dev/disk/$udev_dir/${prefix_loc}*; do
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
}

list_partitions() {
    echo "-------------------------------"
    echo "welcome to the appleboot bootloader!"
    echo "version v${SCRIPT_VERSION}. ${SCRIPT_TYPE} edition"
    printf "\n"
    echo "rescue mode?: ${rescue_status}"
    echo "internet rootfs download enabled?: ${internet_install_rootfs}"
    echo "-------------------------------"
    echo "available appleboot_rootfs volumes:"

    list_partitions_raw $PREFIX

    if [ $count -eq 0 ] 2>/dev/null; then
        if [ $internet_install_rootfs -eq 1 ] 2>/dev/null; then
            echo "warning: NO appleboot_rootfs partitions detected!! since you're connected to the internet, you still the option to either download the rootfs from the internet onto a partition, or manually select a root disk."
        else
            echo "warning: NO appleboot_rootfs partitions detected!! you will need to either manually select a root disk, or exit this script."
        fi
    fi
}

selection_loop(){
    while :; do
        echo "-------------------------------"
        echo "other options:"
        if [ $internet_install_rootfs -eq 1 ] 2>/dev/null; then
            echo " i) install rootfs from the internet"
        fi
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

        if [ $internet_install_rootfs -eq 1 ] 2>/dev/null; then
            if [ "$sel" = "i" ] 2>/dev/null; then
                # download rootfs partition.
                # note: we have to flash to the rootfs directly, because the initramfs can only occupy a max of 50% of the RAM, and that may not be enough storage on some boards.

                # here, we list all partitions we can choose from.
                clear
                echo "-------------------------------"
                echo "target partitions/disks you can choose from:"
                list_partitions_raw "" # no prefix
                while :; do

                    echo "-------------------------------"
                    echo "other options:"
                    echo " q) return to bootloader"
                    echo "-------------------------------"
                    printf "enter selection: "
                    
                    read sel2
                    
                    if [ "$sel2" = "q" ] 2>/dev/null; then
                        echo "returning back to the bootloader..."
                        break # this will break us out of the loop and make us fall back into the original bootloader.
                    fi

                    local a=0
                    local install_disk=""
                    for udev_dir in by-partlabel by-label; do
                        for link2 in /dev/disk/$udev_dir/*; do
                            [ -e "$link2" ] || continue
                            a=$((a+1))
                            if [ "$a" -eq "$sel2" ] 2>/dev/null; then
                                install_disk=$(readlink -f "$link2")
                                break 2
                            fi
                        done
                    done

                    if [ -z "$install_disk" ]; then
                        clear
                        echo "you selected an invalid option! please try again." >&2
                        printf "\n"
                        list_partitions_raw "" # no prefix
                        continue
                    fi

                    # if we reached here, a valid install_disk has to be specified.
                    read -rp "about to overwrite $install_disk with the appleboot rootfs. are you sure? [y/N] " yn
                    case "$yn" in
                        [Yy]*) 
                            ;;
                        *)
                            echo "aborting and returning to the main bootloader..."; break ;;
                    esac

                    # download image
                    echo "WIP"
                    break
                    
                    local image_url="https://something.com/appleboot-${board}_rootfs.bin"
                    local target_disk="/dev/targetp1"

                    curl -# -L ${image_url} | sudo dd of=${install_disk} bs=4M conv=fsync

                    break
                done

                # return to original bootloader
                clear
                list_partitions
                continue
            fi
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

echo "selected appleboot_rootfs partition: $DISK"

# hand off to init.sh
exec "${TEMPDIR}/init.sh" "$SCRIPT_DIR" "$TEMPDIR" "$DISK" "$rescue_status"
