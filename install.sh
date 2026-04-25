#!/bin/bash -e
#
# ANIS - Artix Neat Installation Script
# 
# A fork of artix-installer created by
# Maxwell Anderson
# to be used with the runit init system
#
# Copyright (c) 2026 CHAUVI 
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

confirm_password() {
	stty -echo
	until [ "$pass1" = "$pass2" ] && [ "$pass2" ]; do
		printf "%s: " "$1" >&2 && read -r pass1 && printf "\n" >&2
		printf "confirm %s: " "$1" >&2 && read -r pass2 && printf "\n" >&2
	done
	stty echo
	echo "$pass2"
}

# Check boot mode
[ ! -d /sys/firmware/efi ] && printf "Not booted in UEFI mode. Aborting...\n" && exit 1

# Check init system
[ ! -d /etc/runit ] && printf "wrong init, this script is ONLY for RUNIT!\n" && exit 1

# Language
LANGCODE="${LANG%%.*}"

# Keymap
if [ -f /etc/vconsole.conf ]; then
    source /etc/vconsole.conf
    MY_KEYMAP="$KEYMAP"
fi

# Timezone
LT_PATH=$(realpath /etc/localtime)
REGION_CITY="${LT_PATH#*zoneinfo/}"

# TODO
# Init system (for later use... if I'm really going for ALL systems)
MY_INIT="runit"

# Choose disk
until [ -b "$MY_DISK" ]; do
    printf "\nAviable Disks:\n"
    lsblk -dno NAME,SIZE,MODEL -e 7 | awk '{print "/dev/"$1 " - " $2 " (" $3 " " $4 ") "}'
    
    read -p "Which Disk do you want to install Artix on? (eg. /dev/sda): " MY_DISK
    
    if [[ -b "$MY_DISK" ]]; then
        break
    else
        printf "Error: '$MY_DISK' is not an option."
    fi
done

# Wipe drive warning
until [ "$CONFIRM" ]; do
	printf "WARNING: ALL DATA ON $MY_DISK WILL BE WIPED! Continue? (y/N): " && read -r CONFIRM
	[ ! "$CONFIRM" ] && CONFIRM="n"
done

[ ! "$CONFIRM" = "y" ] && printf "Installation aborted by user. Nothing was changed.\n" && exit 1

PART1="$MY_DISK"1
PART2="$MY_DISK"2
case "$MY_DISK" in
*"nvme"* | *"mmcblk"*)
	PART1="$MY_DISK"p1
	PART2="$MY_DISK"p2
	;;
esac

# Swap size (same as RAM size for hibernation)
SWAP_SIZE=$(free -m | awk '/^Mem:/ {print int($2/1024 + 0.5)}')
[ "$SWAP_SIZE" -eq 0 ] && SWAP_SIZE=1

# TODO
# MY_FS="ext4"

# TODO
# ENCRYPTED="n"

MY_ROOT=$PART2

# Host
until [ "$MY_HOSTNAME" ]; do
	printf "\nHostname: " && read -r MY_HOSTNAME
done

# Users
printf "Username: " && read -r USERNAME
USER_PASSWORD=$(confirm_password "$USERNAME password")

until [ "$SAME_PASS" ]; do
	printf "Use same password for root? (y/N): " && read -r SAME_PASS
	[ ! "$SAME_PASS" ] && SAME_PASS="n"
done

if [ "$SAME_PASS" = "y" ]; then
	ROOT_PASSWORD=$USER_PASSWORD
else
	ROOT_PASSWORD=$(confirm_password "Root password")
fi

printf "\nDone with configuration. Installing...\n\n"

# Partition disk
wipefs -a "$MY_DISK"
printf "label: gpt\n,200M,U\n,,\n" | sfdisk "$MY_DISK"
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

# Install base system and kernel
basestrap /mnt $pkgs

fstabgen -U /mnt >/mnt/etc/fstab

#needed for grub
RESUME_UUID=$(blkid -s UUID -o value "$PART2")
RESUME_OFFSET=$(filefrag -v /mnt/swap/swapfile | awk '{if($1=="0:"){print $4}}' | tr -d '.')

# Chroot
artix-chroot /mnt /bin/sh -e <<EOF
    # Boring stuff you should probably do
    ln -sf /usr/share/zoneinfo/"$REGION_CITY" /etc/localtime
    hwclock --systohc

    # Localization
    printf "%s.UTF-8 UTF-8\n" "$LANGCODE" >>/etc/locale.gen
    locale-gen
    printf "LANG=%s.UTF-8\n" "$LANGCODE" >/etc/locale.conf
    printf "KEYMAP=%s\n" "$MY_KEYMAP" >/etc/vconsole.conf

    # Host stuff
    printf '%s\n' "$MY_HOSTNAME" >/etc/hostname
    printf '\n127.0.0.1 localhost' >> /etc/hosts
    printf '\n::1 localhost' >> /etc/hosts
    printf '\n127.0.1.1 %s.localdomain %s' "$MY_HOSTNAME" "$MY_HOSTNAME" >> /etc/hosts

    # Install boot loader
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --recheck
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --removable --recheck
    
    # vibecoded
    sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"|GRUB_CMDLINE_LINUX_DEFAULT=\"\1 resume=UUID=$RESUME_UUID resume_offset=$RESUME_OFFSET\"|" /etc/default/grub

    grub-mkconfig -o /boot/grub/grub.cfg

    # Root user
    echo "root:$ROOT_PASSWORD" | chpasswd

    # Default User
    useradd -mG wheel $USERNAME
    echo "$USERNAME:$USER_PASSWORD" | chpasswd
    sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

    # enable services
    ln -s /etc/runit/sv/NetworkManager /etc/runit/runsvdir/default/
    ln -s /etc/runit/sv/bluetoothd /etc/runit/runsvdir/default/
    ln -s /etc/runit/sv/cupsd /etc/runit/runsvdir/default/

    # Configure mkinitcpio
    sed -i 's/^HOOKS.*$/HOOKS=(base udev autodetect keyboard keymap modconf block resume filesystems fsck)/g' /etc/mkinitcpio.conf

    mkinitcpio -P
EOF

printf '\nInstallation finished. You may now poweroff.\n'