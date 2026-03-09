#!/usr/bin/env bash
set -euo pipefail

# Stage a Kickstart source file into a host-specific build tree.
#
# Behavior:
# - Load hosts/default.env first when present.
# - Load hosts/<host>.env afterwards when present, allowing host-specific
#   values to override common defaults.
# - Restrict envsubst to currently defined KS_* variables after sourcing.
# - Copy the source file unchanged when no env files exist or when no KS_*
#   variables are available.
# - Publish the destination atomically.

declare host_name
declare src_file
declare dst_file
declare script_dir
declare repo_root
declare hosts_dir
declare dst_dir
declare tmp_file
declare shell_format

declare -a env_files

host_name="${1:?missing host name}"
src_file="${2:?missing source file}"
dst_file="${3:?missing destination file}"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "${script_dir}/.." && pwd -P)"
hosts_dir="${repo_root}/hosts"
dst_dir="$(dirname -- "${dst_file}")"

load_env_file() {
    local env_path

    env_path="${1:?missing env file path}"

    set -a
    # shellcheck disable=SC1090
    . "${env_path}"
    set +a
}

build_shell_format() {
    local var_name
    local format_string

    format_string=""

    while IFS= read -r var_name; do
        format_string+="${format_string:+ }"'${'"${var_name}"'}'
    done < <(compgen -A variable | awk '/^KS_[A-Za-z_][A-Za-z0-9_]*$/')

    printf '%s\n' "${format_string}"
}

if [[ -f "${hosts_dir}/default.env" ]]; then
    env_files+=("${hosts_dir}/default.env")
fi

if [[ -f "${hosts_dir}/${host_name}.env" ]]; then
    env_files+=("${hosts_dir}/${host_name}.env")
fi

mkdir -p "${dst_dir}"
umask 077
tmp_file="$(mktemp "${dst_dir}/.$(basename -- "${dst_file}").XXXXXX.tmp")"

cleanup() {
    rm -f -- "${tmp_file}"
}
trap cleanup EXIT

if ((${#env_files[@]} > 0)); then
    for env_file in "${env_files[@]}"; do
        load_env_file "${env_file}"
    done

    shell_format="$(build_shell_format)"

    if [[ -n "${shell_format}" ]]; then
        envsubst "${shell_format}" < "${src_file}" > "${tmp_file}"
    else
        cp -f -- "${src_file}" "${tmp_file}"
    fi
else
    cp -f -- "${src_file}" "${tmp_file}"
fi

chmod 0600 "${tmp_file}"
mv -f -- "${tmp_file}" "${dst_file}"
trap - EXIT
