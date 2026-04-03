# vim:  set ft=kickstart
# file: profiles/fedora/kvm-intel-btrfs-grub.ks

# bootloader
%include snippets/bootloader/grub-intel.ks

# common kickstart directives
%include snippets/common.ks
%include snippets/post/dnf/dnf.ks
%include snippets/post/dnf/dnf5-automatic.ks
%include snippets/post/hardening.ks
%include snippets/post/kvm/headless.ks
%include snippets/post/systemd/disable-sleep.ks
%include snippets/post/tpm/cryptenroll.ks

# packages and groups to install/exclude
%include snippets/packages/fedora-base.ks
%include snippets/packages/fedora-metal.ks
%include snippets/packages/fedora-tpm.ks
