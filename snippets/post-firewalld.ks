# Remove masquerade from all zones and log all denied packets

%post --interpreter /usr/bin/bash --log=/root/ks-post-dnf.log
systemctl restart firewalld

firewall-cmd --get-active-zones | awk 'NR % 2 == 1' | xargs -I{} firewall-cmd --zone={} --remove-masquerade
firewall-cmd --set-log-denied=all
firewall-cmd --runtime-to-permanent
%end