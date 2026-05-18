# ANIS - Artix' Next Installation Script

## (runit)

![](https://img.shields.io/badge/OS-Artix%20Linux-blue?logo=Artix+Linux)

A simple installer for Artix Linux. Supports currently only runit in UEFI mode.

## Usage

Login to your live artix iso with root:artix

`curl -LOk https://github.com/CHAUVI666/ANIS/archive/refs/heads/main.zip`

`pacman -Sy unzip`

`unzip main.zip`

`cd ANIS-main`

`sh install.sh`

### Preinstallation

* ISO downloads can be found at [artixlinux.org](https://artixlinux.org/download.php)
* ISO files can be burned to drives with `dd` or something like Etcher.
* `sudo dd bs=4M if=/path/to/artix.iso of=/dev/sd[drive letter] status=progress`
* A better method these days is to use [Ventoy](https://www.ventoy.net/en/index.html).

### TODO

* ~~reimplement btrfs support~~
* ~~reimplement encrypted volume~~
* add BIOS support
* reimplement openrc & dinit support

### (((PLANNED)))

* adding snapshots for btrfs, but for that i have to learn more about btrfs myself since i only ever used ext4
* add option for zram