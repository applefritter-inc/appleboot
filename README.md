# appleboot
this project allows you to boot linux on keyrolled devices with code execution in miniOS whilst in developer mode. \
it is heavily built on the way that shimboot works, albeit with a lot of modifications. \
it also heavily relies on [BadApple](https://github.com/applefritter-inc/BadApple), which allowed for the code execution in miniOS.

currently, only `debian` is supported. would i add support for more distros in the future? probably not. maybe i'd merge PR requests, but i might not do much with this project after release. no promises.

## support
1. your board must be disk layout v3 \
this project supports all boards that are on disk layout v3, list here:
```
nissa, skyrim, guybrush, corsola, rex, brya, brox, skywalker, rauru, cherry, geralt
```
2. your crOS version must be `<v132`, and if you have upgraded previously, you cannot downgrade anymore. \
you must not have upgraded to crOS v132, or else this would NOT work, because BadApple has been patched on that version.

## how to use
1. go to `Releases` and grab a copy of appleboot for your board. e.g. `appleboot-nissa.bin` for the nissa board.
2. download and flash the image to a USB stick, as how you would with an RMA shim.
3. on your chromebook, enter developer mode with `ESC+REFRESH+POWER` and `CTRL+D`
4. when you reach the block screen, press `ESC+REFRESH+POWER` again
5. select `Internet Recovery`
6. when miniOS loads in, plug in your USB stick
7. open the VT3 with `CTRL+ALT+F3`
8. find the usb stick identifier with `fdisk -l`
9. when you've found the disk identifier, run the payload with `mount /dev/sdX1 /usb && /usb/main.sh` 
10. select your appleboot root disk with the bootloader, or select a disk manually.
11. you will then proceed to boot into debian!

## rescue mode
somehow, if you messed something up on your root system, appleboot offers a rescue mode.
1. enter the appleboot bootloader, which is steps 1-9 in the [how to use](#how-to-use) section.
2. select the option `r` to toggle rescue mode.
3. select your rootfs volume to enter rescue mode on that volume.
4. you will be given a bash shell after mounts are set up.

when you toggle rescue mode, the "rescue mode:" line in the bootloader will change from 0 to 1, and vice versa if it was toggled on. \
below demonstrates the bootloader when you enable rescue mode.

```
-------------------------------
welcome to the appleboot bootloader!
verson v1.0. stable edition
rescue mode: 1        <---- 1 means that rescue mode is enabled.
-------------------------------
available appleboot_rootfs volumes:
 1) /dev/sda2        4G  appleboot_rootfs:debian
-------------------------------
other options:
 m) manually specify your root disk
 r) toggle rescue mode
 q) exit
-------------------------------
enter selection:
```

## credits
- [appleflyer](https://github.com/appleflyerv3): finding [BadApple](https://github.com/applefritter-inc/BadApple), writing the scripts
- [vk6/ading2210](https://github.com/ading2210/): the [shimboot](https://github.com/ading2210/shimboot) project source code. appleboot is technically a "copyleft" of the shimboot project, and appleboot's source code has been partially written with the shimboot source.

## developer information

### how to build
*ensure you have at least 20gib free space on your build machine*

1. install the dependencies, which are: `cpio realpath mkfs.ext4 fdisk debootstrap findmnt wget git make`
2. clone the repository and enter it with
```sh
git clone https://github.com/applefritter-inc/ && sudo make BOARD=<board>
```
3. once it's done, the image should appear as `appleboot-*.bin`, e.g. `appleboot-nissa.bin`