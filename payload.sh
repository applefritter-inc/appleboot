#!/bin/sh -x

SCRIPT_VERSION="0.1"
SCRIPT_TYPE="PoC" # can be stable, beta, test, PoC
NEWROOT_DIR="/newroot"
# FRECON_BACKGROUND=1E1E2E

TTY=0
MINIOS_SHELL_RUN="/run/frecon/vt$TTY"
SHIMBOOT_PARTITION=$1

main(){
    target=$1 # expected like /dev/sda or something
    mkdir -p "$NEWROOT_DIR"
    mount -v "$target" "$NEWROOT_DIR"

    if [ -f "/bin/frecon-lite" ]; then 
        rm -f /dev/console
        touch /dev/console #this has to be a regular file otherwise the system crashes afterwards
        mount -o bind "$TTY1" /dev/console
    fi

    move_mounts "$NEWROOT_DIR"
    echo "mounts moved! switching root. waiting 5 seconds to do so..."
    sleep 5

    mount --make-rprivate /

    mkdir -p "${NEWROOT_DIR}/bootloader"
    echo "switching root in 2 seconds..."
    sleep 2
    echo "switching to new root with switch_root..., tty1: ${MINIOS_SHELL_RUN}"
    sleep 1
    exec switch_root "$NEWROOT_DIR" /sbin/init < "$MINIOS_SHELL_RUN" >> "$MINIOS_SHELL_RUN" 2>&1 || {
        # idk if this works
        echo "switch_root failed ($?). dropping to shell..."
        exec /bin/sh
    }
    #exec_init
}

debug_kernel_settings() {
    echo "8 4 1 8" > /proc/sys/kernel/printk
    echo 0 > /proc/sys/kernel/panic # infinite panic wait, do not reboot the chromebook
}

test_fn() {
    echo "debug: in process PID$$. waiting forever..."
    sleep infinity
}

drop_to_shell

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
        # $mnt is a full path (leading '/'), so no '/' joiner
        mkdir -p "$newroot_mnt$mnt"
        mount -vn -o move "$mnt" "${newroot_mnt}${mnt}"
    done
}

exec_init() {
  # if [ "$rescue_mode" = "1" ]; then
  #   echo "entering a rescue shell instead of starting init"
  #   echo "once you are done fixing whatever is broken, run 'exec /sbin/init' to continue booting the system normally"
    
  #   if [ -f "/bin/bash" ]; then
  #     exec /bin/bash < "$TTY1" >> "$TTY1" 2>&1
  #   else
  #     exec /bin/sh < "$TTY1" >> "$TTY1" 2>&1
  #   fi
  # else
    echo "tty1: ${TTY1}"
    echo "exec'ing init"
    exec /sbin/init < "$TTY1" >> "$TTY1" 2>&1
  # fi
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
    kill -TERM -1
    sleep 1
    kill -KILL -1
}

disable_processes
init_frecon

# activate AFTER initing frecon!
exec >"$MINIOS_SHELL_RUN" 2>&1

# why is this not in the main.sh script?!?!?!? frecon is cleared when the hijack payload is called. this prompt should be on the screen.
echo "badapple-shimboot switch_root payload!"
echo "version v${SCRIPT_VERSION}. ${SCRIPT_TYPE} edition"
echo "sleeping for 5 sec..."
sleep 5

#cat /dev/kmsg > "$MINIOS_SHELL_RUN" 2>&1 &

debug_kernel_settings
#test_fn
detect_tty
main "$SHIMBOOT_PARTITION" # $1 is the shimboot rootfs