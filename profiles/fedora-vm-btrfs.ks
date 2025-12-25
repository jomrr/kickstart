# vim:  set ft=kickstart
# file: profiles/fedora-vm-btrfs.cfg.in
# type: CLASS profile template

bootloader --driveorder=vda --location=mbr --append="debugfs=off efi=disable_early_pci_dma init_on_alloc=1 init_on_free=1 iommu.strict=1 kexec_load_disabled=1 lockdown=confidentiality module.sig_enforce=1 page_alloc.shuffle=1 pti=on randomize_kstack_offset=on slab_nomerge spec_store_bypass_disable=on vsyscall=none"
clearpart --drives=vda --all
zerombr

%include ../snippets/common-base.ks
%include ../snippets/common-users.ks
%include ../snippets/fedora-mirrors.ks

