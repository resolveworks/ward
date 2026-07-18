# AGENTS.md

Ward is one opinionated Arch Linux image and one rootless Podman container for
pi and its tmux server. It is an exact environment, not a portable framework.

## Approach

Assume an experienced Arch Linux operator. Keep documentation terse and
command-oriented; document Ward's contract, not generic Arch, Podman, systemd,
or tmux usage.

Prefer explicit assumptions and immediate failures. Do not add compatibility
layers, prerequisite probes, fallback behavior, silent recovery, or friendly
wrappers around the underlying tools. A missing requirement or inconsistent
state should fail at the command that encounters it with its native diagnostic.

Do not describe Ward as a personal project. Keep the repository suitable for
outside contributions without broadening its scope or supported environments.

## Authorities

- `Containerfile`: image, packages, accounts, and foreground process
- `.containerignore`: build context
- `ward.build`: image build
- `ward.container`: runtime, mounts, isolation, and limits
- `README.md`: contract and commands

Ward has no custom lifecycle tooling; use the host, systemd, and Podman commands
in `README.md`.

## Invariants

- User systemd and rootless Podman own the lifecycle.
- The container identity is `agent` (1000:1000) under `keep-id`.
- Only the mounts declared in `ward.container` are exposed; `/opt`, shell
  configuration, and tmux configuration are read-only.
- Networking is shared with the host. PID, mount, IPC, UTS, and user namespaces
  remain private.
- All capabilities are dropped and `no-new-privileges` remains enabled.
- The writable root is discarded on stop.
- tmux is the foreground process and creates session `ward`.
- Apply builds first; a failed build leaves the running container untouched.

## Changes

Keep packages in the single `pacman -Syu` transaction. Update the Arch base tag,
digest, and Archive snapshot together.

Keep runtime policy in `ward.container`. Update `README.md` only for changes to
the contract or commands. Never commit secrets, host state, container storage,
or `.pi` contents. Preserve unrelated working-tree changes.

## Validation

Do not modify the host or run builds, containers, or systemd without explicit
permission. Static checks are:

```sh
git diff --check
QUADLET_UNIT_DIRS="$PWD" \
    /usr/lib/systemd/system-generators/podman-system-generator \
    -user -dryrun
git diff
```

Run the generator only when installed. Report omitted host and runtime checks.
