#!/bin/bash
# build debian rootfs for appleboot
set -euo pipefail

ARCH="amd64"
COMPONENTS="main,contrib,non-free,non-free-firmware"
DEBIAN_RELEASE="bookworm"
CHROOT_SETUP="/opt/setup_rootfs.sh"
CHROOT_MOUNTS="/sys /proc /dev /run"

if [ "$EUID" -ne 0 ]; then
    echo "the builder is not running as root!! please ensure you run this as root/sudo."
    exit 1
fi

fatal_exit() {
    echo "FATAL: $1"
    echo "this is fatal, exiting..."
    exit 1
}

build_dir=$(realpath -m $1)
mkdir -p $build_dir

need_remount() {
    local target="$1"
    local mnt_options="$(findmnt -T "$target" | tail -n1 | rev | cut -f1 -d' '| rev)"
    echo "$mnt_options" | grep -e "noexec" -e "nodev"
}

do_remount() {
    local target="$1"
    local mountpoint="$(findmnt -T "$target" | tail -n1 | cut -f1 -d' ')"
    mount -o remount,dev,exec "$mountpoint"
}

# apparently this is important
if [ "$(need_remount "$build_dir")" ]; then
  do_remount "$build_dir"
fi

echo "bootstrapping our debian chroot..."
debootstrap --components=$COMPONENTS --arch $ARCH "$DEBIAN_RELEASE" "$build_dir" http://deb.debian.org/debian/ || fatal_exit "debootstrap failed!"

echo "copying rootfs setup files..." # stolen from shimboot thanks
cp -arv rootfs/* "$build_dir"

echo "bind mounting necessary mounts..."
for mnt in $CHROOT_MOUNTS; do
    # $mnt is a full path (leading '/'), so no '/' joiner
    mkdir -p "$build_dir$mnt"
    mount --make-rslave --rbind "$mnt" "${build_dir}${mnt}"
done

echo "chrooting into our build directory and running the rootfs setup script..."
set +e
LC_ALL=C chroot $build_dir /bin/sh -c "$CHROOT_SETUP"
echo "chroot exited with code $?"
set -e

echo "chroot setup script completed, unmounting bindmounts..."
for mnt in $CHROOT_MOUNTS; do
    umount -l "$build_dir$mnt"
done

echo "rootfs created!"