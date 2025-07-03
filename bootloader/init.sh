#!/bin/sh +x

ORIGINAL_SCRIPT_DIR=$1
TEMP_SCRIPT_DIR=$2
PAYLOAD_FILE="${TEMP_SCRIPT_DIR}/payload.sh"
CLAMIDE_BIN="${TEMP_SCRIPT_DIR}/clamide"
MAIN_DISK_DEV="$3"
RESCUE_MODE="$4"
# echos in this file would be almost impossible to see lol

echo "unmounting payload disk, since all our payloads have been copied to TEMP_SCRIPT_DIR..."
umount $ORIGINAL_SCRIPT_DIR

echo "enabling ptrace..."
echo 0 >/proc/sys/kernel/yama/ptrace_scope
if ! [ "$(cat /proc/sys/kernel/yama/ptrace_scope)" = "0" ]; then
    echo "failed to enable ptrace! this is fatal."
    sleep infinity
fi

echo "hijacking pid 1..."
sleep 1
$CLAMIDE_BIN -p 1 --syscall execve "str:$PAYLOAD_FILE" "arr:str:$PAYLOAD_FILE,str:$MAIN_DISK_DEV,str:$RESCUE_MODE,int:0" "int:0" # hijack PID 1 and make it call our payload

sleep infinity