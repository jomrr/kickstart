#!/usr/bin/env bash
set -euo pipefail

# Flatten and optionally validate a host-specific staged Kickstart tree.
#
# Project-specific layout:
# - build/<host>/host.ks   as the staged Kickstart entry
# - dist/<host>.ks         as the final flattened output
#
# Behavior:
# - Read '#version=' from build/<host>/host.ks when present
# - Fall back to DEVEL when no version header exists
# - Run ksflatten from inside build/<host> so relative includes resolve against
#   the staged host-specific tree
# - Optionally validate the flattened output when --validate is present
# - Publish the final output atomically
# - Prefix all user-visible status lines with dist/<host>.ks:

declare host_name
declare do_validate
declare script_dir
declare repo_root
declare build_root
declare entry_file
declare dist_dir
declare output_file
declare output_label
declare tmp_file
declare validator_log
declare ks_version

host_name="${1:?missing host name}"
shift

do_validate=0

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
entry_file="${build_root}/host.ks"
dist_dir="${repo_root}/dist"
output_file="${dist_dir}/${host_name}.ks"
output_label="dist/${host_name}.ks"

if [[ ! -f "${entry_file}" ]]; then
    printf 'ksflatten: error: missing staged host entry: %s\n' "${entry_file}" >&2
    exit 2
fi

mkdir -p "${dist_dir}"
umask 077
tmp_file="$(mktemp "${dist_dir}/.${host_name}.XXXXXX.tmp")"
validator_log="$(mktemp "${dist_dir}/.${host_name}.validator.XXXXXX.log")"

cleanup() {
    rm -f -- "${tmp_file}" "${validator_log}"
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

# Flatten from inside the host-specific build root so logical include paths such
# as "snippets/..." and "profiles/..." resolve against the staged tree.
(
    cd "${build_root}"
    ksflatten -v "${ks_version}" -c host.ks -o "${tmp_file}"
)

if [[ "${do_validate}" -eq 1 ]]; then
    log_info "validating kickstart"
    if ksvalidator -v "${ks_version}" "${tmp_file}" >"${validator_log}" 2>&1; then
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

mv -f -- "${tmp_file}" "${output_file}"
