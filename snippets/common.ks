# vim:  set ft=kickstart
# file: snippets/common.ks

# installation in text mode
text
# Agree to EULA when prompted (ignored when not prompted)
eula --agreed
# Firewalld enabled, allow ssh
firewall --enabled --service=ssh
# disable initial setup
firstboot --disable
# keyboard layout German
keyboard --vckeymap=de --xlayouts=de
# system language en_US.UTF-8 with support for de_DE.UTF-8
lang en_US.UTF-8 --addsupport=de_DE.UTF-8
# reboot and eject install media
reboot --eject
# root password (disabled, set to be locked)
rootpw ${KS_ROOT_PW}
# SELinux in enforcing mode
selinux  --enforcing
# Enabled services
services --enabled=auditd,firewalld,sshd
# disable root password login via SSH during installation
sshpw  --username=root --lock Locked,0+815 --plaintext
# timezone Berlin, Germany (UTC+1 standard time)
timezone Europe/Berlin --utc
# kdump disabled
%addon com_redhat_kdump --disable
%end
