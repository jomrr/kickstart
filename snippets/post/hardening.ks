# vim:  set ft=kickstart
# file: snippets/post/hardening.ks

# common hardening directives
%include hardening/disable-coredumps.ks
# modprobe blacklists
%include hardening/modprobe-blacklist-drivers.ks
%include hardening/modprobe-blacklist-fs.ks
%include hardening/modprobe-blacklist-net.ks
# sysctl settings
%include hardening/sysctl-net-ip4.ks
%include hardening/sysctl-net-ip6.ks
%include hardening/sysctl.ks
