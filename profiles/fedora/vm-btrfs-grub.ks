# vim:  set ft=kickstart
# file: profiles/fedora/vm-btrfs-grub.ks

# bootloader
%include snippets/bootloader/grub-vm.ks

# common kickstart directives
%include snippets/common.ks

# storage configuration
%include snippets/storage/btrfs-grub.ks

# packages and groups to install/exclude
%include snippets/packages/fedora-base.ks
%include snippets/packages/fedora-tpm.ks
%include snippets/packages/fedora-vm.ks
