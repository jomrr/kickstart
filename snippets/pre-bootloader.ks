%pre --interpreter=/bin/bash --log=/root/ks-pre-bootloader.log
set -euo pipefail

vendor="$(awk -F': *' '/^vendor_id/ {print $2; exit}' /proc/cpuinfo || true)"

# Common hardening args you want on both
COMMON_ARGS=(
  "debugfs=off"
  "efi=disable_early_pci_dma"
  "init_on_alloc=1"
  "init_on_free=1"
  "iommu.strict=1"
  "kexec_load_disabled=1"
  "lockdown=confidentiality"
  "module.sig_enforce=1"
  "page_alloc.shuffle=1"
  "pti=on"
  "randomize_kstack_offset=on"
  "slab_nomerge"
  "spec_store_bypass_disable=on"
  "vsyscall=none"
)

IOMMU_ARGS=()
case "$vendor" in
  GenuineIntel)
    IOMMU_ARGS+=("intel_iommu=on")
    ;;
  AuthenticAMD)
    IOMMU_ARGS+=("amd_iommu=force_isolation")
    ;;
  *)
    # Fallback: both (Linux ignores the irrelevant one with error message)
    IOMMU_ARGS+=("intel_iommu=on" "amd_iommu=force_isolation")
    ;;
esac

# Optional: for bare metal and hypervisor builds
# IOMMU_ARGS+=("iommu=force")

append="$(printf '%s ' "${COMMON_ARGS[@]}" "${IOMMU_ARGS[@]}")"
append="${append% }"

cat > /tmp/bootloader-args.ks <<EOF
bootloader --append="$append"
EOF

echo "%include /tmp/bootloader-args.ks"
%end
 