#!/bin/sh
set -e

script=`readlink -f "$0"`
scriptname=`basename "$script"`
scriptpath=`dirname "$script"`

[ `id -u` -eq 0 ] || { echo "ERROR: Must be run as root."; exit 1; }

mp=/mnt/root
keyslot_size=32m


preparation() {
    echo "Prepare"
    umount /target/boot/efi
    umount /target/boot
    umount /target/cdrom
    umount /target

    mkdir $mp
}

create_subvols() {
    echo "Create subvolumes"
    mount /dev/"$1" $mp
    cd $mp
    [ -z "`ls home 2>&1`" ] || exit 3
    btrfs subvolume snapshot . @
    find -maxdepth 1 \! -name "@*" \! -name . -exec rm -Rf {} \;
    btrfs subvolume create @home
    cd /
    umount $mp
    echo "Mount @ instead of /"
    mount /dev/"$1" -o subvol=@ $mp
}

encrypt() {
    echo "Encrypt $1"
    btrfs filesystem resize -$keyslot_size $mp
    cd /
    umount $mp
    echo 'You may ignore “Warning: keyslot operation could fail …”.'
    echo 'See <https://gitlab.com/cryptsetup/cryptsetup/-/issues/896>.'
    cryptsetup reencrypt --encrypt --type luks2 --reduce-device-size $keyslot_size /dev/"$1"
    cryptsetup open /dev/"$1" root
    mount /dev/mapper/root -o subvol=@ $mp
    btrfs filesystem resize max $mp
}

chroot_and_mkinitramfs() {
    echo "Prepare $mp for chroot"
    mount -t proc proc $mp/proc
    mount -t sysfs sys $mp/sys
    mount --bind /dev $mp/dev
    mount --bind /run $mp/run
    mount /dev/"$2" $mp/boot
    mount /dev/"$3" $mp/boot/efi
    cp "$script" $mp/tmp/"$scriptname"
    chmod a+x $mp/tmp/"$scriptname"
    echo "Chrooting and call the script in the other root"
    chroot $mp /tmp/"$scriptname" //inner $only_subvols /dev/"$1"
}

unmount_everything() {
    echo "Unmounting"
    cd /
    for dir in proc sys dev run boot/efi boot
    do
        umount $mp/$dir
    done
    umount $mp
    if [ $only_subvols = no ]
    then
        cryptsetup close root
    fi
}

if [ "$1" = "//inner" ]
then
    # echo GRUB_DISABLE_OS_PROBER=false >> /etc/default/grub
    only_subvols="$2"
    root_uuid=`blkid --output export "$3" | grep ^UUID=`
    if [ "$only_subvols" = "yes" ]
    then
        echo "Patch /etc/fstab"
        sed --in-place "s!^.* / btrfs defaults 0 1\$!$root_uuid / btrfs defaults,subvol=@ 0 1!" /etc/fstab
        echo "$root_uuid /home btrfs defaults,subvol=@home 0 2" >> /etc/fstab
        update-grub
        echo "Update initramfs"
        update-initramfs -u
    else
        echo "Patch /etc/fstab"
        sed --in-place 's!^.* / btrfs defaults 0 1$!/dev/mapper/root / btrfs defaults,subvol=@ 0 1!' /etc/fstab
        echo "/dev/mapper/root /home btrfs defaults,subvol=@home 0 2" >> /etc/fstab
        echo "root $root_uuid none luks,discard" > /etc/crypttab
        # grub-install /dev/sda
        update-grub
        echo "Update initramfs"
        apt-get install -y cryptsetup-initramfs
    fi
    exit
fi

if [ "$1" = "--only-subvols" ]
then
   only_subvols=yes
   shift
else
    only_subvols=no
fi

if [ -z "$1" -o -z "$2" -o -z "$3" ]
then
    echo "You must pass the device of the root, boot, and EFI partition (without the /dev/) to this script."
    exit 2
fi

preparation
create_subvols "$1"
if [ $only_subvols = no ]
then
    encrypt "$1"
fi
chroot_and_mkinitramfs "$1" "$2" "$3"
unmount_everything
echo "Finished"
