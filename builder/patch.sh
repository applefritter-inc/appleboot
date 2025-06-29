#!/bin/bash
# 70-80% from shimboot code lol
# with the ROOT-A & miniOS-A partitions, patch the existing debian rootfs install.
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "the patcher is not running as root!! please ensure you run this as root/sudo."
    exit 1
fi

target_rootfs=$(realpath $1)
reco_bin=$(realpath $2)

copy_modules(){
    local rootfs_dir=$1 # our debian install
    local minios_dir=$2 # miniOS initramfs. we will be the ones deleting this directory
    local reco_dir=$3 # ROOT-A rootfs.

    rm -rf "${rootfs_dir}/lib/modules"
    cp -r "${minios_dir}/lib/modules" "${rootfs_dir}/lib/modules"

    mkdir -p "${rootfs_dir}/lib/firmware"
    cp -r --remove-destination "${minios_dir}/lib/firmware/"* "${rootfs_dir}/lib/firmware/"
    cp -r --remove-destination "${reco_dir}/lib/firmware/"* "${rootfs_dir}/lib/firmware/"

    mkdir -p "${rootfs_dir}/lib/modprobe.d/"
    mkdir -p "${rootfs_dir}/etc/modprobe.d/"
    cp -r "${reco_dir}/lib/modprobe.d/"* "${rootfs_dir}/lib/modprobe.d/"
    cp -r "${reco_dir}/etc/modprobe.d/"* "${rootfs_dir}/etc/modprobe.d/"

    #decompress kernel modules if necessary - debian won't recognize these otherwise
    local compressed_files="$(find "${rootfs_dir}/lib/modules" -name '*.gz')"
    if [ "$compressed_files" ]; then
        echo "$compressed_files" | xargs gunzip
        for kernel_dir in "$rootfs_dir/lib/modules/"*; do
            local version="$(basename "$kernel_dir")"
            depmod -b "$rootfs_dir" "$version"
        done
    fi
}

extract_miniOS_initramfs(){
    local kernel_bin="$1"
    local working_dir="$2"
    local output_dir="$3"

    local kernel_file="$(basename $kernel_bin)"
    local binwalk_out=$(binwalk --extract $kernel_bin --directory=$working_dir --run-as=root)
    local stage1_file=$(echo $binwalk_out | pcregrep -o1 "\d+\s+0x([0-9A-F]+)\s+xz compressed data")
    local stage1_dir="$working_dir/_$kernel_file.extracted"
    local stage1_path="$stage1_dir/$stage1_file"
    
    #extract the initramfs cpio archive from the kernel image
    binwalk --extract $stage1_path --directory=$stage1_dir --run-as=root > /dev/null
    local stage2_dir="$stage1_dir/_$stage1_file.extracted/"
    local cpio_file=$(file $stage2_dir/* | pcregrep -o1 "([0-9A-F]+):\s+ASCII cpio archive")
    local cpio_path="$stage2_dir/$cpio_file"

    rm -rf $output_dir
    mkdir $output_dir
    cpio -idmv -D "$output_dir" < "$cpio_path"
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

echo "mounting recovery image"
reco_loop=$(losetup -f --show -P "$reco_bin")
mkdir -p reco_rootfs minios_rootfs
mount -o ro "${reco_loop}p3" "reco_rootfs"

echo "extracting miniOS kernel blob"
dd if="${reco_loop}p9" of=minios_kernel.blob bs=512 status=progress

echo "extracting miniOS initramfs"
extract_miniOS_initramfs "minios_kernel.blob" "minios_extract" "minios_rootfs"
rm -rf minios_extract minios_kernel.blob

echo "copying modules"
copy_modules $(basename $target_rootfs) "minios_rootfs" "reco_rootfs"

echo "downloading and copying firmware"
copy_firmware $(basename $target_rootfs)

echo "deleting/unmounting rootfses"
umount reco_rootfs
rm -rf reco_rootfs minios_rootfs
losetup -d $reco_loop

echo "completed patching rootfs"