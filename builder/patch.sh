#!/bin/bash
# 70-80% from shimboot code lol
# with the ROOT-A & miniOS-A partitions, patch the existing debian rootfs install.
set -Eeuo pipefail
trap 'rc=$?; fatal_exit "unexpected error (exit code $rc) at line ${LINENO}: \`${BASH_COMMAND}\`!"' ERR

cleanup() {
    if mountpoint -q reco_rootfs; then
        echo "unmounting reco_rootfs"
        umount reco_rootfs || echo "warning: failed to unmount reco_rootfs!!!"
    fi

    if [ -n "${reco_loop:-}" ]; then
        if losetup -j "$reco_bin" | grep -qF "$reco_loop"; then
            echo "detaching loop device $reco_loop"
            losetup -d "$reco_loop" || echo "warning: failed to detach $reco_loop!!"
        fi
    fi

    echo "cleaning up temp dirs"
    rm -rf reco_rootfs
}

fatal_exit() {
    echo "FATAL: $1"
    echo "this is fatal! errors here are VERY messy. attempting to clean up."
    cleanup
    echo "finished cleaning up, exiting on a fatal exit."
    exit 1
}

if [ "$EUID" -ne 0 ]; then
    echo "the patcher is not running as root!! please ensure you run this as root/sudo."
    exit 1
fi

target_rootfs=$(realpath $1)
reco_bin=$(realpath $2)

copy_libs(){
    local rootfs_dir=$1 # our debian install
    # local minios_dir=$2 # miniOS initramfs. we will be the ones deleting this directory
    local reco_dir=$2 # ROOT-A rootfs.

    # modules
    rm -rf "${rootfs_dir}/lib/modules"
    mkdir -p "${rootfs_dir}/lib/modules"
    # we do not load the miniOS modules here, because we don't know what miniOS version the user is on, which will cause the kernel modules to change too. kernel modules are strictly tied to that specific kernel build. instead, we autodetect in the bootloader, and copy over modules.
    #cp -a "${minios_dir}/lib/modules/." "${rootfs_dir}/lib/modules/"
    # we do not use the recovery image modules here, because they are of a different kernel!
    #cp -a "${reco_dir}/lib/modules/." "${rootfs_dir}/lib/modules/"

    # firmware
    rm -rf "${rootfs_dir}/lib/firmware"
    mkdir -p "${rootfs_dir}/lib/firmware"
    # since we removed our miniOS dependency, we will remove miniOS firmware copying here.
    #cp -a --remove-destination "${minios_dir}/lib/firmware/." "${rootfs_dir}/lib/firmware/"
    cp -a --remove-destination "${reco_dir}/lib/firmware/." "${rootfs_dir}/lib/firmware/"

    # modprobe configs
    mkdir -p "${rootfs_dir}/lib/modprobe.d" "${rootfs_dir}/etc/modprobe.d"
    cp -a "${reco_dir}/lib/modprobe.d/." "${rootfs_dir}/lib/modprobe.d/"
    cp -a "${reco_dir}/etc/modprobe.d/." "${rootfs_dir}/etc/modprobe.d/"
    
}

download_firmware() {
    local firmware_url="https://chromium.googlesource.com/chromiumos/third_party/linux-firmware"
    local firmware_path=$(realpath -m $1)

    git clone --branch master --depth=1 "${firmware_url}" $firmware_path
}

copy_firmware() {
    local firmware_path="/tmp/chromium-firmware"
    local target_rootfs=$(realpath -m $1)

    if [ ! -e "$firmware_path" ]; then
        download_firmware $firmware_path
    fi

    cp -r --remove-destination "${firmware_path}/"* "${target_rootfs}/lib/firmware/"
}

echo "patching rootfs with needed kernel drivers and firmware" 

echo "mounting recovery image"
reco_loop=$(losetup -f --show -P "$reco_bin")
mkdir -p reco_rootfs
mount -o ro "${reco_loop}p3" "reco_rootfs"

# echo "extracting miniOS kernel blob"
# dd if="${reco_loop}p9" of=minios_kernel.blob bs=512 status=progress

# echo "extracting miniOS initramfs"
# extract_miniOS_initramfs "minios_kernel.blob" "minios_extract" "minios_rootfs"
# rm -rf minios_extract minios_kernel.blob

echo "copying libraries"
copy_libs $(basename $target_rootfs) "reco_rootfs"

echo "downloading and copying firmware"
copy_firmware $(basename $target_rootfs)

echo "deleting/unmounting rootfses"
sync
sync
umount reco_rootfs
rm -rf reco_rootfs
losetup -d $reco_loop

echo "completed patching rootfs"