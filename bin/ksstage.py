#!/usr/bin/env python3
"""
Stage one Kickstart host into build/<host>/staged.

The tool stages exactly the files returned by ksdeps.collect_dependencies():
- hosts/<host>.ks          -> build/<host>/staged/host.ks
- profiles/**/*.ksi        -> build/<host>/staged/profiles/**/*.ksi
- snippets/**/*.ksi        -> build/<host>/staged/snippets/**/*.ksi

Variable rendering substitutes only variables with the KS_ prefix loaded from:
- hosts/default.env
- hosts/<host>.env
"""

from __future__ import annotations

import argparse
import re
import shutil
import sys
from pathlib import Path

import ksdeps

ASSIGNMENT_RE = re.compile(
    r"""^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)\s*$"""
)
VAR_RE = re.compile(r"\$(\w+)|\$\{([^}]+)\}")


class StageError(Exception):
    """Raised when one host cannot be staged."""


def parse_args() -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(
        description="Stage one Kickstart host into build/<host>/staged."
    )
    parser.add_argument(
        "host_name",
        help="Host name without path or suffix, for example example-vm-uki.",
    )
    return parser.parse_args()


def strip_inline_comment(value: str) -> str:
    """
    Strip simple trailing shell comments from one value.

    Args:
        value: Raw right-hand side of one assignment.

    Returns:
        Value without trailing comment when unquoted.
    """
    in_single = False
    in_double = False
    result: list[str] = []

    for char in value:
        if char == "'" and not in_double:
            in_single = not in_single
            result.append(char)
            continue

        if char == '"' and not in_single:
            in_double = not in_double
            result.append(char)
            continue

        if char == "#" and not in_single and not in_double:
            break

        result.append(char)

    return "".join(result).strip()


def normalize_value(raw_value: str) -> str:
    """
    Normalize one shell-style assignment value.

    Args:
        raw_value: Raw right-hand side of one assignment.

    Returns:
        Normalized value.
    """
    value = strip_inline_comment(raw_value)

    if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
        return value[1:-1]

    return value


def load_env_file(file_path: Path, env_map: dict[str, str]) -> None:
    """
    Load one env file into the supplied mapping.

    Args:
        file_path: Source env file.
        env_map: Mutable mapping of variable names to values.

    Raises:
        StageError: The env file contains an unsupported line.
    """
    if not file_path.is_file():
        return

    for lineno, line in enumerate(
        file_path.read_text(encoding="utf-8").splitlines(),
        start=1,
    ):
        stripped = line.strip()

        if not stripped or stripped.startswith("#"):
            continue

        match = ASSIGNMENT_RE.match(line)
        if match is None:
            raise StageError(f"{file_path}:{lineno}: unsupported env syntax")

        key = match.group(1)
        value = normalize_value(match.group(2))

        if key.startswith("KS_"):
            env_map[key] = value


def substitute_text(text: str, env_map: dict[str, str]) -> str:
    """
    Substitute only variables present in env_map.

    Args:
        text: Source text.
        env_map: Variable mapping.

    Returns:
        Rendered text.
    """

    def replace(match_obj: re.Match[str]) -> str:
        name = match_obj.group(1) or match_obj.group(2)
        if name in env_map:
            return env_map[name]
        return match_obj.group(0)

    return VAR_RE.sub(replace, text)


def stage_target(
    source_path: Path,
    repo_root: Path,
    host_name: str,
    staged_dir: Path,
) -> Path:
    """
    Map one source file to its staged target path.

    Args:
        source_path: Exact source file path.
        repo_root: Repository root directory.
        host_name: Current host name.
        staged_dir: Host-specific staged directory.

    Returns:
        Absolute staged file path.

    Raises:
        StageError: A source path is unexpected.
    """
    rel_path = source_path.relative_to(repo_root)

    if rel_path.parts[0] == "hosts":
        expected = Path("hosts") / f"{host_name}.ks"
        if rel_path != expected:
            raise StageError(f"Unexpected host source path: {rel_path}")
        return staged_dir / "host.ks"

    if rel_path.parts[0] in {"profiles", "snippets"}:
        return staged_dir / rel_path

    raise StageError(f"Unexpected staged source path: {rel_path}")


def stage_host(host_name: str) -> None:
    """
    Stage one host into build/<host>/staged.

    Args:
        host_name: Current host name.

    Raises:
        StageError: The host cannot be staged.
        ksdeps.IncludeError: The include graph is invalid.
    """
    repo_root = Path.cwd().resolve()
    host_name = ksdeps.validate_host_name(host_name)

    build_dir = repo_root / "build" / host_name
    staged_dir = build_dir / "staged"
    default_env = repo_root / "hosts" / "default.env"
    host_env = repo_root / "hosts" / f"{host_name}.env"

    source_deps = ksdeps.collect_dependencies(repo_root, host_name)

    env_map: dict[str, str] = {}
    load_env_file(default_env, env_map)
    load_env_file(host_env, env_map)

    if staged_dir.exists():
        shutil.rmtree(staged_dir)
    staged_dir.mkdir(parents=True, exist_ok=True)

    for source_path in source_deps:
        if source_path == default_env.resolve():
            continue
        if host_env.is_file() and source_path == host_env.resolve():
            continue

        target_path = stage_target(source_path, repo_root, host_name, staged_dir)
        target_path.parent.mkdir(parents=True, exist_ok=True)

        source_text = source_path.read_text(encoding="utf-8")
        rendered_text = substitute_text(source_text, env_map)
        target_path.write_text(rendered_text, encoding="utf-8")


def main() -> int:
    """
    Stage one host from the current repository.

    Returns:
        Process exit code.
    """
    args = parse_args()

    try:
        stage_host(args.host_name)
    except (StageError, ksdeps.IncludeError) as exc:
        print(f"ksstage: error: {exc}", file=sys.stderr)
        return 2

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
