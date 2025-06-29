#!/bin/sh
TEMPDIR=/temp
APPLEBOOT_PART_NUM=2 # should be 2 in prod

# thanks stack overflow
SCRIPT_PATH=$(readlink -f -- "$0")
SCRIPT_DIR=$(dirname -- "$SCRIPT_PATH") # current dir the script is in

mkdir -p $TEMPDIR
cp ${SCRIPT_DIR}/* "$TEMPDIR"

# TODO(appleflyer): don't use this, we need a better way to select our appleboot rootfs disk...
DEV=$(df -P "$SCRIPT_DIR" | awk 'NR==2 { print $1 }')
DEVNAME=$(basename "$DEV")
case "$DEVNAME" in
    nvme[0-9]*n[0-9]*p[0-9]* | mmcblk[0-9]*p[0-9]*)
        BASE="${DEVNAME%p*}"
        DISK="/dev/${BASE}p${APPLEBOOT_PART_NUM}"
        ;;
    [a-z][a-z]?[0-9]*)
        BASE="${DEVNAME%%[0-9]*}"
        DISK="/dev/${BASE}${APPLEBOOT_PART_NUM}"
        ;;
    *)
        echo "something went wrong with detecting your USB drive!! please report this."
        echo "debug info: ${DEV} ${DEVNAME}"
        exit
        ;;
esac
echo "detected appleboot partition: $DISK"

# pass exec to the setup
exec "${TEMPDIR}/init.sh" "$SCRIPT_DIR" "$TEMPDIR" "$DISK" # pass our tempdir and appleboot boot disk
