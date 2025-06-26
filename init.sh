#!/bin/sh

echo 0 >/proc/sys/kernel/yama/ptrace_scope
if ! [ "$(cat /proc/sys/kernel/yama/ptrace_scope)" = "0" ]; then
    echo "failed to enable ptrace"
    sleep 1d
fi

/tmploader/clamide -p 1 --syscall execve "str:/tmploader/badapple_shimboot.sh"

echo "cleaning up miniOS crap"
pkill -f frecon