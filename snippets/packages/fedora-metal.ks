# vim:  set ft=kickstart
# file: snippets/packages/fedora-metal.ks

%packages --exclude-weakdeps --excludedocs --ignoremissing --inst-langs de_DE,en_US
fwupd
linux-firmware
microcode_ctl
nvme-cli
smartmontools
%end
