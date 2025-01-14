btrfs-encrypt-root
==================

Since Ubuntu 23.04, it cannot be installed anymore on an encrypted Btrfs.
Moreover, no @ and @home subvolumes are created automatically during
installation.  Canonical deserted all users who had found a comfortable home in
the Btrfs ecosystem.  Besides, Canonical actively removed the functionality,
even in expert mode of the installer.

Be that as it may, this script brings it back.  You it call as root immediately
after the installation of Ubuntu, from a live system.  You can copy the script
on the USB stick with the live system, or download it with ``wget`` from this
repository::

  wget https://gitlab.com/bronger/btrfs-encrypt-root/-/raw/master/btrfs-encrypt-root.sh
  sudo sh btrfs-encrypt-root.sh sda3 sda2 sda1


**Caution**: Use the script only if you trust the script, either because you
can analyse it yourself, or because you trust someone who can.

It works only in an EFI environment.  It assumes that you want to have ``/``
and ``/home`` on the same partition, and that there is a separate partition for
``/boot``.  Then, the three parameters are:

- the device name for ``/``
- the device name for ``/boot``
- the device name for ``/boot/efi``

All three without the ``/dev/`` prefix.

The script then encrypts the root partition and creates the subvolumes ``@``
for ``/`` and ``@home`` for ``/home``.  If you pass ``--only-subvols`` as the
first parameter, no encryption happens but only the subvolumes are created.

If you pass the ``--enlarge`` parameter, the root partition is enlarged to the
complete available space after it after the encryption.  This makes encryption
much faster, because you make a small partition for just the installation of
the base system, and then you call this script, which has to encrypt only the
smaller partition.  The enlargement covers only empty space, so no encryption
is necessary there.
