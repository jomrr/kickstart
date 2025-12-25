# ===========================================================================
# file: snippets/harden-sysctl.ks
# ===========================================================================

%post --interpreter=/usr/bin/bash --log=/root/ks-post-harden-sysctl.log
cat << EOF >> /etc/sysctl.d/90-harden-dev-tty.conf
# Disable TTY line discipline autoload
dev.tty.ldisc_autoload=0
EOF

cat << EOF >> /etc/sysctl.d/90-harden-fs.conf
# Protect file system objects
fs.protected_fifos=2
fs.protected_hardlinks=1
fs.protected_regular=2
fs.protected_symlinks=1
EOF

cat << EOF >> /etc/sysctl.d/90-harden-kernel.conf
# Kernel self-protection settings
kernel.dmesg_restrict=1
kernel.kexec_load_disabled=1
kernel.kptr_restrict=2
kernel.perf_event_paranoid=3
kernel.printk=3 3 3 3
kernel.randomize_va_space=2
kernel.sysrq=4
kernel.unprivileged_bpf_disabled=1
kernel.unprivileged_userns_clone=0
kernel.yama.ptrace_scope=2
EOF

cat << EOF >> /etc/sysctl.d/90-harden-net-core.conf
# Harden BPF JIT
net.core.bpf_jit_harden=2
EOF

cat << EOF >> /etc/sysctl.d/90-harden-net-ipv4.conf
# Harden IPv4 settings
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.all.accept_source_route=0
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.all.secure_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.default.accept_source_route=0
net.ipv4.conf.default.rp_filter=1
net.ipv4.conf.default.secure_redirects=0
net.ipv4.conf.default.send_redirects=0
net.ipv4.icmp_echo_ignore_all=1
net.ipv4.tcp_dsack=0
net.ipv4.tcp_fack=0
net.ipv4.tcp_rfc1337=1
net.ipv4.tcp_sack=0
net.ipv4.tcp_syncookies=1
EOF

cat << EOF >> /etc/sysctl.d/90-harden-net-ipv6.conf
# Harden IPv6 settings
net.ipv6.conf.all.accept_ra=0
net.ipv6.conf.all.accept_redirects=0
net.ipv6.conf.all.accept_source_route=0
net.ipv6.conf.all.use_tempaddr=2  
net.ipv6.conf.default.accept_ra=0
net.ipv6.conf.default.accept_redirects=0
net.ipv6.conf.default.accept_source_route=0
net.ipv6.conf.default.use_tempaddr=2
EOF

cat << EOF >> /etc/sysctl.d/90-harden-vm.conf
# Randomize memory mappings
vm.mmap_rnd_bits=32
vm.mmap_rnd_compat_bits=16

# Disable unprivileged userfaultfd
vm.unprivileged_userfaultfd=0
EOF
%end
