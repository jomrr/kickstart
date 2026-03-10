# vim:  set ft=kickstart
# file: profiles/fedora/vm-luks-btrfs-grub.ks

# bootloader
%include snippets/bootloader/grub-vm.ks

# common kickstart directives
%include snippets/common.ks
%include snippets/post/dnf/dnf.ks
%include snippets/post/dnf/dnf5-automatic.ks
%include snippets/post/hardening.ks
%include snippets/post/tpm/cryptenroll.ks

# storage configuration
%include snippets/storage/luks-btrfs-grub.ks

# packages and groups to install/exclude
%include snippets/packages/fedora-base.ks
%include snippets/packages/fedora-tpm.ks
%include snippets/packages/fedora-vm.ks
