#!/usr/bin/env bash
set -euo pipefail

# Flatten and optionally validate a host-specific staged Kickstart tree.
#
# Project-specific layout:
# - build/<host>/staged/host.ks as the staged Kickstart entry
# - build/<host>/flat.ks        as the persistent flattened build artifact
# - build/<host>/validate.log   as the persistent validation log
# - dist/<host>.ks              as the final published output
#
# Behavior:
# - Read '#version=' from build/<host>/staged/host.ks when present
# - Fall back to DEVEL when no version header exists
# - Run ksflatten from inside build/<host>/staged so relative includes resolve
#   against the staged host-specific tree
# - Optionally validate the flattened output when --validate is present
# - Keep build artifacts for debugging and reproducibility
# - Publish the final dist output atomically
# - Prefix all user-visible status lines with dist/<host>.ks:

declare host_name
declare do_validate
declare script_dir
declare repo_root
declare build_root
declare staged_root
declare entry_file
declare dist_dir
declare output_file
declare output_label
declare flat_file
declare flat_tmp
declare dist_tmp
declare validator_log
declare ks_version
declare status

host_name="${1:?missing host name}"
shift

do_validate=0
status=0

while (($# > 0)); do
    case "$1" in
        --validate)
            do_validate=1
            shift
            ;;
        *)
            printf 'ksflatten: error: unknown argument: %s\n' "$1" >&2
            exit 2
            ;;
    esac
done

if [[ "${host_name}" != "$(basename -- "${host_name}")" ]] || [[ "${host_name}" == *.ks ]]; then
    printf 'ksflatten: error: host name must be a plain stem without path or suffix\n' >&2
    exit 2
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "${script_dir}/.." && pwd -P)"
build_root="${repo_root}/build/${host_name}"
staged_root="${build_root}/staged"
entry_file="${staged_root}/host.ks"
dist_dir="${repo_root}/dist"
output_file="${dist_dir}/${host_name}.ks"
output_label="dist/${host_name}.ks"
flat_file="${build_root}/flat.ks"
validator_log="${build_root}/validate.log"

if [[ ! -f "${entry_file}" ]]; then
    printf 'ksflatten: error: missing staged host entry: %s\n' "${entry_file}" >&2
    exit 2
fi

mkdir -p "${build_root}" "${dist_dir}"
umask 077
flat_tmp="$(mktemp "${build_root}/.flat.XXXXXX.tmp")"
dist_tmp="$(mktemp "${dist_dir}/.${host_name}.XXXXXX.tmp")"

cleanup() {
    rm -f -- "${flat_tmp}" "${dist_tmp}"
}
trap cleanup EXIT

log_info() {
    local message
    message="${1:?missing log message}"
    printf '%s: %s\n' "${output_label}" "${message}"
}

print_prefixed_file() {
    local file_path
    local stream

    file_path="${1:?missing file path}"
    stream="${2:-stdout}"

    if [[ "${stream}" == "stderr" ]]; then
        awk -v prefix="${output_label}: " '
            NF { print prefix $0 }
        ' "${file_path}" >&2
    else
        awk -v prefix="${output_label}: " '
            NF { print prefix $0 }
        ' "${file_path}"
    fi
}

# Read the optional Kickstart version header from the staged host entry.
# When no explicit version is present, use DEVEL by convention.
ks_version="$(
    sed -nE 's/^[[:space:]]*#version[[:space:]]*=[[:space:]]*([^[:space:]]+)[[:space:]]*$/\1/p' \
        "${entry_file}" \
        | head -n 1
)"
ks_version="${ks_version:-DEVEL}"

log_info "flattening kickstart"
(
    cd "${staged_root}"
    ksflatten -v "${ks_version}" -c host.ks -o "${flat_tmp}"
)
mv -f -- "${flat_tmp}" "${flat_file}"

if [[ "${do_validate}" -eq 1 ]]; then
    log_info "validating kickstart"
    : > "${validator_log}"

    if ksvalidator -v "${ks_version}" "${flat_file}" >"${validator_log}" 2>&1; then
        if [[ -s "${validator_log}" ]]; then
            print_prefixed_file "${validator_log}"
        fi
    else
        status=$?
        if [[ -s "${validator_log}" ]]; then
            print_prefixed_file "${validator_log}" "stderr"
        fi
        exit "${status}"
    fi
fi

cp -- "${flat_file}" "${dist_tmp}"
mv -f -- "${dist_tmp}" "${output_file}"
