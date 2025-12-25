#version=F42
#
# =============================================================================
# file: hosts/example0.ks
# desc: host specific kickstart snippet
# =============================================================================
#
# hostname
network --hostname=example0.example.com
# include profile to use
%include profiles/fedora-vm-btrfs.ks