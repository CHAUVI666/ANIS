#!/bin/bash -e
#
# ANIS - Artix Neat Installation Script
#
# A fork of artix-installer to be used with the runit init system.
#
# Copyright (c) 2026 CHAUVI 
# Copyright (c) 2022 Maxwell Anderson
#
# ANIS is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# ANIS is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with ANIS If not, see <https://www.gnu.org/licenses/>.

# Partition disk
wipefs -a "$MY_DISK"
printf "label: gpt\n,550M,U\n,,\n" | sfdisk "$MY_DISK"

# Format and mount partitions
mkfs.fat -F 32 "$PART1"
yes | mkfs.ext4 "$MY_ROOT"
mount "$MY_ROOT" /mnt

# Create swapfile
mkdir /mnt/swap
fallocate -l "$SWAP_SIZE"G /mnt/swap/swapfile
chmod 600 /mnt/swap/swapfile
mkswap /mnt/swap/swapfile
swapon /mnt/swap/swapfile

mkdir -p /mnt/boot/efi
mount "$PART1" /mnt/boot/efi

# packages
pkgs="base base-devel $MY_INIT elogind-$MY_INIT efibootmgr grub linux linux-firmware vim networkmanager"
pkgs="$pkgs networkmanager-runit network-manager-applet dosfstools linux-headers bluez bluez-runit bluez-utils cups cups-runit xdg-utils xdg-user-dirs"

case $(grep vendor /proc/cpuinfo) in
*"Intel"*)
	pkgs="$pkgs intel-ucode"
	;;
*"AMD"*|*"Amd"*)
	pkgs="$pkgs amd-ucode"
	;;
esac

unset --
IFS=" "
for pkg in $pkgs; do
	set -- "$@" "$pkg"
done

# Install base system and kernel
basestrap /mnt $pkgs
fstabgen -U /mnt >/mnt/etc/fstab