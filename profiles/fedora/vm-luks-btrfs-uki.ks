# vim:  set ft=kickstart
# file: profiles/fedora/vm-luks-btrfs-uki-direct.ks

# bootloader
bootloader --append="console=ttyS0" --nombr --location=none --disabled

# common kickstart directives
%include snippets/common.ks
%include snippets/post/boot/vm-uki.ks
%include snippets/post/dnf/dnf.ks
%include snippets/post/dnf/dnf5-automatic.ks
%include snippets/post/hardening.ks
%include snippets/post/tpm/cryptenroll.ks
%include snippets/post/systemd/disable-sleep.ks

# storage configuration
%include snippets/storage/luks-btrfs-uki.ks

# packages and groups to install/exclude
%include snippets/packages/fedora-base.ks
%include snippets/packages/fedora-tpm.ks
%include snippets/packages/fedora-vm.ks
%include snippets/packages/fedora-vm-uki.ks
