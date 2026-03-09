# vim:  set ft=kickstart
# file: snippets/bootloader/grub-amd.ks
#
# AMD kvm-host boot configuration.
#
# Kernel hardening:
# - debugfs=off
# - init_on_alloc=1
# - init_on_free=1
# - kexec_load_disabled=1
# - lockdown=confidentiality
# - module.sig_enforce=1
# - page_alloc.shuffle=1
# - pti=on
# - randomize_kstack_offset=on
# - slab_nomerge
# - spec_store_bypass_disable=on
# - vsyscall=none
#
# DMA / IOMMU hardening:
# - amd_iommu=force_isolation
# - efi=disable_early_pci_dma
# - iommu=force
# - iommu.strict=1

bootloader --driveorder=sda --append="${KS_KERNEL_CMDLINE_CPU_AMD} ${KS_KERNEL_CMDLINE_BASE} ${KS_KERNEL_CMDLINE_METAL}"  --password ${KS_GRUB_PASSWORD_HASH} --iscrypted
