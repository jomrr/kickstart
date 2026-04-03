# vim:  set ft=kickstart
# file: snippets/post/systemd/disable-sleep.ks

%post --interpreter /usr/bin/bash --log=/root/ks-post-systemd-disable-sleep.log
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
%end
