%post --interpreter=/usr/bin/bash --logfile=/root/ks-post-custom-virt-uki.log --erroronfail
set -euo pipefail

# Build a custom signed UKI from Fedora's prebuilt kernel-uki-virt by
# extracting the embedded kernel and initrd sections and reassembling them
# with a custom embedded command line.
#
# Assumptions:
# - UEFI installation
# - ESP mounted at /boot/efi
# - kernel-uki-virt is installed
# - systemd-ukify, python3-virt-firmware, mokutil, openssl and binutils are installed
# - root filesystem label is "system"
# - root Btrfs subvolume is "root"

declare work_dir
declare src_uki
declare out_uki
declare key_pem
declare cert_pem
declare cert_der
declare mok_hash
declare cmdline_file
declare linux_bin
declare initrd_img
declare ucode_img
declare shim_file
declare kver

work_dir="/root/custom-virt-uki"
key_pem="${work_dir}/MOK-CUSTOM-UKI.key"
cert_pem="${work_dir}/MOK-CUSTOM-UKI.crt"
cert_der="${work_dir}/MOK-CUSTOM-UKI.der"
mok_hash="${work_dir}/mok-password.hash"
cmdline_file="${work_dir}/cmdline.txt"
linux_bin="${work_dir}/linux.bin"
initrd_img="${work_dir}/initrd.img"
ucode_img="${work_dir}/ucode.img"

install -d -m 0700 "${work_dir}"
install -d -m 0755 /boot/efi/EFI/Linux

kver="$(ls -1 /lib/modules | sort -V | tail -1)"
src_uki="/lib/modules/${kver}/vmlinuz-virt.efi"
out_uki="/boot/efi/EFI/Linux/fedora-${kver}-custom-virt.efi"

test -f "${src_uki}"

# Locate shim for the direct shim -> UKI boot path using MOK trust.
if [[ -f /boot/efi/EFI/fedora/shimx64.efi ]]; then
    shim_file="/boot/efi/EFI/fedora/shimx64.efi"
elif [[ -f /boot/efi/EFI/fedora/shim.efi ]]; then
    shim_file="/boot/efi/EFI/fedora/shim.efi"
else
    printf 'No Fedora shim binary found on the ESP.\n' >&2
    exit 1
fi

# Extract the embedded kernel and initrd from Fedora's prebuilt virt UKI.
objcopy --dump-section .linux="${linux_bin}" "${src_uki}"
objcopy --dump-section .initrd="${initrd_img}" "${src_uki}"

# Extract optional microcode section when present.
if objcopy --dump-section .ucode="${ucode_img}" "${src_uki}" 2>/dev/null; then
    :
else
    rm -f "${ucode_img}"
fi

# Embed the final kernel command line into the custom UKI.
cat > "${cmdline_file}" <<'EOF'
root=LABEL=system rootfstype=btrfs rootflags=subvol=root rw quiet systemd.show_status=no console=tty0
EOF
chmod 0600 "${cmdline_file}"

# Generate the Secure Boot signing key pair for the custom UKI.
openssl req \
    -new \
    -x509 \
    -newkey rsa:2048 \
    -keyout "${key_pem}" \
    -out "${cert_pem}" \
    -nodes \
    -days 3650 \
    -subj "/CN=Custom Fedora Virt UKI/" \
    -sha256

chmod 0600 "${key_pem}" "${cert_pem}"

# Convert the certificate to DER for mokutil import.
openssl x509 -outform DER -in "${cert_pem}" -out "${cert_der}"
chmod 0600 "${cert_der}"

# Generate a dedicated MokManager password hash from the staged kickstart variable.
# KS_MOK_PASSWORD must be provided through your host env staging.
mokutil --generate-hash="${KS_MOK_PASSWORD}" > "${mok_hash}"
chmod 0600 "${mok_hash}"

# Rebuild the UKI with the extracted virt kernel + initrd and the embedded custom cmdline.
if [[ -s "${ucode_img}" ]]; then
    ukify build \
        --linux="${linux_bin}" \
        --initrd="${initrd_img}" \
        --microcode="${ucode_img}" \
        --uname="${kver}" \
        --os-release=@/usr/lib/os-release \
        --cmdline="@${cmdline_file}" \
        --secureboot-private-key="${key_pem}" \
        --secureboot-certificate="${cert_pem}" \
        --output="${out_uki}"
else
    ukify build \
        --linux="${linux_bin}" \
        --initrd="${initrd_img}" \
        --uname="${kver}" \
        --os-release=@/usr/lib/os-release \
        --cmdline="@${cmdline_file}" \
        --secureboot-private-key="${key_pem}" \
        --secureboot-certificate="${cert_pem}" \
        --output="${out_uki}"
fi

chmod 0644 "${out_uki}"

# Replace any existing boot entry for this UKI path and make it the first entry in BootOrder.
kernel-bootcfg --remove-uki "${out_uki}" || true
kernel-bootcfg \
    --add-uki "${out_uki}" \
    --shim "${shim_file}" \
    --title "Fedora Mauer virt UKI ${kver}" \
    --boot-order 0

kernel-bootcfg --show > /root/kernel-bootcfg-after-custom-uki.txt 2>&1 || true
efibootmgr -v > /root/efibootmgr-after-custom-uki.txt 2>&1 || true
%end

%post --nochroot --interpreter=/usr/bin/bash --logfile=/mnt/sysimage/root/ks-post-mok-import.log --erroronfail
set -euo pipefail

# Queue MOK enrollment outside the target chroot so the request is written to EFI vars
# reliably in the running installer environment.

declare sysroot
declare cert_der
declare mok_hash

sysroot="/mnt/sysimage"
cert_der="${sysroot}/root/custom-virt-uki/MOK-CUSTOM-UKI.der"
mok_hash="${sysroot}/root/custom-virt-uki/mok-password.hash"

test -f "${cert_der}"
test -f "${mok_hash}"

if [[ -d /sys/firmware/efi/efivars ]] && ! mountpoint -q /sys/firmware/efi/efivars; then
    mount -t efivarfs efivarfs /sys/firmware/efi/efivars
fi

mokutil --import "${cert_der}" --hash-file "${mok_hash}"

# Fail hard when no pending MOK request exists.
mokutil --list-new | tee "${sysroot}/root/mokutil-list-new.txt"
grep -q "Custom Fedora Virt UKI" "${sysroot}/root/mokutil-list-new.txt"
%end