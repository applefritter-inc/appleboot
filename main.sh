#!/bin/sh
TEMPDIR=/temp
PAYLOAD_PATH=${TEMPDIR}/payload.sh
SHIMBOOT_PART_NUM=2

# thanks stack overflow
SCRIPT_PATH=$(readlink -f -- "$0")
SCRIPT_DIR=$(dirname -- "$SCRIPT_PATH") # current dir the script is in

mkdir $TEMPDIR
cp "${SCRIPT_DIR}/*" "$TEMPDIR"

DEV=$(df -P "$SCRIPT_DIR" | awk 'NR==2 { print $1 }')
DEVNAME=$(basename "$DEV")
case "$DEVNAME" in
    nvme[0-9]*n[0-9]*p[0-9]* | mmcblk[0-9]*p[0-9]*)
        BASE="${DEVNAME%p*}"
        DISK="/dev/${BASE}p${SHIMBOOT_PART_NUM}"
        ;;
    [a-z][a-z]?[0-9]*)
        BASE="${DEVNAME%%[0-9]*}"
        DISK="/dev/${BASE}${SHIMBOOT_PART_NUM}"
        ;;
    *)
        DISK="${DEV}${SHIMBOOT_PART_NUM}"
        ;;
esac

# pass exec to the setup
exec "${TEMPDIR}/init.sh" "$TEMPDIR" "$DISK" # pass our tempdir and shimboot boot disk
