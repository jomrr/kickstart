# vim:  set ft=kickstart
# file: snippets/packages/fedora-vm-uki.ks

%packages --exclude-weakdeps --excludedocs --ignoremissing --inst-langs de_DE,en_US
binutils
-dracut-config-rescue
dracut-config-generic
efibootmgr
-grub2-efi-x64-modules
-grub2-tools-extra
-grubby
-kernel
-kernel-core
kernel-uki-virt
-kernel-modules
kernel-modules-core
-linux-firmware
openssl
python3-virt-firmware
sbsigntools
systemd-ukify
# no uki-direct, we use custom cmdline and need own post install hook
-uki-direct
%end
