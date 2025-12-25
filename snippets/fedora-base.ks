# ===========================================================================
# file: snippets/fedora-base.ks
# ===========================================================================

firewall --enabled --service=ssh

%packages --excludedocs --ignoremissing
%include fedora-packages-minimal.ks
%end
