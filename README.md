# Kickstart Build System

A deterministic, dependency-aware build system for generating flattened Kickstart (`.ks`) files from modular sources and host-specific variables, e.g. for use on `OEMDRV`-labeled USB sticks as `ks.cfg` or with `virt-install --initrd-inject [..]`.

This repository provides a **non-recursive GNU Make–based workflow** that:

- stages host entries, profiles, and snippets into a **host-specific build tree**,
- resolves `%include` / `%ksappend` dependencies automatically,
- renders `KS_*` variables from `hosts/default.env` and optional `hosts/<host>.env`,
- flattens the staged tree with `ksflatten`,
- optionally validates the final result with `ksvalidator`,
- and rebuilds **only what is actually affected by changes**.

The goal is correctness, reproducibility, and a clean, inspectable dependency graph.

---

## Repository Layout

```text
.
├── hosts/                     # Host entry Kickstart files and host-specific variables
│   ├── default.env
│   ├── example-vm-core-grub.env
│   ├── example-vm-core-grub.ks
│   └── example-vm-uki-direct.ks
├── profiles/                  # Reusable Kickstart profiles
│   └── fedora/
│       ├── kvm-intel-btrfs-core-grub.ks
│       ├── vm-btrfs-core-grub.ks
│       ├── vm-btrfs-uki-direct.ks
│       ├── vm-luks-btrfs-core-grub.ks
│       ├── vm-luks-btrfs-core-sdboot.ks
│       └── vm-luks-btrfs-uki-direct.ks
├── snippets/                  # Reusable building blocks split by concern
│   ├── bootloader/
│   ├── packages/
│   ├── post/
│   │   ├── boot/
│   │   ├── dnf/
│   │   ├── hardening/
│   │   ├── kvm/
│   │   ├── network/
│   │   └── tpm/
│   ├── storage/
│   └── common.ks
├── bin/
│   ├── ksdeps.py              # Dependency graph generator for %include / %ksappend
│   ├── ksflatten.sh           # Host-specific ksflatten / ksvalidator wrapper
│   ├── ksstage.sh             # Host-specific staging + envsubst wrapper
│   └── test.sh                # Local virt-install test helper
├── build/                     # Generated host-specific staging trees (do not edit)
├── dist/                      # Final flattened Kickstart files
└── Makefile
```

---

## Build Model

### Entry Points

Each file in `hosts/*.ks` is a build target:

```bash
make example-vm-core-grub
```

Produces:

```
dist/example-vm-core-grub.ks
```

Build all host entries:

```bash
make all
```

---

### Profiles and Snippets

- **Hosts** in `hosts/*.ks` are the entry points for concrete builds.
- **Profiles** (`profiles[/..]/*.ks`) define reusable system classes.
- **Snippets** (`snippets/*.ks`) provide fine-grained building blocks.
- All sources are staged into a **host-specific build tree** under `build/<host>/`.

For a host called example-vm-core-grub, the staged layout looks like this:

```
build/example-vm-core-grub/
├── deps.mk
├── host.ks
├── profiles/
└── snippets/
```

This keeps builds isolated per host and makes the generated dependency graph easy to inspect.

---

### Dependency Resolution

- `%include` and `%ksappend` directives are parsed recursively by `bin/ksdeps.py`
- A host-specific dependency fragment is generated at:

```
build/<host>/deps.mk
```

- GNU Make includes only the dependency fragments needed for the requested targets.
- Includes can be written relative to the including file or root-relative below `hosts/`, `profiles/`, or `snippets/`.
- URLs, absolute paths, repository escapes, include cycles, and references to other host entry files below `hosts/` are rejected.

There is no recursive Make and no implicit dependency guessing.

---

## Environment Rendering

Staging is handled by `bin/ksstage.sh`.

- `hosts/default.env` is loaded first when present.
- `hosts/<host>.env` is loaded afterwards when present.
- Only currently defined variables matching `KS_*` are passed to envsubst.
- If no environment files exist, or if no `KS_*` variables are defined, the source file is copied unchanged.

This allows host-specific values such as disk names, passwords, kernel command line fragments, or hostnames to be injected without turning the repository into a full template engine.

---

## Version Handling

Kickstart versions are read from the optional header in the staged host entry:

```text
#version=F42
```

`bin/ksflatten.sh` applies strict rules:

- No version header → fall back to `DEVEL`
- explicit header present → use that value for `ksflatten` and `ksvalidator`
- flattening is executed from inside `build/<host>/` so staged relative includes resolve correctly

This keeps version selection explicit while avoiding hidden defaults inside the Makefile.

---

## Validation

Kickstart validation via `ksvalidator` is optional and enabled by default.

Enabled by default:

```bash
make example-vm-core-grub
```

Disabled explicitly:

```bash
make example-vm-core-grub VALIDATE=0
```

For local installation testing, the repository also provides VM test targets for example hosts:

```bash
make test
make test-example-vm-core-grub
```

`bin/test.sh` boots a Fedora installer via virt-install, injects the generated Kickstart file into the initrd, enables UEFI Secure Boot, and attaches a software TPM. This is intended for local validation of the example host definitions.

---

## Cleaning Targets

```bash
make clean      # removes dist/
make distclean  # removes build/ and dist/
make mrproper   # alias for distclean
```

---

## Design Goals

- Explicit file-based dependencies
- Minimal rebuilds
- Deterministic output
- Host-specific isolated staging trees
- Readable Make dependency graph
- Atomic file publication for generated artifacts
- No recursive Make
- No hidden templating logic beyond controlled KS_* substitution

If Make rebuilds something, it does so for a concrete and inspectable reason.

---

## Requirements

- GNU Make
- Bash
- gettext / envsubst
- Python ≥ 3.10
- pykickstart (`ksflatten`, `ksvalidator`)
- POSIX-compatible environment

For local VM testing via `make test`:

- libvirt / KVM
- OVMF
- swtpm
- virt-install

---

## License

MIT License
