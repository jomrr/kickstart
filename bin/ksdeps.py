#!/usr/bin/env python3
"""
Generate a Make dependency fragment for one Kickstart host.

The tool walks literal %include / %ksappend directives recursively and writes
two dependency lines:

1. build/<host>/deps.mk: all source files that influence dependency discovery
2. build/<host>/flat.ks: all exact source files needed for building the host

Assumptions:
- hosts/<host>.ks are the only entry points
- profiles/** and snippets/** includes must use the .ksi suffix
- include paths are literal and appear on a single line
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

INCLUDE_RE = re.compile(r"^\s*%(include|ksappend)\s+(\S+)\s*$")
URL_RE = re.compile(r"^[A-Za-z][A-Za-z0-9+.-]*://")
ROOT_PREFIXES = ("hosts/", "profiles/", "snippets/")


class IncludeError(Exception):
    """Raised when a Kickstart include cannot be resolved safely."""


def parse_args() -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(
        description="Generate a Make dependency fragment for one Kickstart host."
    )
    parser.add_argument(
        "host_name",
        help="Host name without path or suffix, for example example-vm-uki.",
    )
    return parser.parse_args()


def validate_host_name(host_name: str) -> str:
    """
    Validate the host name passed on the command line.

    Args:
        host_name: Raw host name argument.

    Returns:
        The validated host name.

    Raises:
        IncludeError: The host name is not a plain stem.
    """
    if Path(host_name).name != host_name or host_name.endswith(".ks"):
        raise IncludeError(
            "Host name must be passed as a plain stem without path or suffix."
        )
    return host_name


def resolve_include(
    parent_file: Path,
    include_value: str,
    repo_root: Path,
    host_name: str,
) -> Path:
    """
    Resolve and validate one include path.

    Args:
        parent_file: Including file.
        include_value: Raw include value from the Kickstart directive.
        repo_root: Repository root directory.
        host_name: Current host name.

    Returns:
        Absolute resolved include path.

    Raises:
        IncludeError: The include is invalid or unsafe.
    """
    if URL_RE.match(include_value):
        raise IncludeError(f"URL include is not allowed: {include_value}")

    if include_value.startswith("/"):
        raise IncludeError(f"Absolute include path is not allowed: {include_value}")

    if include_value.startswith(ROOT_PREFIXES):
        candidate = (repo_root / include_value).resolve()
    else:
        candidate = (parent_file.parent / include_value).resolve()

    try:
        rel_path = candidate.relative_to(repo_root)
    except ValueError as exc:
        raise IncludeError(f"Include escapes repository root: {candidate}") from exc

    if not candidate.is_file():
        raise IncludeError(f"Missing include file: {candidate}")

    if rel_path.parts[0] in {"profiles", "snippets"} and candidate.suffix != ".ksi":
        raise IncludeError(
            f"Includes below profiles/ and snippets/ must use the .ksi suffix: {rel_path}"
        )

    if rel_path.parts[0] == "hosts":
        expected = Path("hosts") / f"{host_name}.ks"
        if rel_path != expected:
            raise IncludeError(
                f"Only the current host entry may be referenced below hosts/: {rel_path}"
            )

    return candidate


def walk(
    file_path: Path,
    repo_root: Path,
    host_name: str,
    seen: set[Path],
    stack: list[Path],
) -> None:
    """
    Walk the include graph recursively.

    Args:
        file_path: Current source file.
        repo_root: Repository root directory.
        host_name: Current host name.
        seen: Collected source file dependencies.
        stack: Current recursion stack for cycle detection.

    Raises:
        IncludeError: The include graph is invalid.
    """
    file_path = file_path.resolve()

    if file_path in stack:
        cycle = " -> ".join(item.name for item in stack + [file_path])
        raise IncludeError(f"Include cycle detected: {cycle}")

    if file_path in seen:
        return

    seen.add(file_path)
    stack.append(file_path)

    for lineno, line in enumerate(
        file_path.read_text(encoding="utf-8").splitlines(),
        start=1,
    ):
        match = INCLUDE_RE.match(line)
        if match is None:
            continue

        include_value = match.group(2)

        try:
            child = resolve_include(file_path, include_value, repo_root, host_name)
        except IncludeError as exc:
            raise IncludeError(f"{file_path}:{lineno}: {exc}") from exc

        try:
            walk(child, repo_root, host_name, seen, stack)
        except IncludeError as exc:
            raise IncludeError(f"{file_path}:{lineno}: {exc}") from exc

    stack.pop()


def collect_dependencies(repo_root: Path, host_name: str) -> list[Path]:
    """
    Collect exact transitive source dependencies for one host.

    Args:
        repo_root: Repository root directory.
        host_name: Current host name.

    Returns:
        Sorted list of absolute source dependency paths.

    Raises:
        IncludeError: The host entry or one of its includes is invalid.
    """
    host_name = validate_host_name(host_name)

    host_file = (repo_root / "hosts" / f"{host_name}.ks").resolve()
    default_env = (repo_root / "hosts" / "default.env").resolve()
    host_env = (repo_root / "hosts" / f"{host_name}.env").resolve()

    if not host_file.is_file():
        raise IncludeError(f"Missing host entry file: {host_file}")

    seen: set[Path] = set()
    walk(host_file, repo_root, host_name, seen, [])

    if default_env.is_file():
        seen.add(default_env)

    if host_env.is_file():
        seen.add(host_env)

    return sorted(seen)


def render_make_fragment(
    depfile_path: Path,
    flat_target: Path,
    source_deps: list[Path],
    tool_path: Path,
) -> str:
    """
    Render the final Make dependency fragment.

    Args:
        depfile_path: Absolute path to build/<host>/deps.mk.
        flat_target: Absolute path to build/<host>/flat.ks.
        source_deps: Exact transitive source dependencies for the host.
        tool_path: Path to this tool.

    Returns:
        Complete Make fragment text.
    """
    flat_deps = " ".join(str(path) for path in source_deps)
    depfile_deps = " ".join(
        str(path) for path in sorted([*source_deps, tool_path.resolve()])
    )

    return (
        f"{depfile_path}: {depfile_deps}\n"
        f"{flat_target}: {flat_deps}\n"
    )


def main() -> int:
    """
    Generate one dependency fragment for one host.

    Returns:
        Process exit code.
    """
    args = parse_args()

    repo_root = Path.cwd().resolve()
    host_name = validate_host_name(args.host_name)

    build_dir = repo_root / "build" / host_name
    depfile_path = build_dir / "deps.mk"
    flat_target = build_dir / "flat.ks"
    tool_path = repo_root / "bin" / "ksdeps.py"

    source_deps = collect_dependencies(repo_root, host_name)
    content = render_make_fragment(depfile_path, flat_target, source_deps, tool_path)

    depfile_path.parent.mkdir(parents=True, exist_ok=True)

    old_content = None
    if depfile_path.exists():
        old_content = depfile_path.read_text(encoding="utf-8")

    if old_content != content:
        depfile_path.write_text(content, encoding="utf-8")

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except IncludeError as exc:
        print(f"ksdeps: error: {exc}", file=sys.stderr)
        raise SystemExit(2) from exc
