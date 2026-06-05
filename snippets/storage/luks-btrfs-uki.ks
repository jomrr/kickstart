# vim:  set ft=kickstart
# file: snippets/storage/luks-btrfs-single-uki.ks

# partitioning
ignoredisk --only-use=${KS_INSTALL_DISK}
clearpart  --all --initlabel --drives=${KS_INSTALL_DISK}

# partitioning schmeme
part /boot/efi --ondisk=${KS_INSTALL_DISK} --fstype=efi   --size=8192   --label=efi  --fsoptions="umask=0077,shortname=winnt"
part btrfs.01  --ondisk=${KS_INSTALL_DISK} --fstype=btrfs --size=1 --grow            --fsoptions="compress=zstd:3,noatime,space_cache=v2" --encrypted --luks-version=luks2 --passphrase=${KS_LUKS_PW}

# btrfs volumes
btrfs none --label=system --data=single --metadata=single btrfs.01

# btrfs subvolumes
btrfs /               --subvol --name=@      system
btrfs /home           --subvol --name=@home  system
btrfs /opt            --subvol --name=@opt   system
btrfs /srv            --subvol --name=@srv   system
btrfs /var            --subvol --name=@var   system
btrfs /var/log        --subvol --name=@log   system
btrfs /var/log/audit  --subvol --name=@audit system
btrfs /var/spool/mail --subvol --name=@mail  system
btrfs /var/tmp        --subvol --name=@tmp   system
btrfs /var/www        --subvol --name=@www   system
