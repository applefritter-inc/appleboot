#!/bin/sh +x

SCRIPT_VERSION="1.0"
SCRIPT_TYPE="stable" # can be stable, beta, test, PoC
NEWROOT_DIR="/newroot"
RESCUE_SHELL="/bin/bash"

TTY=0
MINIOS_SHELL_RUN="/dev/pts/$TTY"
APPLEBOOT_VOLUME=$1
RESCUE_MODE=$2

open_shell() { # this means that something went very wrong, probably because the root disk is broken. this should only happen if the user manually selects a root disk, and the root disk didnt have a rootfs.
    local tty=$1
    # enable input & cursor
    printf "\033[?25h" > "$tty"
    printf "\033]input:on\a" > "$tty"

    # enable the shell
    exec /bin/sh < "$tty" >> "$tty" 2>&1
}

copy_modules_to_rootfs() {
    local target=$1 # the root directory of the newroot location

    if [ ! -d "${target}/lib/modules/$(uname -r)" ]; then
        echo "modules not in the rootfs!! auto-copying modules to rootfs."
        mkdir -p "${target}/lib/modules/$(uname -r)"
        cp -a "/lib/modules/$(uname -r)/." "${target}/lib/modules/$(uname -r)"

        # from shimboot
        #decompress kernel modules if necessary - debian won't recognize these otherwise
        local compressed_files="$(find "${target}/lib/modules/$(uname -r)" -name '*.gz')"
        if [ "$compressed_files" ]; then
            echo "$compressed_files" | xargs gunzip
            # busybox depmod has a bad implementation of depmod. chroot into target and depmod ourselves.
            # depmod -b "$target" "$(uname -r)"
            chroot "$target" /usr/sbin/depmod "$(uname -r)"
        fi
    else
        echo "modules exist in rootfs, not copying modules..."
    fi
}

main(){
    target=$1 # expected like /dev/sda2 or something
    mkdir -p "$NEWROOT_DIR"
    mount -v "$target" "$NEWROOT_DIR"

    copy_modules_to_rootfs "$NEWROOT_DIR"

    # unload kernel modules before moving mounts, or else lsmod will fail due to /proc/modules not existing...
    for m in $(lsmod | awk 'NR>1 {print $1}' | tac); do
        modprobe -r "$m" 2>/dev/null || true
    done

    move_mounts "$NEWROOT_DIR"
    echo "mounts moved! switching root to the new rootfs with switch_root."
    echo "sleeping for 2 seconds..."
    sleep 2

    # /dev/ttyS0 for debugging with SuzyQ on a dev miniOS image.
    switch_root_cmd="switch_root -c /dev/ttyS0 $NEWROOT_DIR /sbin/init"
    switch_root_cmd_rescue="switch_root -c /dev/console $NEWROOT_DIR $RESCUE_SHELL -i"

    if [ "$RESCUE_MODE" -ne 0 ]; then
        switch_root_cmd=$switch_root_cmd_rescue
        export TERM=vt100
        
        printf "\n"
        echo "entering rescue mode in the rootfs..."
        echo "tip: once you're done, you can run 'exec /sbin/init' to continue booting into the system! (we are in the appleboot rootfs)"
        printf "\n"

        # enable input
        printf "\033[?25h" > "/console/vt0"
        printf "\033]input:on\a" > "/console/vt0"
    fi

    if [ "$RESCUE_MODE" -eq 0 ]; then
        if [ ! -L "${NEWROOT_DIR}/sbin/init" ]; then # this checks if the /sbin/init symlink exists, not its target. since we aren't in the nrw root filesystem yet, it's target will point to nothing.
            # we cannot recover from this point, it is very difficult for the end user to recover from here. instead, we shall drop to rescue mode.
            echo "/sbin/init does not exist on the newroot! dropping to a shell...(we are still in miniOS)"
            open_shell /console/vt0
        fi
    fi

    exec $switch_root_cmd || {
        echo "switch_root failed ($?). dropping to shell...(we are still in miniOS)"
        open_shell /console/vt0
    }
}

debug_kernel_settings() {
    echo "8 4 1 8" > /proc/sys/kernel/printk
    echo 0 > /proc/sys/kernel/panic # infinite panic wait, do not reboot the chromebook, in the event of a panic
}

move_mounts() {
    local base_mounts="/sys /proc /dev"
    local unmount_devices="/tmp /run"
    local newroot_mnt="$1"

    for umnt in $unmount_devices; do
        umount -l "$umnt"
    done

    for mnt in $base_mounts; do
        mkdir -p "$newroot_mnt$mnt"
        mount -vn -o move "$mnt" "${newroot_mnt}${mnt}"
    done
}

init_frecon(){
    # this is to ensure that vt1 doesnt end up on /dev/pts/0
    umount /dev/pts
    mount -t devpts devpts /dev/pts -o rw,newinstance,nosuid,noexec,relatime,mode=600,ptmxmode=000

    # now, we actually setup frecon
    local resolution="$(/bin/frecon-lite --print-resolution)"
    local x_res="${resolution% *}"
    [ "${x_res}" -ge 1920 ] && scale=0 || scale=1

    /bin/frecon-lite --enable-vt1 --enable-vts --daemon --no-login --enable-osc --scale="$scale" --clear "0x0" --pre-create-vts
    sleep 2
    printf "\033]switchvt:$TTY\a" > /run/frecon/current
}

bind_frecon_pts(){
    if [ -f "/bin/frecon-lite" ]; then 
        # this is for our newroot to make /dev/console work
        rm -f /dev/console
        touch /dev/console # this has to be a regular file otherwise the system crashes afterwards
        mount -o bind $MINIOS_SHELL_RUN /dev/console

        # allows us to open a debug shell while booting!
        # bind mount /dev/pts/0 -> /console/vt0 and so on
        rm -f /console
        mkdir -p /console
        local vts="0 1 2 3"
        for vt in $vts; do
            touch /console/vt$vt
            mount -o bind /dev/pts/$vt /console/vt$vt
        done
    fi
}

disable_processes(){
    echo 0 > /sys/fs/selinux/enforce
    echo 0 > /proc/sys/kernel/loadpin/enforce # allow the kernel modules to load
    kill -TERM -1
    sleep 1
    kill -KILL -1
    sleep 1 # wait a bit
}

stty -F /dev/ttyS0 115200 # set the baud rate, for some reason 115200 is not set by default
disable_processes
init_frecon

# activate AFTER initing frecon, we want as much logging as possible.
exec >"$MINIOS_SHELL_RUN" 2>&1

bind_frecon_pts

# why is this not in the main.sh script?!?!?!? frecon is cleared when the hijack payload is called. this prompt should be on the screen.
echo "welcome to the appleboot switch_root payload!"
echo "in process PID($$), (we should be PID1)."
echo "sleeping for 2 seconds..."
printf "\n"
sleep 2

debug_kernel_settings
main "$APPLEBOOT_VOLUME" "$RESCUE_MODE"

# how did we end up here?
sleep infinity # will kernel panic if we dont sleep
