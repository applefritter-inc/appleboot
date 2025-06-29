#!/bin/sh +x

SCRIPT_VERSION="1.0"
SCRIPT_TYPE="stable" # can be stable, beta, test, PoC
NEWROOT_DIR="/newroot"

TTY=0
MINIOS_SHELL_RUN="/run/frecon/vt$TTY"
APPLEBOOT_VOLUME=$1

main(){
    target=$1 # expected like /dev/sda2 or something
    mkdir -p "$NEWROOT_DIR"
    mount -v "$target" "$NEWROOT_DIR"

    if [ -f "/bin/frecon-lite" ]; then 
        rm -f /dev/console
        touch /dev/console # this has to be a regular file otherwise the system crashes afterwards
        mount -o bind "$TTY1" /dev/console
    fi

    # unload kernel modules before moving mounts, or else lsmod will fail due to /proc/modules not existing...
    for m in $(lsmod | awk 'NR>1 {print $1}' | tac); do
        modprobe -r "$m" 2>/dev/null || true
    done

    move_mounts "$NEWROOT_DIR"
    echo "mounts moved! switching root. waiting 2 seconds to do so..."
    sleep 2

    mount --make-rprivate /
    mkdir -p "${NEWROOT_DIR}/bootloader"

    echo "switching to new root with switch_root in 2 seconds... tty1: ${MINIOS_SHELL_RUN}"
    sleep 1

    # /dev/ttyS0,115200 for debugging with SuzyQ on a dev miniOS image.
    exec switch_root "$NEWROOT_DIR" /sbin/init -c /dev/ttyS0,115200 || {
        # doesnt work yet
        echo "switch_root failed ($?). dropping to shell..."
        exec /bin/sh
    }
}

debug_kernel_settings() {
    echo "8 4 1 8" > /proc/sys/kernel/printk
    echo 0 > /proc/sys/kernel/panic # infinite panic wait, do not reboot the chromebook
}

detect_tty() {
    if [ -f "/bin/frecon-lite" ]; then
        export TTY1="/run/frecon/vt0"
        export TTY2="/run/frecon/vt1"
    else
        export TTY1="/dev/tty1"
        export TTY2="/dev/tty2"
    fi
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

exec_init() {
    echo "tty1: ${TTY1}"
    echo "exec'ing init"
    exec /sbin/init < "$TTY1" >> "$TTY1" 2>&1
}

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
    echo 0 > /proc/sys/kernel/loadpin/enforce # allow the kernel modules to load
    kill -TERM -1
    sleep 1
    kill -KILL -1
}

disable_processes
init_frecon

# activate AFTER initing frecon!
exec >"$MINIOS_SHELL_RUN" 2>&1

# why is this not in the main.sh script?!?!?!? frecon is cleared when the hijack payload is called. this prompt should be on the screen.
echo "appleboot switch_root payload!"
echo "in process PID($$), (we should be PID1)"
echo "sleeping for 2 sec..."
sleep 2

# output kernel logs
#cat /dev/kmsg > "$MINIOS_SHELL_RUN" 2>&1 &

debug_kernel_settings
detect_tty
main "$APPLEBOOT_VOLUME" # $1 is the appleboot rootfs

# how did we end up here?
sleep infinity # will kernel panic if we dont sleep