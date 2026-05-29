# ANIS - Artix' Next Installation Script

![](https://img.shields.io/badge/OS-Artix%20Linux-blue?logo=Artix+Linux)

A simple installer for Artix Linux. Forked from [/Zaechus/artix-installer](https://github.com/Zaechus/artix-installer) with the goal to deliver a modern, """fully-fledged""" base installation. 

> **Important:** In its current state, this script is **NOT** stable. Everything that could break will break, eventually.

As long as there is no release tab available the main branch will continue to be used for non tested function implementations... well, even IF there's a release available, I'm only able to confirm that it works on my machine™.

Primarily I started that fork to force myself to learning shell scripting (and maybe some C in the future) as well as to dive deeper into everything GNU/Linux has to offer.

## Features

### Upstream Features

- Basic support for Dinit and OpenRC
- Standard Ext4 and Btrfs partitioning
- LUKS2 disk encryption

### Added Features

- Auto-fetch keyboard, locale, and timezone settings straight from the live ISO (since you already chose them at boot anyway)
- Automatic swapfile sizing to match your RAM for hibernation purposes
- Completely reworked Btrfs subvolumes to follow modern layout standards
- Legacy BIOS boot support, so it doesn't just rely on UEFI
- Added Runit and S6 support (meaning every official Artix init system is now covered)

### Planned Features

- A menu option to manually override any auto-detected values
- LVM support
- An option to choose different kernels
- More readable terminal outputs during the install process
- Automated installation mode via a dedicated configuration file
- A final "Are you sure?" confirmation prompt before any actual wiping or installing begins
- GRUB os-prober integration to make dual-booting easier
- Support for alternative bootloaders besides GRUB
- An optional post-install script
- Support to add multiple users
- Automated Btrfs snapshot configuration (Snapper/Timeshift setup)
- ZRAM support
- Partition resizing capabilities for dual-boot setups
- Support to make hibernation reliable work completely out of the box
- Fancy TUI with whiptail

## Usage

Login to your live artix iso with root:artix

> If you're on s6, switch to tty2 first (Ctrl+Alt+F2), since tty1 will be flooded with s6 logs by default.

```
$ curl -OL https://github.com/CHAUVI666/ANIS/archive/v0.1.0.tar.gz

$ tar -xvf v0.1.0.tar.gz

$ cd ANIS

$ sh install.sh
```

### Preinstallation

* ISO downloads can be found at [artixlinux.org](https://artixlinux.org/download.php)
* ISO files can be burned to drives with `dd` or something like Etcher.
* `sudo dd bs=4M if=/path/to/artix.iso of=/dev/sd[drive letter] status=progress`
* A better method these days is to use [Ventoy](https://www.ventoy.net/en/index.html).