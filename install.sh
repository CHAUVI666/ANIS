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

print_hello() {
	printf "\
************************************************************\n\
*                                                          *\n\
*          ANIS: Artix's Next Installation Script!         *\n\
*                                                          *\n\
* This neat little Script will guide you trough the basic  *\n\
* installation process of Artix.                           *\n\
* If somethings not working for you as expected, feel free *\n\
* to open an issue on the projects page.                   *\n\
* https://github.com/CHAUVI666/ANIS                        *\n\
*                                                          *\n\
* Press <Enter> to start :)                                *\n\
*                                                          *\n\
************************************************************\n\n"
	read -r TEMP
}

print_overview() {
	printf "[ SYSTEM ]\n"
	printf "%-15s%15s\t\t%-15s%15s\n" "Boot" $BOOTMODE "Init" "$MY_INIT"
	printf "%-15s%15s\t\t%-15s%15s\n" "Drive" "$MY_DISK" "File System" "$MY_FS"
	printf "%-15s%15s\t\t%-15s%15s\n" "Swapfile" "Yes" "Swap Size" "$SWAP_SIZE"
	printf "%-15s%15s\n" "Encrypted" "$ENCRYPTED"
}

clear

# Check boot mode
BOOTMODE="UEFI"
[ ! -d /sys/firmware/efi ] && BOOTMODE="BIOS"

# Check init system
MY_INIT="$(cat /etc/os-release | grep "VARIANT")"
MY_INIT="${MY_INIT#*-}"

MY_INIT="runit"
[ "$MY_INIT" = "runit" ] && ln -s /etc/runit/sv/ntpd /run/runit/service/
[ "$MY_INIT" = "openrc" ] && rc-service ntpd start
[ "$MY_INIT" = "dinit" ] && dinitctl start ntpd
[ "$MY_INIT" = "s6" ] && s6-rc -u change ntpd

# Language
LANGCODE="${LANG%%.*}"

# Keymap
# shellcheck disable=SC1091
. /etc/vconsole.conf
MY_KEYMAP="$KEYMAP"

# Timezone
LT_PATH=$(realpath /etc/localtime)
REGION_CITY="${LT_PATH#*zoneinfo/}"

# Hello
print_hello

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

PART1="$MY_DISK"1
PART2="$MY_DISK"2
case "$MY_DISK" in
*"nvme"* | *"mmcblk"*)
	PART1="$MY_DISK"p1
	PART2="$MY_DISK"p2
	;;
esac

# Wipe drive warning
until [ "$CONFIRM" ]; do
	printf "WARNING: ALL DATA ON %s WILL BE WIPED! Continue? (y/N): " "$MY_DISK" && read -r CONFIRM
	[ ! "$CONFIRM" ] && CONFIRM="n"
done

[ ! "$CONFIRM" = "y" ] && printf "Installation aborted by user. Nothing was changed.\n" && exit 1

# Choose filesystem
until [ "$MY_FS" = "1" ] || [ "$MY_FS" = "2" ]; do
	printf "\nChoose filesystem\n(1) btrfs\n(2) ext4\ndefault (1): " && read -r MY_FS
	[ ! "$MY_FS" ] && MY_FS="1"
done
[ "$MY_FS" = "1" ] && MY_FS="btrfs"
[ "$MY_FS" = "2" ] && MY_FS="ext4"

# Encrypt or not
until [ "$ENCRYPTED" ]; do
	printf "Encrypt? (y/N): " && read -r ENCRYPTED
	[ ! "$ENCRYPTED" ] && ENCRYPTED="n"
done

if [ "$ENCRYPTED" = "y" ]; then
	MY_ROOT="/dev/mapper/root"
	CRYPTPASS=$(confirm_password "encryption password")
else
	MY_ROOT=$PART2
	ENCRYPTED="n"
	# ??? what was the intention behind that
	# [ "$MY_FS" = "ext4" ] && MY_ROOT=$PART2
fi

# Swap size (same as RAM size for hibernation)
SWAP_SIZE=$(free -m | awk '/^Mem:/ {print int($2/1024 + 0.5)}')
[ "$SWAP_SIZE" -lt 4 ] && SWAP_SIZE=4

# Host
until [ "$MY_HOSTNAME" ]; do
	printf "\nHostname: " && read -r MY_HOSTNAME
done

# Users
printf "Username: " && read -r USERNAME

# Thanks to LARBS.xyz
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

clear

printf "\nDone with configuration.\n\n"
print_overview
printf "\nPress <Enter> to begin with the installation, or <Ctrl+C> to abort it.\n\n"

# shellcheck disable=SC2034
read -r TEMP

# Install
sudo MY_INIT="$MY_INIT" MY_DISK="$MY_DISK" PART1="$PART1" PART2="$PART2" \
	SWAP_SIZE="$SWAP_SIZE" MY_FS="$MY_FS" ENCRYPTED="$ENCRYPTED" MY_ROOT="$MY_ROOT" \
	CRYPTPASS="$CRYPTPASS" BOOTMODE="$BOOTMODE" \
	./src/installer.sh

# Chroot
sudo cp src/iamchroot.sh /mnt/root/ &&
	sudo MY_INIT="$MY_INIT" PART2="$PART2" MY_FS="$MY_FS" ENCRYPTED="$ENCRYPTED" \
		REGION_CITY="$REGION_CITY" MY_HOSTNAME="$MY_HOSTNAME" CRYPTPASS="$CRYPTPASS" \
		ROOT_PASSWORD="$ROOT_PASSWORD" LANGCODE="$LANGCODE" MY_KEYMAP="$MY_KEYMAP" \
		USERNAME="$USERNAME" USER_PASSWORD="$USER_PASSWORD" MY_ROOT="$MY_ROOT" \
		BOOTMODE="$BOOTMODE" MY_DISK="$MY_DISK" \
		artix-chroot /mnt sh -ec './root/iamchroot.sh; rm /root/iamchroot.sh; exit' &&
	printf '\nYou may now poweroff.\n'