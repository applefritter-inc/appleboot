# appleboot
this project allows you to boot linux on keyrolled devices with code execution in miniOS whilst in developer mode. \
it is heavily built on the way that shimboot works, albeit with a lot of modifications. \
it also heavily relies on [BadApple](https://github.com/applefritter-inc/BadApple), which allowed for the code execution in miniOS.

currently, only `debian` is supported. would i add support for more distros in the future? probably not. maybe i'd merge PR requests, but i might not do much with this project after release. no promises.

## support
1. your board must be disk layout v3 \
this project supports all boards that are on disk layout v3, list here:
```
nissa, skyrim, guybrush, corsola, rex, brya, brox, rauru, cherry, geralt
```
but, if your board has shims and is not keyrolled, you should use [shimboot](https://github.com/ading2210/shimboot) instead. \
the only board on this list that has shims, and is not keyrolled, is `brya`

2. your crOS version must be `<v132`, and if you have upgraded previously, you cannot downgrade anymore. \
you must not have upgraded to crOS v132, or else this would NOT work, because BadApple has been patched on that version.

## how to use
there are 2 ways of using appleboot.
1. usb guide(requires a usb)
2. usbless guide(does not require a usb)

### usb guide
1. go to `Releases` and grab a copy of appleboot for your architecture. e.g. amd64 boards is `appleboot-amd64.bin`
amd64 boards
```
nissa, skyrim, guybrush, rex, brya, brox
```

arm64 boards
```
corsola, rauru, cherry, geralt
```
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

### usbless guide
1. enter miniOS, which is steps 1-5 in the [how to use](#how-to-use) section.
2. when miniOS loads, click `Next` to move to the next page
3. connect to a network on the `Connect to a network to begin recovery` page
4. once you connect to the internet, you will see a `Start recovery` page. DO NOT PROCEED.
5. open the VT3 with `CTRL+ALT+F3` to enter BadApple
6. start the bootloader with `cd / && curl -LOk appleboot.appleflyer.xyz/usbless.sh && sh usbless.sh`
7. you will be presented with the option `i` to download an appleboot rootfs from the internet, onto an existing partition. PLEASE install it on the stateful partition, do not install it on the root disk, or you may not be able to boot into appleboot again once you restart. (you may install it onto a usb stick partition too, if you want)
8. once you download the rootfs, boot into appleboot by selecting your appleboot root disk from the bootloader.
9. you will proceed to boot into debian.

note: you only need to install the rootfs once. after which, you may skip step 7 everytime you boot into appleboot.

## rescue mode
somehow, if you messed something up on your root system, appleboot offers a rescue mode.
1. enter the appleboot bootloader, which is steps 1-9 in the [how to use](#how-to-use) section.
2. select the option `r` to toggle rescue mode.
3. select your rootfs volume to enter rescue mode on that volume.
4. you will be given a bash shell after mounts are set up.

when you toggle rescue mode, the `rescue mode:` line in the bootloader will change from `0` to `1`, and vice versa if it was toggled on. \
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

## i messed up rootfs
*this guide is different from the usbless guide!!*
*this only works if your bootloader still exists. if it doesn't, you will need to use the usbless guide. the usbless guide can also install the rootfs to another usb if needed.*

somehow, if you really really messed something up on your root system, e.g. rm -rf'ing your entire system, you still have a chance to recover. \
since miniOS has the ability to connect to networking, all you need to do is:

1. enter miniOS, which is steps 1-5 in the [how to use](#how-to-use) section.
2. when miniOS loads, click `Next` to move to the next page
3. connect to a network on the `Connect to a network to begin recovery` page
4. once you connect to the internet, you will see a `Start recovery` page. DO NOT PROCEED.
5. instead, perform appleboot by plugging in your appleboot USB and performing steps 7-9 in the [how to use](#how-to-use) section.
6. you will be presented with the option to download an appleboot rootfs from the internet, onto an existing partition.
7. once you download the rootfs, boot into appleboot by selecting your appleboot root disk from the bootloader. select your USB stick partition(partition 2)
8. you will proceed to boot into debian.

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