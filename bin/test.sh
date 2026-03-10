#!/usr/bin/env bash
set -euo pipefail

# Start a Fedora VM installation test with a Kickstart file injected into the
# installer initrd.
#
# Assumptions:
# - The script is executed from inside the Kickstart repository or from any
#   location below it. The repository root is derived from the script path.
# - The generated Kickstart file already exists at dist/<host>.ks.
# - libvirt, virt-install, OVMF, and swtpm support are installed.
# - The selected libvirt network exists.
#
# Behavior:
# - Boot the installer in UEFI Secure Boot mode.
# - Inject the generated Kickstart file into the initrd.
# - Attach a vTPM 2.0 device backed by the emulator backend.
# - Use a deterministic locally administered MAC address derived from the host
#   name unless a MAC is explicitly provided.

declare host_name
declare script_dir
declare repo_root
declare ks_file
declare vm_name
declare install_url
declare os_variant
declare memory_mb
declare vcpus
declare disk_gib
#declare disk_pool
declare network_name
declare mac_address

host_name="${1:?missing host name}"

if [[ "${host_name}" != "$(basename -- "${host_name}")" ]] || [[ "${host_name}" == *.ks ]]; then
    printf 'test.sh: error: host name must be a plain stem without path or suffix\n' >&2
    exit 2
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "${script_dir}/.." && pwd -P)"
ks_file="${repo_root}/dist/${host_name}.ks"

if [[ ! -f "${ks_file}" ]]; then
    printf 'test.sh: error: missing Kickstart file: %s\n' "${ks_file}" >&2
    exit 2
fi

generate_mac_address() {
    local name
    local digest

    name="${1:?missing host name for MAC generation}"
    digest="$(printf '%s' "${name}" | sha256sum | awk '{print $1}')"

    # Use a locally administered unicast MAC prefix and derive the remaining
    # bytes deterministically from the host name hash.
    printf '52:%s:%s:%s:%s:%s\n' \
        "${digest:0:2}" \
        "${digest:2:2}" \
        "${digest:4:2}" \
        "${digest:6:2}" \
        "${digest:8:2}"
}

# Default values can be overridden from the environment when needed.
vm_name="${VM_NAME:-${host_name}}"
install_url="${INSTALL_URL:-https://ftp.fau.de/fedora/linux/releases/43/Everything/x86_64/os/}"
os_variant="${OS_VARIANT:-fedora41}"
memory_mb="${MEMORY_MB:-8192}"
vcpus="${VCPUS:-4}"
disk_gib="${DISK_GIB:-32}"
#disk_pool="${DISK_POOL:-default}"
network_name="${NETWORK_NAME:-default}"
mac_address="${MAC_ADDRESS:-$(generate_mac_address "${host_name}")}"

virt-install \
    --name "${vm_name}" \
    --connect "qemu:///system" \
    --virt-type "kvm" \
    --memory "${memory_mb}" \
    --vcpus "${vcpus}" \
    --cpu "host-model" \
    --os-variant "${os_variant}" \
    --boot "loader=/usr/share/OVMF/OVMF_CODE.secboot.fd,loader.readonly=yes,loader.type=pflash,nvram.template=/usr/share/OVMF/OVMF_VARS.secboot.fd,loader_secure=yes" \
    --features "smm.state=on" \
    --tpm "backend.type=emulator,backend.version=2.0,model=tpm-crb" \
    --disk "/tmp/${vm_name}.qcow2,format=qcow2,size=${disk_gib},target.bus=virtio" \
    --network "network=${network_name},model=virtio,mac=${mac_address}" \
    --graphics "spice" \
    --sound "none" \
    --console "pty,target_type=serial" \
    --location "${install_url}" \
    --initrd-inject "${ks_file}" \
    --extra-args "inst.ks=file:/${host_name}.ks console=tty0 ipv6.disable=1" \
    --autoconsole "graphical"
