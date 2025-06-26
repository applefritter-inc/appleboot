#!/bin/sh +x

TTY=/run/frecon/vt0
# BACKGROUND=1E1E2E

init_frecon(){
    local resolution="$(/bin/frecon-lite --print-resolution)"
    local x_res="${resolution% *}"
    [ "${x_res}" -ge 1920 ] && scale=0 || scale=1

    /bin/frecon-lite --enable-vt1 --daemon --no-login --enable-gfx \
                --enable-vts --scale="$scale" \
                --clear "0x0" --pre-create-vts
    sleep 2
    printf "\033]switchvt:0\a" > /run/frecon/current
}

init_frecon

exec <$TTY
exec >$TTY
exec 2>$TTY

exec /bin/sh
