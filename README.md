# ANIS - Artix Neat Installation Script

## (runit)

![](https://img.shields.io/badge/OS-Artix%20Linux-blue?logo=Artix+Linux)

A simple installer for Artix Linux. Supports currently only runit in UEFI mode.

## Usage

Login to your live artix iso with artix:artix

`curl -LO chauvi.at/anis.tar`

`tar -xvf anis.tar`

`chmod +x ./install.sh`

`sudo su`

`./install.sh`

### Preinstallation

* ISO downloads can be found at [artixlinux.org](https://artixlinux.org/download.php)
* ISO files can be burned to drives with `dd` or something like Etcher.
* `sudo dd bs=4M if=/path/to/artix.iso of=/dev/sd[drive letter] status=progress`
* A better method these days is to use [Ventoy](https://www.ventoy.net/en/index.html).

### TODO

* reimplement btrfs support (done)
* reimplement encrypted volume
* reimplement openrc & dinit support
* add BIOS support

### (((PLANNED)))

* adding snapshot/autosnapshots for btrfs, but for that i have to learn more about btrfs myself since i only ever used ext4
