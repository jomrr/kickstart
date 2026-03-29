# vim:  set ft=kickstart
# file: snippets/packages/fedora-vm.ks

%packages --exclude-weakdeps --excludedocs --ignoremissing --inst-langs de_DE,en_US
-linux-firmware
qemu-guest-agent
virt-firmware
%end
