# vim: set ft=kickstart
# file: snippets/post/tpm/cryptenroll.ks

%post --erroronfail --interpreter=/usr/bin/bash --log=/root/ks-post-tpm-cryptenroll.log
set -euo pipefail

# Enroll TPM2 unlock for all detected LUKS2 devices without destroying the
# installer-generated crypttab structure.
#
# Assumptions:
# - The installation uses LUKS2.
# - KS_LUKS_PW is available during staging/rendering.
# - A TPM2 or vTPM2 device is present.
#
# Notes:
# - PCRs are set explicitly to keep behavior deterministic.
# - The default is intentionally conservative for a first UKI-direct VM test.
# - Existing crypttab lines are patched in place instead of being rebuilt from
#   scratch.

PCRS="${KS_TPM2_PCRS}"
PASSFILE="/root/.luks-pass"
TMP_CRYPTTAB=""

cleanup() {
    rm -f -- "${PASSFILE}"
    if [[ -n "${TMP_CRYPTTAB}" ]]; then
        rm -f -- "${TMP_CRYPTTAB}"
    fi
}
trap cleanup EXIT

umask 077
printf '%s' "${KS_LUKS_PW}" > "${PASSFILE}"

# Discover actual block devices, not just UUID strings.
mapfile -t LUKS_DEVS < <(blkid -t TYPE=crypto_LUKS -o device)

if ((${#LUKS_DEVS[@]} == 0)); then
    printf 'No LUKS devices found, skipping TPM enrollment.\n' >&2
    exit 0
fi

for dev in "${LUKS_DEVS[@]}"; do
    systemd-cryptenroll \
        --unlock-key-file="${PASSFILE}" \
        --tpm2-device=auto \
        --tpm2-pcrs="${PCRS:-7}" \
        "${dev}"
done

# Preserve installer-generated crypttab entries and only add TPM options where
# they are missing. Do not replace mapper names or other existing options.
if [[ -f /etc/crypttab ]]; then
    TMP_CRYPTTAB="$(mktemp /etc/crypttab.XXXXXX)"

    awk -v pcrs="${PCRS:-7}" '
        BEGIN { OFS = "\t" }
        /^[[:space:]]*#/ || NF == 0 { print; next }
        {
            opts = $4

            if (opts == "" || opts == "-") {
                opts = "tpm2-device=auto,tpm2-measure-pcr=yes"
            } else {
                if (opts !~ /(^|,)tpm2-device=/) {
                    opts = opts ",tpm2-device=auto"
                }
                if (opts !~ /(^|,)tpm2-measure-pcr=/) {
                    opts = opts ",tpm2-measure-pcr=yes"
                }
            }

            $4 = opts
            print
        }
    ' /etc/crypttab > "${TMP_CRYPTTAB}"

    install -m 0600 "${TMP_CRYPTTAB}" /etc/crypttab
fi

# Rebuild initramfs/boot artifacts after TPM enrollment and crypttab updates.
dracut -f
%end
