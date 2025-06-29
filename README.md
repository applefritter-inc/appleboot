# appleboot
this project allows you to boot linux on keyrolled devices with code execution in miniOS whilst in developer mode. \
it is heavily built on the way that shimboot works, albeit with a lot of modifications. \
it also heavily relies on [BadApple](https://github.com/applefritter-inc/BadApple), which allowed for the code execution in miniOS.

## support
1. your board must be disk layout v3
this project supports all boards that are on disk layout v3, list here:
```
nissa, skyrim, guybrush, corsola, rex, brya, brox, skywalker, rauru, cherry, geralt
```
2. your crOS version must be <v132, and if you have upgraded previously, you cannot downgrade anymore.
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
10. the payload will automatically start, and debian will run.

## credits
- [appleflyer](https://github.com/appleflyerv3): finding BadApple, writing the scripts
- [vk6/ading2210](https://github.com/ading2210/): the [shimboot](https://github.com/ading2210/shimboot) project source code. appleboot is technically a "copyleft" of the shimboot project, and appleboot's source code has been partially written with the shimboot source.
