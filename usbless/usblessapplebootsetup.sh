fail(){
	printf "$1\n"
	printf "error occurred\n"
	exit
}
echo "Starting zip download"
curl -LO https://github.com/applefritter-inc/appleboot/releases/latest/download/appleboot-nissa.bin.zip || fail "Download failed"
echo "Extracting zip"
unzip appleboot-nissa.bin.zip || fail "Could not unzip"
echo "Setting up a loop"
losetup -r -P /dev/loop0 appleboot-nissa.bin || fail "Could not set up loop"
echo "Copying rootfs to stateful partition"
dd if=/dev/loop0p2 of=/dev/mmcblk0p1 || fail "Could not copy rootfs"
echo "Done!  Now run usblessappleboot.sh."
