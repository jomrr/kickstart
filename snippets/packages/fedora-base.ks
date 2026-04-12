# vim:  set ft=kickstart
# file: snippets/packages/fedora-base.ks

%packages --exclude-weakdeps --excludedocs --ignoremissing --inst-langs de_DE,en_US
@core
auditd
bash-completion
bash-color-prompt
cracklib
cracklib-dicts
firewalld
libpwquality
policycoreutils-python-utils
python3-dnf
python3-libdnf5
python3-pwquality
vim-default-editor
zstd
-ModemManager-*
-abrt*
-avahi*
-bluez*
-brcmfmac-firmware
-cirrus-audio-firmware
-iw*
-mt7xxx-firmware
-nano
-nodejs*
-nvidia-gpu-firmware
-nxpwireless-firmware
-perl*
-rpmfusion-*
-samba*
-setroubleshoot*
-sssd*
-zram-generator-*
%end
