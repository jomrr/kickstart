# disable unused and/or insecure kernel modules

%post --interpreter=/usr/bin/bash --log=/root/ks-post-modprobe-blacklist.log
cat << EOF >> /etc/modprobe.d/90-blacklist-net.conf
# Disable network protocols
blacklist dccp
install dccp /bin/true

blacklist sctp
install sctp /bin/true

blacklist rds
install rds /bin/true

blacklist tipc
install tipc /bin/true

blacklist n_hdlc
install n-hdlc /bin/true

blacklist ax25
install ax25 /bin/true

blacklist netrom
install netrom /bin/true

blacklist x25
install x25 /bin/true

blacklist rose
install rose /bin/true

blacklist decnet
install decnet /bin/true

blacklist econet
install econet /bin/true

blacklist af_802154
install af_802154 /bin/true

blacklist ipx
install ipx /bin/true

blacklist appletalk
install appletalk /bin/true

blacklist psnap
install psnap /bin/true

blacklist p8023
install p8023 /bin/true

blacklist p8022
install p8022 /bin/true

blacklist can
install can /bin/true

blacklist atm
install atm /bin/true
EOF

cat << EOF >> /etc/modprobe.d/90-blacklist-fs.conf
# Disable filesystem modules

blacklist cramfs
install cramfs /bin/true

blacklist freevxfs
install freevxfs /bin/true

blacklist jffs2
install jffs2 /bin/true

blacklist hfs
install hfs /bin/true

blacklist hfsplus
install hfsplus /bin/true

blacklist squashfs
install squashfs /bin/true

blacklist udf
install udf /bin/true

blacklist gfs2
install gfs2 /bin/true

blacklist nfsv3
install nfsv3 /bin/true

# Allow some network filesystems to be loaded
install cifs /bin/true
install nfs /bin/true
install nfsv4 /bin/true
install ksmbd /bin/true
EOF

cat << EOF >> /etc/modprobe.d/90-blacklist-drivers.conf
# Disable drivers and services
blacklist vivid
install vivid /bin/true

# Disable Bluetooth
blacklist bluetooth
install bluetooth /bin/true

# Disable Bluetooth USB
blacklist btusb
install btusb /bin/true

# Disable Webcam
blacklist uvcvideo
install uvcvideo /bin/true

# Disable Firewire (be careful on VMs, e.g. Netcup KMV)
blacklist firewire-core
install firewire-core /bin/true

# Disable USB storage
blacklist usb-storage
install usb-storage /bin/true
EOF
%end