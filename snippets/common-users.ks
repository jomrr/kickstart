# vim:  set ft=kickstart
# file: snippets/common-users.ks
# desc: common users kickstart snippet

# disable root account login
rootpw --lock
# disable root password login via SSH during installation
sshpw  --username=root --lock Locked,0+815 --plaintext
# create user {KS_USER_NAME} with password {KS_USER_PASSWORD}
user --name=jomrr --password=Strunzen0ed= --plaintext --gecos="jomrr" --groups=wheel --shell=/bin/bash
# add SSH public key for user {KS_USER_NAME}
sshkey --username=jomrr "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOdSdKkfbiZVM73QDD4p2+Ce0LW7OTVWey42mTL07ZOn"