# vim:  set ft=kickstart
# file: snippets/storage/btrfs-single-grub.ks

# partitioning
ignoredisk --only-use=${KS_INSTALL_DISK}
clearpart  --all --initlabel --drives=${KS_INSTALL_DISK}

# partitioning schmeme
part /boot/efi --asprimary --ondisk=${KS_INSTALL_DISK} --fstype=efi   --size=2048   --label=efi  --fsoptions="umask=0077,shortname=winnt"
part /boot     --asprimary --ondisk=${KS_INSTALL_DISK} --fstype=ext4  --size=2048   --label=boot --fsoptions="noatime,nodev,noexec,nosuid"
part btrfs.01  --asprimary --ondisk=${KS_INSTALL_DISK} --fstype=btrfs --size=1 --grow            --fsoptions="compress=zstd:3,noatime,space_cache=v2"

# btrfs volumes
btrfs none --label=rootfs --data=single --metadata=single btrfs.01

# btrfs subvolumes
btrfs /                    --subvol --name=@            LABEL=rootfs
btrfs /home                --subvol --name=@home        LABEL=rootfs
btrfs /opt                 --subvol --name=@opt         LABEL=rootfs
btrfs /srv                 --subvol --name=@srv         LABEL=rootfs
btrfs /var                 --subvol --name=@var         LABEL=rootfs
btrfs /var/lib/containers  --subvol --name=@containers  LABEL=rootfs
btrfs /var/log             --subvol --name=@log         LABEL=rootfs
btrfs /var/log/audit       --subvol --name=@audit       LABEL=rootfs
btrfs /var/spool/mail      --subvol --name=@mail        LABEL=rootfs
btrfs /var/tmp             --subvol --name=@tmp         LABEL=rootfs
btrfs /var/www             --subvol --name=@www         LABEL=rootfs
