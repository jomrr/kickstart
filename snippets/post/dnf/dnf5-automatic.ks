# vim:  set ft=kickstart
# file: snippets/post-dnf5-automatic.ks

%post --interpreter /usr/bin/bash --log=/root/ks-post-dnf5-automatic.log
dnf install --setopt=install_weak_deps=False -y dnf5-plugin-automatic

cat << EOF > /etc/dnf/automatic.conf
[commands]
apply_updates = yes
reboot = when-needed
upgrade_type = default
EOF

systemctl enable dnf5-automatic.timer
%end
