%post --interpreter /usr/bin/bash --log=/root/ks-post-disable-coredumps.log
mkdir -p /etc/security/limits.d

cat << EOF > /etc/security/limits.d/99-disable-coredumps.conf
* soft core 0
* hard core 0
EOF

mkdir -p /etc/systemd/coredump.conf.d/

cat << EOF >> /etc/systemd/coredump.conf.d/disable.conf
[Coredump]
Storage=none
ProcessSizeMax=0
EOF

cp -fa /usr/lib/systemd/system.conf /etc/systemd/system.conf
sed -i 's/^\(#DefaultLimitCORE=.*\)/DefaultLimitCORE=0/' /etc/systemd/system.conf

cat << EOF > /etc/sysctl.d/99-disable-coredumps.conf
# Disable core dumps
fs.suid_dumpable = 0
kernel.core_pattern=|/bin/false
EOF
%end