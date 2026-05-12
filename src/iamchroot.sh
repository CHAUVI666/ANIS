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

#needed for grub
RESUME_UUID=$(blkid -s UUID -o value "$PART2")
RESUME_OFFSET=$(filefrag -v /mnt/swap/swapfile | awk '{if($1=="0:"){print $4}}' | tr -d '.')

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
printf '\n127.0.0.1 localhost\n::1 localhost' >> /etc/hosts
printf '\n127.0.1.1 %s.localdomain %s' "$MY_HOSTNAME" "$MY_HOSTNAME" >> /etc/hosts

# Install boot loader
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --recheck
grub-install --target=x86_64-efi --efi-directory=/boot/efi --removable --recheck

# vibecode
sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"|GRUB_CMDLINE_LINUX_DEFAULT=\"\1 resume=UUID=$RESUME_UUID resume_offset=$RESUME_OFFSET\"|" /etc/default/grub

grub-mkconfig -o /boot/grub/grub.cfg

# Root user
printf "%s:%s\n" "root" "$ROOT_PASSWORD" | chpasswd

# Default User
useradd -mG wheel "$USERNAME"
printf "%s:%s\n" "$USERNAME" "$USER_PASSWORD" | chpasswd
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# enable services
ln -s /etc/runit/sv/NetworkManager /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/bluetoothd /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/cupsd /etc/runit/runsvdir/default/

# Configure mkinitcpio
[ "$MY_FS" = "btrfs" ] && sed -i 's/BINARIES=()/BINARIES=(\/usr\/bin\/btrfs)/g' /etc/mkinitcpio.conf
sed -i 's/^HOOKS.*$/HOOKS=(base udev autodetect keyboard keymap modconf block resume filesystems fsck)/g' /etc/mkinitcpio.conf

mkinitcpio -P