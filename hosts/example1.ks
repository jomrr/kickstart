#version=RHEL10
#
# =============================================================================
# file: hosts/example1.ks
# desc: host specific kickstart snippet
# =============================================================================
#
# hostname
network --hostname=example1.mauer.in
# include profile to use
%include profiles/fedora-vm-btrfs.ks