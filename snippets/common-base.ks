# vim:  set ft=kickstart
# file: snippets/common-base.ks
# desc: common base kickstart snippet

# installation in text mode
text
# disable initial setup
firstboot --disable
# Agree to EULA when prompted (ignored when not prompted)
eula --agreed
# system language en_US.UTF-8 with support for de_DE.UTF-8
lang en_US.UTF-8 --addsupport=de_DE.UTF-8
# keyboard layout German
keyboard --vckeymap=de --xlayouts=de
# timezone Berlin, Germany (UTC+1 standard time)
timezone Europe/Berlin --utc
# time synchronization with NTP
timesource --ntp-server=fritz.box
# kdump disabled
%addon com_redhat_kdump --disable
%end
# SELinux in enforcing mode
selinux --enforcing
