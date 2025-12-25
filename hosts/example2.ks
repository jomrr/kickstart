#version=
#
# =============================================================================
# file: hosts/example2.ks
# desc: host specific kickstart snippet
# =============================================================================
#
# hostname
network --hostname=example2.mauer.in
# include profile to use
%include profiles/fedora-vm-btrfs.ks