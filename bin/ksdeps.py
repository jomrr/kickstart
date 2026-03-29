#!/usr/bin/env python3
"""
Generate Makefile dependency fragments for Kickstart %include/%ksappend graphs.

The tool walks the include graph of a Kickstart host entry, resolves logical
include paths, maps them to host-specific staged build targets under
build/<host>/staged/..., and emits a Makefile fragment with two rules:

1. A self-dependency for build/<host>/deps.mk on the current source graph.
2. A dependency for dist/<host>.ks on the staged host-specific build graph.

All paths emitted into the Makefile fragment are absolute paths so they match a
Makefile that uses $(CURDIR)-based directory variables.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlparse

INCLUDE_DIRECTIVE_RE = re.compile(r"^\s*%(include|ksappend)\s+(\S+)\s*$")
ROOT_RELATIVE_PREFIXES = ("snippets/", "profiles/", "hosts/")


@dataclass
class WalkContext:
    """
    Shared context for walking a Kickstart include dependency graph.

    Attributes:
        cwd: Repository root directory.
        host_name: Host stem used to derive the host-specific build tree.
        build_dir: Host-specific build root, for example build/example0.
        staged_dir: Host-specific staged root, for example build/example0/staged.
        source_deps: Collected source file dependencies as absolute paths.
        staged_deps: Collected staged build targets as absolute paths.
    """

    cwd: Path
    host_name: str
    build_dir: Path
    staged_dir: Path
    source_deps: set[Path]
    staged_deps: set[Path]


class IncludeError(Exception):
    """Raised when a Kickstart %include or %ksappend cannot be resolved."""


def is_url(value: str) -> bool:
    """
    Return whether the given value appears to be an absolute URL.

    Args:
        value: Raw include value from the Kickstart file.

    Returns:
        True if the value looks like an absolute URL, otherwise False.
    """
    parsed = urlparse(value)
    return bool(parsed.scheme and parsed.netloc)


def validate_host_name(host_name: str) -> str:
    """
    Validate the host name passed on the command line.

    The accepted format is a plain stem without path separators and without a
    '.ks' suffix.

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


def resolve_source_for_logical_include(child_ks: Path) -> Path:
    """
    Resolve a logical include path to the source file used for recursive parsing.

    Resolution policy:
    - Prefer the logical file itself, for example: snippets/foo.ks
    - Fall back to a templated source file, for example: snippets/foo.ks.in

    Args:
        child_ks: Logical include path ending in .ks.

    Returns:
        The existing source file path used for recursion.

    Raises:
        IncludeError: The logical include and its .in fallback are both missing.
    """
    if child_ks.exists():
        return child_ks.resolve()

    child_template = child_ks.with_suffix(f"{child_ks.suffix}.in")
    if child_template.exists():
        return child_template.resolve()

    raise IncludeError(
        f"Missing include file: {child_ks} "
        f"(or template fallback {child_template})"
    )


def normalize_include_path(parent_dir: Path, include_value: str, cwd: Path) -> Path:
    """
    Normalize an include path found in a Kickstart file.

    Policy:
    - URLs are rejected.
    - Absolute paths are rejected.
    - Includes below well-known top-level directories are resolved relative to
      the repository root.
    - All other includes are resolved relative to the including file.

    Args:
        parent_dir: Directory of the including file.
        include_value: Raw include argument from the Kickstart directive.
        cwd: Repository root directory.

    Returns:
        The normalized absolute path for the logical include.

    Raises:
        IncludeError: The include is a URL or absolute path.
    """
    if is_url(include_value):
        raise IncludeError(
            f"URL not allowed in source includes/ksappends: {include_value}"
        )

    if include_value.startswith("/"):
        raise IncludeError(
            f"Absolute path not allowed in source includes/ksappends: "
            f"{include_value}"
        )

    if include_value.startswith(ROOT_RELATIVE_PREFIXES):
        return (cwd / include_value).resolve()

    return (parent_dir / include_value).resolve()


def ensure_within_repo_root(path_value: Path, cwd: Path) -> None:
    """
    Validate that the given path is located inside the repository root.

    Args:
        path_value: Path to validate.
        cwd: Repository root directory.

    Raises:
        IncludeError: The path escapes the repository root.
    """
    try:
        path_value.resolve().relative_to(cwd.resolve())
    except ValueError as exc:
        raise IncludeError(
            f"Include escapes repository root: {path_value}"
        ) from exc


def staged_target_for_logical_include(child_ks: Path, ctx: WalkContext) -> Path:
    """
    Map a logical include path to its host-specific staged build target path.

    Examples:
        snippets/foo.ks -> /repo/build/<host>/staged/snippets/foo.ks
        profiles/base.ks -> /repo/build/<host>/staged/profiles/base.ks

    The current host entry file is staged as
    /repo/build/<host>/staged/host.ks.
    References to other files below hosts/ are rejected because the staging
    model keeps a single host entry point per host-specific build tree.

    Args:
        child_ks: Logical include path inside the repository.
        ctx: Shared walk context.

    Returns:
        Absolute staged target path under build/<host>/staged/...

    Raises:
        IncludeError: A hosts/ include references a different host file.
    """
    rel_path = child_ks.resolve().relative_to(ctx.cwd.resolve())

    if rel_path.parts[0] == "hosts":
        expected_rel = Path("hosts") / f"{ctx.host_name}.ks"
        if rel_path != expected_rel:
            raise IncludeError(
                "Only the current host entry may be referenced below hosts/: "
                f"{rel_path}"
            )
        return (ctx.staged_dir / "host.ks").resolve()

    return (ctx.staged_dir / rel_path).resolve()


def walk(file_src: Path, ctx: WalkContext, stack: list[Path]) -> None:
    """
    Walk the Kickstart %include/%ksappend dependency graph recursively.

    Args:
        file_src: Source file to inspect.
        ctx: Shared walk context.
        stack: Current include recursion stack used for cycle detection.

    Raises:
        IncludeError: A cycle is detected or an include cannot be resolved.
    """
    resolved_file = file_src.resolve()

    if resolved_file in stack:
        cycle = " -> ".join(path_item.name for path_item in (stack + [resolved_file]))
        raise IncludeError(f"Include cycle detected: {cycle}")

    if not resolved_file.exists():
        raise IncludeError(f"Missing include file: {resolved_file}")

    ctx.source_deps.add(resolved_file)
    stack.append(resolved_file)

    file_text = resolved_file.read_text(encoding="utf-8", errors="strict")
    for lineno, line in enumerate(file_text.splitlines(), start=1):
        match = INCLUDE_DIRECTIVE_RE.match(line)
        if match is None:
            continue

        include_value = match.group(2)

        try:
            child_logical = normalize_include_path(
                resolved_file.parent,
                include_value,
                ctx.cwd,
            )
            ensure_within_repo_root(child_logical, ctx.cwd)
            staged_target = staged_target_for_logical_include(child_logical, ctx)
        except IncludeError as exc:
            raise IncludeError(f"{resolved_file}:{lineno}: {exc}") from exc

        ctx.staged_deps.add(staged_target)

        try:
            child_src = resolve_source_for_logical_include(child_logical)
            walk(child_src, ctx, stack)
        except IncludeError as exc:
            raise IncludeError(f"{resolved_file}:{lineno}: {exc}") from exc

    stack.pop()


def render_make_fragment(
    depfile_path: Path,
    depfile_dependencies: set[Path],
    flat_target: Path,
    staged_dependencies: set[Path],
) -> str:
    """
    Render the final Makefile dependency fragment content.

    Args:
        depfile_path: Absolute path of the generated depfile.
        depfile_dependencies: Source dependencies that trigger depfile refresh.
        dist_target: Absolute final dist target path.
        staged_dependencies: Absolute staged build targets required for dist.

    Returns:
        Makefile fragment text with trailing newlines.
    """
    depfile_deps_sorted = sorted(depfile_dependencies, key=str)
    staged_deps_sorted = sorted(staged_dependencies, key=str)

    depfile_deps_line = " ".join(str(path_item) for path_item in depfile_deps_sorted)
    staged_deps_line = " ".join(str(path_item) for path_item in staged_deps_sorted)

    return (
        f"{depfile_path}: {depfile_deps_line}\n"
        f"{flat_target}: {staged_deps_line}\n"
    )


def write_text_atomic(path_value: Path, content: str) -> None:
    """
    Write text to a file atomically inside the destination directory.

    The content is first written to a temporary file in the destination
    directory, then published via os.replace().

    Args:
        path_value: Final destination path.
        content: Text content to write.
    """
    path_value.parent.mkdir(parents=True, exist_ok=True)

    file_descriptor: int | None = None
    tmp_path_str: str | None = None

    try:
        file_descriptor, tmp_path_str = tempfile.mkstemp(
            prefix=f".{path_value.name}.",
            suffix=".tmp",
            dir=path_value.parent,
            text=True,
        )
        with os.fdopen(file_descriptor, "w", encoding="utf-8") as handle:
            file_descriptor = None
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())

        os.replace(tmp_path_str, path_value)
        tmp_path_str = None
    finally:
        if file_descriptor is not None:
            os.close(file_descriptor)
        if tmp_path_str is not None:
            try:
                Path(tmp_path_str).unlink()
            except FileNotFoundError:
                pass


def update_output_file(out_path: Path, content: str) -> None:
    """
    Update the output Make fragment.

    Behavior:
    - If the output file already exists and the content is unchanged, the file
      is not rewritten.
    - If the content differs or the file does not exist, the file is rewritten
      atomically.
    - The output file mtime is always refreshed at the end so remade included
      Makefiles remain current from Make's point of view.

    Args:
        out_path: Output Make fragment path.
        content: Final content to persist.
    """
    existing_content: str | None = None
    if out_path.exists():
        existing_content = out_path.read_text(encoding="utf-8")

    if existing_content != content:
        write_text_atomic(out_path, content)

    out_path.touch(exist_ok=True)


def parse_args() -> argparse.Namespace:
    """
    Parse command-line arguments.

    Returns:
        Parsed argument namespace.
    """
    parser = argparse.ArgumentParser(
        description=(
            "Generate a Make include fragment for Kickstart "
            "%include/%ksappend dependencies."
        )
    )
    parser.add_argument(
        "host_name",
        help="Kickstart host name without path or suffix, for example example0.",
    )
    return parser.parse_args()


def main() -> int:
    """
    Generate a Makefile dependency fragment for a Kickstart host entry.

    Returns:
        Process exit code. Zero indicates success.

    Raises:
        IncludeError: A Kickstart include cannot be resolved safely.
    """
    args = parse_args()

    cwd = Path.cwd().resolve()
    host_name = validate_host_name(args.host_name)

    build_dir = (cwd / "build" / host_name).resolve()
    staged_dir = (build_dir / "staged").resolve()
    host_src = (cwd / "hosts" / f"{host_name}.ks").resolve()
    out_mk = (build_dir / "deps.mk").resolve()
    flat_target = (build_dir / "flat.ks").resolve()

    default_env = (cwd / "hosts" / "default.env").resolve()
    host_env = (cwd / "hosts" / f"{host_name}.env").resolve()
    ksstage_tool = (cwd / "bin" / "ksstage.sh").resolve()
    ksdeps_tool = (cwd / "bin" / "ksdeps.py").resolve()

    if not host_src.exists():
        raise IncludeError(f"Missing host entry file: {host_src}")

    ctx = WalkContext(
        cwd=cwd,
        host_name=host_name,
        build_dir=build_dir,
        staged_dir=staged_dir,
        source_deps=set(),
        staged_deps=set(),
    )

    walk(host_src, ctx, [])

    # Add the current staged host entry explicitly to the staged dependency set.
    ctx.staged_deps.add((staged_dir / "host.ks").resolve())

    depfile_dependencies = set(ctx.source_deps)
    depfile_dependencies.add(ksdeps_tool)
    depfile_dependencies.add(ksstage_tool)

    if default_env.exists():
        depfile_dependencies.add(default_env)

    if host_env.exists():
        depfile_dependencies.add(host_env)

    content = render_make_fragment(
        depfile_path=out_mk,
        depfile_dependencies=depfile_dependencies,
        flat_target=flat_target,
        staged_dependencies=ctx.staged_deps,
    )
    update_output_file(out_mk, content)

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except IncludeError as exc:
        print(f"ksdeps: error: {exc}", file=sys.stderr)
        raise SystemExit(2) from exc
