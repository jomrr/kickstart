# Kickstart Build System

A deterministic, dependency-aware build system for generating flattened Kickstart (`.ks`) files from modular sources, e.g. for use on `OEMDRV`-labeled USB Sticks as `ks.cfg` or with `virt-install --initrd-inject [..]`.

This repository provides a **non-recursive GNU Make–based workflow** that:

- stages host entries, profiles, and snippets,
- resolves `%include` / `%ksappend` dependencies automatically,
- handles Kickstart versions safely and explicitly,
- and rebuilds **only what is actually affected by changes**.

The goal is correctness, reproducibility, and a clean, inspectable dependency graph — not templating magic.

---

## Repository Layout

```
.
├── hosts/            # Host entry Kickstart files (one per host)
│   ├── example0.ks
│   ├── example1.ks
│   └── example2.ks
├── profiles/         # Reusable Kickstart profiles
│   └── fedora-vm-btrfs.ks
├── snippets/         # Reusable Kickstart snippets
│   ├── common-base.ks
│   └── common-users.ks
├── bin/
│   ├── ksdeps.py     # Dependency graph generator
│   └── kswrap.py     # Version-aware ksflatten wrapper
├── build/            # Generated staging + dependency files (do not edit)
│   ├── hosts/
│   ├── profiles/
│   ├── snippets/
│   └── deps/
├── dist/             # Final flattened Kickstart files
└── Makefile
```

---

## Build Model

### Entry Points

Each file in `hosts/*.ks` is a build target:

```bash
make example1
```

Produces:

```
dist/example1.ks
```

---

### Profiles and Snippets

- **Profiles** (`profiles/*.ks`) define reusable system classes.
- **Snippets** (`snippets/*.ks`) provide fine-grained building blocks.
- Both are staged globally into `build/` and shared across all hosts.

---

### Dependency Resolution

- `%include` and `%ksappend` directives are parsed by `bin/ksdeps.py`
- A per-host dependency fragment is generated in:

```
build/deps/<host>.mk
```

- GNU Make uses this fragment to decide exactly when a rebuild is required

There is no recursive Make and no implicit dependency guessing.

---

## Version Handling

Kickstart versions are read from the optional header:

```text
#version=F42
```

`bin/kswrap.py` applies strict rules:

- No version header → `ksflatten` is called *without* `-v`
- Unsupported version (e.g. `DEVEL`) → `-v` is omitted
- Supported version → `ksflatten -v <version>` is used

This prevents invalid defaults and avoids breakage.

---

## Validation

Kickstart validation via `ksvalidator` is optional.

Enabled by default:

```bash
make example1
```

Disabled explicitly:

```bash
make example1 VALIDATE=0
```

---

## Cleaning Targets

```bash
make clean      # removes dist/
make distclean  # removes build/ and dist/
```

---

## Design Goals

- Explicit file-based dependencies
- Minimal rebuilds
- Deterministic output
- Readable Make dependency graph
- No recursive Make
- No hidden templating logic

If Make rebuilds something, it does so for a concrete and inspectable reason.

---

## Requirements

- GNU Make
- Python ≥ 3.10
- pykickstart (`ksflatten`, `ksvalidator`)
- POSIX-compatible environment

---

## License

MIT License
