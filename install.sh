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
# shellcheck disable=SC1091
. /etc/vconsole.conf
MY_KEYMAP="$KEYMAP"

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
    
    printf "Which Disk do you want to install Artix on? (eg. /dev/sda): " && read -r MY_DISK
    
    if [ -b "$MY_DISK" ]; then
        break
    else
        printf "Error: %s is not an option." "$MY_DISK"
    fi
done

# Choose filesystem
until [ "$MY_FS" = "1" ] || [ "$MY_FS" = "2" ]; do
	printf "Choose filesystem\n(1) btrfs\n(2) ext4\ndefault (1): " && read -r MY_FS
	[ ! "$MY_FS" ] && MY_FS="1"
done
[ "$MY_FS" = "1" ] && MY_FS="btrfs"
[ "$MY_FS" = "2" ] && MY_FS="ext4"

# Wipe drive warning
until [ "$CONFIRM" ]; do
	printf "WARNING: ALL DATA ON %s WILL BE WIPED! Continue? (y/N): " "$MY_DISK" && read -r CONFIRM
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

MY_ROOT=$PART2

# Swap size (same as RAM size for hibernation)
SWAP_SIZE=$(free -m | awk '/^Mem:/ {print int($2/1024 + 0.5)}')
[ "$SWAP_SIZE" -eq 0 ] && SWAP_SIZE=1

# TODO
# ENCRYPTED="n"

# Host
until [ "$MY_HOSTNAME" ]; do
	printf "\nHostname: " && read -r MY_HOSTNAME
done

# Users
printf "\nUsername: " && read -r USERNAME
while ! echo "$USERNAME" | grep -q "^[a-z_][a-z0-9_-]*$"; do
	printf "Username not valid. Give a username beginning with a letter, with only lowercase letters, - or _.\n"
	printf "\nUsername: " && read -r USERNAME
done
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

# Install
sudo MY_INIT="$MY_INIT" MY_DISK="$MY_DISK" PART1="$PART1" PART2="$PART2" \
	SWAP_SIZE="$SWAP_SIZE" MY_FS="$MY_FS" ENCRYPTED="$ENCRYPTED" MY_ROOT="$MY_ROOT" \
	CRYPTPASS="$CRYPTPASS" \
	./src/installer.sh

# Chroot
sudo cp src/iamchroot.sh /mnt/root/ &&
	sudo MY_INIT="$MY_INIT" PART2="$PART2" MY_FS="$MY_FS" ENCRYPTED="$ENCRYPTED" \
		REGION_CITY="$REGION_CITY" MY_HOSTNAME="$MY_HOSTNAME" CRYPTPASS="$CRYPTPASS" \
		ROOT_PASSWORD="$ROOT_PASSWORD" LANGCODE="$LANGCODE" MY_KEYMAP="$MY_KEYMAP" \
		USERNAME="$USERNAME" USER_PASSWORD="$USER_PASSWORD" \
		artix-chroot /mnt sh -ec './root/iamchroot.sh; rm /root/iamchroot.sh; exit' &&
	printf '\nYou may now poweroff.\n'