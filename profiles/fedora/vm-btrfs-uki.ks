# vim:  set ft=kickstart
# file: profiles/fedora/vm-btrfs-uki-direct.ks

# bootloader
bootloader --append="console=ttyS0" --nombr --location=none

# common kickstart directives
%include snippets/common.ks
%include snippets/post/boot/vm-uki.ks
#%include snippets/post/dnf/dnf.ks
#%include snippets/post/dnf/dnf5-automatic.ks
#%include snippets/post/hardening/disable-coredumps.ks
#%include snippets/post/hardening/modprobe-blacklist-drivers.ks
#%include snippets/post/hardening/modprobe-blacklist-fs.ks
#%include snippets/post/hardening/modprobe-blacklist-net.ks

# storage configuration
%include snippets/storage/btrfs-uki.ks

# packages and groups to install/exclude
%include snippets/packages/fedora-base.ks
%include snippets/packages/fedora-vm.ks
%include snippets/packages/fedora-vm-uki.ks
