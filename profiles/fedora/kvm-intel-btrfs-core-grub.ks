# vim:  set ft=kickstart
# file: profiles/fedora/kvm-intel-btrfs-core-grub.ks

# common kickstart directices
%include snippets/common.ks
# kvm specific post installation steps
%include snippets/kvm/headless.ks

# packages and groups to install/exclude
%packages --exclude-weakdeps --excludedocs --ignoremissing --inst-langs de_DE,en_US
%include snippets/packages/fedora-minimal.ks
%end
