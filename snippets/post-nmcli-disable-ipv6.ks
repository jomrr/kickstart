## Network Manager Configuration

%post --interpreter /usr/bin/bash --log=/root/ks-post-nmcli.log

# Device Configuration to disable ipv6, --noipv6 in ks sets ignore not disable
for conn in $(nmcli -t -f NAME connection show | grep -vE '^(lo)$'); do
    nmcli connection modify "$conn" ipv6.method disable
done

%end