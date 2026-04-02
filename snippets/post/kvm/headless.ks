# vim:  set ft=kickstart
# file: snippets/post/kvm/headless.ks

%post --interpreter /usr/bin/bash --log=/root/ks-post-kvm-headless.log
dnf install --setopt=install_weak_deps=False -y bridge-utils cockpit cockpit-bridge cockpit-machines cockpit-networkmanager cockpit-packagekit cockpit-system cockpit-ws guestfs-tools qemu-kvm-core libvirt virt-bootstrap virt-install
systemctl enable libvirtd cockpit.socket
firewall-offline-cmd --add-service=cockpit
usermod -aG libvirt ${KS_USER_NAME}
%end
