#!/bin/bash

RECO_BIN=""
# create shimboot image
BOARD="nissa"
ROOTFS_DIR="rootfs-chroot"
RECO_ZIP="reco.zip"

if [ "$EUID" -ne 0 ]; then
    echo "the builder is not running as root!! please ensure you run this as root/sudo."
    exit 1
fi

get_reco_url() {
    local board=$1
    local boards_url="https://chromiumdash.appspot.com/cros/fetch_serving_builds?deviceCategory=ChromeOS"

    echo "downloading list of recovery images"
    local reco_url="$(wget -qO- --show-progress $boards_url | python3 -c '
import json, sys

all_builds = json.load(sys.stdin)
board_name = sys.argv[1]
if not board_name in all_builds["builds"]:
    print("Invalid board name: " + board_name, file=sys.stderr)
    sys.exit(1)

board = all_builds["builds"][board_name]
if "models" in board:
    for device in board["models"].values():
        if device["pushRecoveries"]:
            board = device
            break

reco_url = list(board["pushRecoveries"].values())[-1]
print(reco_url)
    ' $board)"
    echo "found recovery url: $reco_url"
    wget "$reco_url" -O "$RECO_ZIP"
    unzip "$RECO_ZIP"
    out=$(unzip -Z1 "$RECO_ZIP")
    mv -- "$out" reco.bin
}

./builder/build.sh "$ROOTFS_DIR"

if [ -z "${RECO_BIN}" ]; then
    get_reco_url $BOARD
    RECO_BIN="reco.bin"
fi

./builder/patch.sh "$ROOTFS_DIR" "$RECO_BIN"

rootfs_size="$(du -sm "$ROOTFS_DIR" | cut -f 1)"
rootfs_part_size=$(( rootfs_size * 12 / 10 + 5 ))

echo $rootfs_part_size