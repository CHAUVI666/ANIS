#!/bin/sh -e
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
if [ "$ENCRYPTED" = "y" ]; then
	yes "$CRYPTPASS" | cryptsetup -q luksFormat "$PART2"
	yes "$CRYPTPASS" | cryptsetup open "$PART2" root
fi

mkfs.fat -F 32 "$PART1"

if [ "$MY_FS" = "ext4" ]; then
	yes | mkfs.ext4 "$MY_ROOT"
	mount "$MY_ROOT" /mnt

	# Create swapfile
	mkdir /mnt/swap
	fallocate -l "$SWAP_SIZE"G /mnt/swap/swapfile
	chmod 600 /mnt/swap/swapfile
	mkswap /mnt/swap/swapfile
elif [ "$MY_FS" = "btrfs" ]; then
	mkfs.btrfs -f "$MY_ROOT"

	# Create subvolumes
	mount "$MY_ROOT" /mnt
	btrfs subvolume create /mnt/@
	btrfs subvolume create /mnt/@home
	btrfs subvolume create /mnt/@log
	btrfs subvolume create /mnt/@cache
	btrfs subvolume create /mnt/@swap
	umount -R /mnt

	# Mount subvolumes
	mount -t btrfs -o compress=zstd,subvol=@ "$MY_ROOT" /mnt
	mkdir /mnt/home
	mkdir /mnt/swap
	mkdir -p /mnt/var/log
	mkdir /mnt/var/cache

	mount -t btrfs -o compress=zstd,subvol=@home "$MY_ROOT" /mnt/home
	mount -t btrfs -o compress=zstd,subvol=@log "$MY_ROOT" /mnt/var/log
	mount -t btrfs -o compress=zstd,subvol=@cache "$MY_ROOT" /mnt/var/cache
	mount -t btrfs -o noatime,nodatacow,subvol=@swap "$MY_ROOT" /mnt/swap

	# Create swapfile
	btrfs filesystem mkswapfile -s "$SWAP_SIZE"G /mnt/swap/swapfile
fi

swapon /mnt/swap/swapfile

mkdir -p /mnt/boot/efi
mount "$PART1" /mnt/boot/efi

# packages
pkgs="base base-devel $MY_INIT elogind-$MY_INIT efibootmgr grub linux linux-firmware vim networkmanager"
pkgs="$pkgs networkmanager-runit network-manager-applet dosfstools linux-headers bluez bluez-runit bluez-utils cups cups-runit xdg-utils xdg-user-dirs"
[ "$MY_FS" = "btrfs" ] && pkgs="$pkgs btrfs-progs"
[ "$ENCRYPTED" = "y" ] && pkgs="$pkgs cryptsetup cryptsetup-$MY_INIT"

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
basestrap /mnt "$@"
fstabgen -U /mnt >/mnt/etc/fstab