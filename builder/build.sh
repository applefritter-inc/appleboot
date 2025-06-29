#!/bin/bash

ARCH="amd64"
COMPONENTS="main,contrib,non-free,non-free-firmware"
DEBIAN_RELEASE="bookworm"
CHROOT_SETUP="/opt/setup_rootfs.sh"
CHROOT_MOUNTS="/sys /proc /dev /run"

# build debian rootfs for appleboot

if [ "$EUID" -ne 0 ]; then
    echo "the builder is not running as root!! please ensure you run this as root/sudo."
    exit 1
fi

build_dir=$(realpath -m $1)
mkdir -p $build_dir
mp=$(findmnt -n -o TARGET --target "$build_dir")
opts=$(findmnt -n -o OPTIONS --target "$build_dir")
if echo "$opts" | grep -Eq '(^|,)noexec|nodev'; then
    echo ">>> Remounting $mp with exec,dev"
    mount -o remount,exec,dev "$mp"
fi


echo "bootstrapping our debian chroot..."
debootstrap --components=$COMPONENTS --arch $ARCH "$DEBIAN_RELEASE" "$build_dir" http://deb.debian.org/debian/

echo "copying rootfs setup files..." # stolen from shimboot thanks
cp -arv rootfs/* "$build_dir"

echo "bind mounting necessary mounts..."
for mnt in $CHROOT_MOUNTS; do
    # $mnt is a full path (leading '/'), so no '/' joiner
    mkdir -p "$build_dir$mnt"
    mount --make-rslave --rbind "$mnt" "${build_dir}${mnt}"
done

echo "chrooting into our build directory and running the rootfs setup script..."
LC_ALL=C chroot $build_dir /bin/sh -c "$CHROOT_SETUP"

echo "chroot setup script completed, unmounting bindmounts..."
for mnt in $CHROOT_MOUNTS; do
    umount -l "$build_dir$mnt"
done

echo "rootfs created!"