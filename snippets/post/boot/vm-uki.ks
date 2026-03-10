%post --interpreter=/usr/bin/bash --logfile=/root/ks-post-custom-virt-uki.log --erroronfail
set -euo pipefail

# Build and register a custom signed UKI derived from Fedora's prebuilt
# kernel-uki-virt image. The embedded command line is fully controlled here.
#
# Assumptions:
# - UEFI installation
# - ESP mounted at /boot/efi
# - Btrfs root label is "system"
# - Btrfs root subvolume is "root"
# - KS_MOK_PW is provided via staged host env or default.env
# - Required packages are already installed

declare key_dir
declare work_dir
declare install_dir
declare helper_dir
declare cmdline_file
declare key_pem
declare cert_pem
declare cert_der
declare mok_hash
declare plugin_file
declare builder_file
declare current_kver

key_dir="/etc/kernel/uki-keys"
work_dir="/var/lib/custom-virt-uki"
install_dir="/etc/kernel/install.d"
helper_dir="/usr/local/libexec"
cmdline_file="/etc/kernel/cmdline"
key_pem="${key_dir}/MOK-CUSTOM-UKI.key"
cert_pem="${key_dir}/MOK-CUSTOM-UKI.crt"
cert_der="${key_dir}/MOK-CUSTOM-UKI.der"
mok_hash="${key_dir}/mok-password.hash"
plugin_file="${install_dir}/95-custom-virt-uki.install"
builder_file="${helper_dir}/custom-virt-uki.sh"

install -d -m 0700 "${key_dir}" "${work_dir}"
install -d -m 0755 "${install_dir}" "${helper_dir}" /boot/efi/EFI/Linux

# Prevent accidental kernel-install plugin execution.
ln -sfn /dev/null "${install_dir}/20-grub.install"
ln -sfn /dev/null "${install_dir}/51-dracut-rescue.install"
ln -sfn /dev/null "${install_dir}/90-uki-copy.install"
ln -sfn /dev/null "${install_dir}/99-uki-uefi-setup.install"

# Persist the embedded command line used for every custom UKI build.
printf '%s\n' "root=LABEL=system rootfstype=btrfs rootflags=subvol=root rw quiet systemd.show_status=no console=tty0 ${KS_KERNEL_CMDLINE_BASE}" > "${cmdline_file}"
chmod 0600 "${cmdline_file}"

# Generate the Secure Boot signing key only once.
if [[ ! -s "${key_pem}" || ! -s "${cert_pem}" ]]; then
    openssl req \
        -new \
        -x509 \
        -newkey rsa:2048 \
        -keyout "${key_pem}" \
        -out "${cert_pem}" \
        -nodes \
        -days 3650 \
        -subj "/CN=${KS_HOSTNAME} Fedora UKI/" \
        -sha256
fi

chmod 0600 "${key_pem}" "${cert_pem}"

# Convert the certificate to DER for mokutil import.
openssl x509 -outform DER -in "${cert_pem}" -out "${cert_der}"
chmod 0600 "${cert_der}"

# Generate a dedicated MokManager password hash once.
if [[ ! -s "${mok_hash}" ]]; then
    mokutil --generate-hash="${KS_MOK_PW}" > "${mok_hash}"
fi
chmod 0600 "${mok_hash}"

# Central builder used both by kickstart and future kernel updates.
cat > "${builder_file}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Build or remove a custom signed UKI derived from Fedora's prebuilt
# kernel-uki-virt image.
#
# Arguments:
#   $1 = add|remove
#   $2 = kernel version

command="${1:?missing command}"
kver="${2:?missing kernel version}"

key_dir="/etc/kernel/uki-keys"
key_pem="${key_dir}/MOK-CUSTOM-UKI.key"
cert_pem="${key_dir}/MOK-CUSTOM-UKI.crt"
cmdline_file="/etc/kernel/cmdline"

work_root="/var/lib/custom-virt-uki"
work_dir="${work_root}/${kver}"

src_uki="/lib/modules/${kver}/vmlinuz-virt.efi"
out_uki="/boot/efi/EFI/Linux/fedora-${kver}-custom-virt.efi"

linux_bin="${work_dir}/linux.bin"
initrd_img="${work_dir}/initrd.img"
ucode_img="${work_dir}/ucode.img"
osrel_txt="${work_dir}/os-release"
sbat_csv="${work_dir}/sbat.csv"

find_shim() {
    if [[ -f /boot/efi/EFI/fedora/shimx64.efi ]]; then
        printf '%s\n' /boot/efi/EFI/fedora/shimx64.efi
        return 0
    fi

    if [[ -f /boot/efi/EFI/fedora/shim.efi ]]; then
        printf '%s\n' /boot/efi/EFI/fedora/shim.efi
        return 0
    fi

    return 1
}

remove_uki() {
    if [[ -f "${out_uki}" ]]; then
        kernel-bootcfg --remove-uki "${out_uki}" || true
        rm -f -- "${out_uki}"
    fi

    rm -rf -- "${work_dir}"
}

case "${command}" in
    remove)
        remove_uki
        exit 0
        ;;
    add)
        :
        ;;
    *)
        exit 0
        ;;
esac

test -f "${src_uki}"
test -f "${key_pem}"
test -f "${cert_pem}"
test -f "${cmdline_file}"

declare shim_file
declare -a ukify_args

shim_file="$(find_shim)"

install -d -m 0700 "${work_dir}"
install -d -m 0755 /boot/efi/EFI/Linux

# Extract required sections from Fedora's prebuilt virt UKI.
objcopy --dump-section .linux="${linux_bin}" "${src_uki}"
objcopy --dump-section .initrd="${initrd_img}" "${src_uki}"

# Extract optional sections only when they really exist and contain data.
if objcopy --dump-section .ucode="${ucode_img}" "${src_uki}" 2>/dev/null && [[ -s "${ucode_img}" ]]; then
    :
else
    rm -f -- "${ucode_img}"
fi

if objcopy --dump-section .osrel="${osrel_txt}" "${src_uki}" 2>/dev/null && [[ -s "${osrel_txt}" ]]; then
    :
else
    rm -f -- "${osrel_txt}"
fi

if objcopy --dump-section .sbat="${sbat_csv}" "${src_uki}" 2>/dev/null && [[ -s "${sbat_csv}" ]]; then
    :
else
    rm -f -- "${sbat_csv}"
fi

ukify_args=(
    build
    "--linux=${linux_bin}"
    "--initrd=${initrd_img}"
    "--uname=${kver}"
    "--cmdline=@${cmdline_file}"
    "--secureboot-private-key=${key_pem}"
    "--secureboot-certificate=${cert_pem}"
    "--output=${out_uki}"
)

if [[ -s "${ucode_img}" ]]; then
    ukify_args+=("--microcode=${ucode_img}")
fi

if [[ -s "${osrel_txt}" ]]; then
    ukify_args+=("--os-release=@${osrel_txt}")
else
    ukify_args+=("--os-release=@/usr/lib/os-release")
fi

if [[ -s "${sbat_csv}" ]]; then
    ukify_args+=("--sbat=@${sbat_csv}")
fi

ukify "${ukify_args[@]}"

chmod 0644 "${out_uki}"

# Recreate the direct shim -> UKI boot entry and place it first in BootOrder.
kernel-bootcfg --remove-uki "${out_uki}" || true
kernel-bootcfg \
    --add-uki "${out_uki}" \
    --shim "${shim_file}" \
    --title "Fedora custom virt UKI ${kver}" \
    --boot-order 0
EOF
chmod 0750 "${builder_file}"

# kernel-install plugin for all future kernel add/remove events.
cat > "${plugin_file}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

command="${1:?missing command}"
kver="${2:?missing kernel version}"

/usr/local/libexec/custom-virt-uki.sh "${command}" "${kver}"
EOF
chmod 0755 "${plugin_file}"

# Seed the current kernel immediately so the system is ready before the first reboot.
current_kver="$(ls -1 /lib/modules | sort -V | tail -1)"
"${builder_file}" add "${current_kver}"

kernel-bootcfg --show > /root/kernel-bootcfg-after-custom-uki.txt 2>&1 || true
efibootmgr -v > /root/efibootmgr-after-custom-uki.txt 2>&1 || true
find /boot/efi/EFI -maxdepth 4 -type f | sort > /root/efi-files-after-custom-uki.txt 2>&1 || true
%end

%post --nochroot --interpreter=/usr/bin/bash --logfile=/mnt/sysimage/root/ks-post-mok-import.log --erroronfail
set -euo pipefail

# Queue MOK enrollment outside the target chroot so the EFI variables are
# written in the running installer environment.

declare sysroot
declare cert_der
declare mok_hash

sysroot="/mnt/sysimage"
cert_der="${sysroot}/etc/kernel/uki-keys/MOK-CUSTOM-UKI.der"
mok_hash="${sysroot}/etc/kernel/uki-keys/mok-password.hash"

test -f "${cert_der}"
test -f "${mok_hash}"

if [[ -d /sys/firmware/efi/efivars ]] && ! mountpoint -q /sys/firmware/efi/efivars; then
    mount -t efivarfs efivarfs /sys/firmware/efi/efivars
fi

mokutil --import "${cert_der}" --hash-file "${mok_hash}"

# Fail hard if no pending enrollment exists.
mokutil --list-new | tee "${sysroot}/root/mokutil-list-new.txt"
grep -q "${KS_HOSTNAME} Fedora UKI" "${sysroot}/root/mokutil-list-new.txt"
%end
