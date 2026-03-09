# vim:  set ft=kickstart
# file: snippets/bootloader/grub-vm.ks

bootloader --driveorder=${KS_INSTALL_DISK} --append="${KS_KERNEL_CMDLINE_BASE}"  --password ${KS_GRUB_PASSWORD_HASH}
