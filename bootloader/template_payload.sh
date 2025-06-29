#!/bin/sh -x

TTY=0
MINIOS_SHELL_RUN="/run/frecon/vt$TTY"

init_frecon(){
    local resolution="$(/bin/frecon-lite --print-resolution)"
    local x_res="${resolution% *}"
    [ "${x_res}" -ge 1920 ] && scale=0 || scale=1

    /bin/frecon-lite --enable-vt1 --daemon --no-login --enable-gfx --enable-vts --scale="$scale" --clear "0x0" --pre-create-vts
    sleep 2
    printf "\033]switchvt:$TTY\a" > /run/frecon/current
}

disable_processes(){
    echo 0 > /sys/fs/selinux/enforce
    kill -TERM -1
    sleep 1
    kill -KILL -1
}

disable_processes
init_frecon

exec >"$MINIOS_SHELL_RUN" 2>&1

# code here
echo "hello"
# code ends

sleep infinity # will kernel panic if we dont sleep