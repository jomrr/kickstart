# DNF Configuration

%post --interpreter /usr/bin/bash --log=/root/ks-post-dnf.log
cp -a /etc/dnf/dnf.conf /etc/dnf/dnf.conf.rpm

cat << EOF > /etc/dnf/dnf.conf
[main]
best=False
clean_requirements_on_remove=True
deltarpm=False
defaultyes=False
fastestmirror=True
gpgcheck=True
gpgkey_dns_verification=False
installonly_limit=2
install_weak_deps=False
keepcache=False
localpkg_gpgcheck=False
max_parallel_downloads=10
metadata_expire=43200
repo_gpgcheck=True
skip_if_unavailable=True
tsflasg=nodocs
EOF
%end