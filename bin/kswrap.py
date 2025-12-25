#!/usr/bin/env python3
"""
Kickstart wrapper for version-aware flattening.

This tool reads an optional #version= header from a Kickstart entry file,
defaults to DEVEL if missing, and invokes ksflatten with the correct version.
Optionally validates the result using ksvalidator.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
import tempfile
from pathlib import Path


RE_VER = re.compile(r"^\s*#version\s*=\s*(\S+)\s*$")


class KsWrapError(RuntimeError):
    """Raised when flattening or validation fails."""


def read_version(entry: Path, default: str) -> str:
    """Return #version=... from entry file, or default if missing."""
    text = entry.read_text(encoding="utf-8", errors="strict")
    m = RE_VER.search(text)
    return m.group(1) if m else default


def run(cmd: list[str]) -> None:
    """
    Execute an external command.

    Raises CalledProcessError if the command exits with a non-zero status.
    """
    subprocess.run(cmd, check=True)


def supported_versions() -> set[str]:
    """Return the set of versions supported by ksvalidator/ksflatten."""
    cp = subprocess.run(
        ["ksvalidator", "--list"],
        check=True,
        text=True,
        capture_output=True,
    )
    return {ln.strip() for ln in cp.stdout.splitlines() if ln.strip()}


def main() -> int:
    """CLI entry point."""
    ap = argparse.ArgumentParser(
        description="Kickstart wrapper: read #version from entry (or default) and run ksflatten."
    )
    ap.add_argument("--in", dest="infile", required=True, help="Entry file (staged host file).")
    ap.add_argument("--out", dest="outfile", required=True, help="Flattened output kickstart file.")
    ap.add_argument("--version", default="", help="Version, e.g. F43, RHEL9.")
    ap.add_argument("--validate", action="store_true", help="Run ksvalidator -v <version>.")
    args = ap.parse_args()

    entry = Path(args.infile).resolve()
    out = Path(args.outfile).resolve()

    if not entry.exists():
        raise KsWrapError(f"Input does not exist: {entry}")

    out.parent.mkdir(parents=True, exist_ok=True)

    with tempfile.NamedTemporaryFile(
        prefix=out.name + ".",
        suffix=".tmp",
        dir=out.parent,
        delete=False,
    ) as tf:
        tmp_out = Path(tf.name)

    version = read_version(entry, args.version).strip()

    use_v = False
    if version:
        use_v = version in supported_versions()

    cmd = ["ksflatten"]
    if use_v:
        cmd += ["-v", version]
    cmd += ["-c", str(entry), "-o", str(tmp_out)]
    run(cmd)

    if args.validate and version:
        run(["ksvalidator", "-v", version, str(tmp_out)])
    elif args.validate and not version:
        # optional: validate without -v, or skip
        run(["ksvalidator", str(tmp_out)])

    tmp_out.replace(out)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KsWrapError as e:
        print(f"kswrap: error: {e}", file=sys.stderr)
        raise SystemExit(2) from e
    except subprocess.CalledProcessError as e:
        # Preserve tool stderr output; just add context.
        print(
            f"kswrap: error: command failed with exit code {e.returncode}: {e.cmd}",
            file=sys.stderr,
        )

        raise SystemExit(e.returncode) from e
