# vim:  set ft=kickstart
# file: snippets/storage/luks-btrfs-single-grub.ks

# partitioning
ignoredisk --only-use=${KS_INSTALL_DISK}
clearpart  --all --initlabel --drives=${KS_INSTALL_DISK}

# partitioning schmeme
part /boot/efi  --asprimary --ondisk=${KS_INSTALL_DISK} --fstype=efi   --size=2048   --label=efi  --fsoptions="umask=0077,shortname=winnt"
part /boot      --asprimary --ondisk=${KS_INSTALL_DISK} --fstype=ext4  --size=2048   --label=boot --fsoptions="noatime,nodev,nosuid"
part pv.01      --asprimary --ondisk=${KS_INSTALL_DISK} --fstype=lvmpv --size=1 --grow            --encrypted --passphrase=${KS_LUKS_PW}

volgroup system pv.01

logvol btrfs.01 --name=root --size=20000

# btrfs volumes
btrfs none --label=rootfs --data=single --metadata=single --mkfsoptions "--nodiscard --compress zstd:3" btrfs.01

# btrfs subvolumes
btrfs /                    --subvol --name=@            rootfs
btrfs /home                --subvol --name=@home        rootfs
btrfs /opt                 --subvol --name=@opt         rootfs
btrfs /srv                 --subvol --name=@srv         rootfs
btrfs /var                 --subvol --name=@var         rootfs
btrfs /var/log             --subvol --name=@log         rootfs
btrfs /var/log/audit       --subvol --name=@audit       rootfs
btrfs /var/spool/mail      --subvol --name=@mail        rootfs
btrfs /var/tmp             --subvol --name=@tmp         rootfs
btrfs /var/www             --subvol --name=@www         rootfs
