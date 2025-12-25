#!/usr/bin/env python3
"""
Generate Makefile dependency fragments for Kickstart %include/%ksappend graphs.
"""
from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlparse

# Parse Kickstart directives that pull other files into the graph.
RE = re.compile(r"^\s*%(include|ksappend)\s+(\S+)\s*$")


@dataclass
class WalkContext:
    """Shared context for walking the Kickstart include dependency graph."""
    cwd: Path
    build_dir: Path
    deps_out: set[Path]


def is_url(s: str) -> bool:
    """
    Return True if the given string looks like an absolute URL.

    A string is considered a URL if it has a scheme and network location
    as parsed by urllib.parse.urlparse().
    """
    u = urlparse(s)
    return bool(u.scheme and u.netloc)


class IncludeError(Exception):
    """Raised when a Kickstart %include or %ksappend cannot be resolved."""


def resolve_source_for_logical_include(child_ks: Path) -> Path:
    """
    Resolve a logical include path to a *source* file we can read for recursion.

    Convention:
      - Kickstart includes reference *.ks (logical include path).
      - The repository may store either:
          - snippets/foo.ks        (plain file)
          - snippets/foo.ks.in     (templated file)
        In that case, the logical include is snippets/foo.ks and the source to read
        is either foo.ks (preferred) or foo.ks.in (fallback).
    """
    if child_ks.exists():
        return child_ks

    # If the logical include does not exist, allow a .in template as source-of-truth.
    child_in = child_ks.with_suffix(child_ks.suffix + ".in")  # foo.ks -> foo.ks.in
    if child_in.exists():
        return child_in

    raise IncludeError(f"Missing include file: {child_ks} (or template {child_in})")


def normalize_inc(parent: Path, inc: str, cwd: Path) -> Path:
    """
    Normalize an include path found in a file.

    Policy:
      - No URLs
      - No absolute paths
      - Paths are either:
          * repo-root relative (preferred) for well-known top-level dirs like
            snippets/, profiles/, hosts/
          * or file-parent relative for everything else (portable for local includes)
    """
    if is_url(inc):
        raise IncludeError(f"URL not allowed in source includes/ksappends: {inc}")
    if inc.startswith("/"):
        raise IncludeError(f"Absolute path not allowed in source includes/ksappends: {inc}")

    # Treat these as repo-root relative paths to avoid "../" gymnastics in templates.
    if inc.startswith(("snippets/", "profiles/", "hosts/")):
        return (cwd / inc).resolve()

    # Default: resolve relative to including file's directory.
    return (parent / inc).resolve()


def staged_target_for_logical_include(child_ks: Path, cwd: Path, build_dir: Path) -> Path:
    """
    Map a logical include path (e.g., snippets/foo.ks) to its staged build target
    (e.g., build/snippets/foo.ks).

    For safety, only map paths that are within the repo checkout.
    """
    rel_path = child_ks.resolve().relative_to(cwd.resolve())
    return (build_dir / rel_path).resolve()


def walk(file_src: Path, ctx: WalkContext, stack: list[Path]) -> None:
    """Walk the %include/%ksappend dependency graph starting from file_src."""
    file_src = file_src.resolve()

    if file_src in stack:
        cycle = " -> ".join(p.name for p in (stack + [file_src]))
        raise IncludeError(f"Include cycle detected: {cycle}")

    if not file_src.exists():
        raise IncludeError(f"Missing include file: {file_src}")

    stack.append(file_src)

    text = file_src.read_text(encoding="utf-8", errors="strict")
    for lineno, line in enumerate(text.splitlines(), start=1):
        m = RE.match(line)
        if not m:
            continue

        inc_raw = m.group(2)

        try:
            child_logical = normalize_inc(file_src.parent, inc_raw, ctx.cwd)
        except IncludeError as e:
            raise IncludeError(f"{file_src}:{lineno}: {e}") from e

        try:
            child_logical.resolve().relative_to(ctx.cwd.resolve())
        except ValueError as e:
            raise IncludeError(
                f"{file_src}:{lineno}: Include escapes repo root: {child_logical}"
            ) from e

        ctx.deps_out.add(
            staged_target_for_logical_include(child_logical, ctx.cwd, ctx.build_dir)
        )

        try:
            child_src = resolve_source_for_logical_include(child_logical)
            walk(child_src, ctx, stack)
        except IncludeError as e:
            raise IncludeError(f"{file_src}:{lineno}: {e}") from e

    stack.pop()


def main() -> int:
    """
    Generate a Makefile dependency fragment for a Kickstart profile.

    Walks the %include/%ksappend graph starting from the given profile source,
    resolves logical includes to staged build targets under the build directory,
    and emits a Makefile fragment that attaches all required dependencies to the
    specified target.
    """
    ap = argparse.ArgumentParser(
        description="Generate a Make include (.mk) for Kickstart %include/%ksappend dependencies."
    )
    ap.add_argument("--profile", required=True, help="Kickstart profile source (entry point), typically *.ks.in")
    ap.add_argument("--target", required=True, help="Make target to attach dependencies to (e.g. dist/*.ks).")
    ap.add_argument("--out-mk", required=True, help="Output Make fragment path (e.g. build/deps/*.mk).")
    ap.add_argument("--cwd", default=".", help="Repository root for relative path emission.")
    ap.add_argument(
        "--build-dir",
        required=True,
        help="Build directory root (e.g. build). Staged targets are emitted under this directory.",
    )
    args = ap.parse_args()

    cwd = Path(args.cwd).resolve()
    build_dir = Path(args.build_dir).resolve()
    profile_src = Path(args.profile).resolve()
    out_mk = Path(args.out_mk).resolve()

    # Walk include graph from profile source.
    ctx = WalkContext(
        cwd=cwd,
        build_dir=build_dir,
        deps_out=set(),
    )
    walk(profile_src, ctx, [])

    # add staged entry file itself as dependency
    try:
        prof_rel = profile_src.resolve().relative_to(cwd.resolve())
    except ValueError as e:
        raise IncludeError(f"Profile is outside repo root: {profile_src}") from e

    ctx.deps_out.add((build_dir / prof_rel).resolve())

    deps_sorted = sorted(ctx.deps_out, key=str)
    deps_line = " ".join(str(p) for p in deps_sorted)
    content = f"{args.target}: {deps_line}\n"

    out_mk.parent.mkdir(parents=True, exist_ok=True)
    out_mk.write_text(content, encoding="utf-8")

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except IncludeError as e:
        print(f"ksdeps: error: {e}", file=sys.stderr)
        raise SystemExit(2) from e
