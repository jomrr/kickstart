# vim:  set ft=kickstart
# file: profiles/fedora/vm-pgsql.ks

# bootloader
%include snippets/bootloader/grub-vm.ks

# common kickstart directives
%include snippets/common.ks
%include snippets/post/dnf/dnf.ks
%include snippets/post/dnf/dnf5-automatic.ks
%include snippets/post/hardening.ks
%include snippets/post/systemd/disable-sleep.ks

# packages and groups to install/exclude
%include snippets/packages/fedora-base.ks
%include snippets/packages/fedora-tpm.ks
%include snippets/packages/fedora-vm.ks

# partitioning
ignoredisk --only-use=vda,vdb
clearpart  --all --initlabel --drives=vda,vdb

# partitioning schmeme
part /boot/efi --asprimary --ondisk=vda --fstype=efi   --size=2048   --label=efi  --fsoptions="umask=0077,shortname=winnt"
part /boot     --asprimary --ondisk=vda --fstype=ext4  --size=2048   --label=boot --fsoptions="noatime,nodev,noexec,nosuid"
part btrfs.01  --asprimary --ondisk=vda --fstype=btrfs --size=1 --grow            --fsoptions="compress=zstd:3,noatime,space_cache=v2"
part /var/lib  --asprimary --ondisk=vdb --fstype=ext4  --size=1 --grow            --fsoptions="noatime,nodev,noexec,nosuid"
# btrfs volumes
btrfs none --label=rootfs --data=single --metadata=single btrfs.01

# btrfs subvolumes
btrfs /                    --subvol --name=@            LABEL=rootfs
btrfs /home                --subvol --name=@home        LABEL=rootfs
btrfs /opt                 --subvol --name=@opt         LABEL=rootfs
btrfs /srv                 --subvol --name=@srv         LABEL=rootfs
btrfs /var                 --subvol --name=@var         LABEL=rootfs
btrfs /var/log             --subvol --name=@log         LABEL=rootfs
btrfs /var/log/audit       --subvol --name=@audit       LABEL=rootfs
btrfs /var/spool/mail      --subvol --name=@mail        LABEL=rootfs
btrfs /var/tmp             --subvol --name=@tmp         LABEL=rootfs
btrfs /var/www             --subvol --name=@www         LABEL=rootfs
