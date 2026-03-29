# vim:  set ft=kickstart
# file: snippets/bootloader/grub-intel.ks
#
# Intel kvm-host boot configuration.
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
# - efi=disable_early_pci_dma
# - intel_iommu=on
# - iommu=force
# - iommu.strict=1

bootloader --driveorder=${KS_INSTALL_DISK} --append="${KS_KERNEL_CMDLINE_CPU_INTEL} ${KS_KERNEL_CMDLINE_BASE} ${KS_KERNEL_CMDLINE_METAL}" --password ${KS_GRUB_PW}
