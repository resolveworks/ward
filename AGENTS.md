# AGENTS.md

Ward defines one disposable Arch Linux image and one rootless Podman container
for pi and its shared tmux server.

## Authorities

- `Containerfile`: image, packages, accounts, and foreground process
- `.containerignore`: build context
- `ward.build`: image build
- `ward.container`: runtime, mounts, isolation, and limits
- `README.md`: host requirements and operation

Use the standard host, systemd, and Podman commands in `README.md`; Ward has no
custom lifecycle tooling.

## Invariants

- Ward runs through user-level systemd and rootless Podman as host user `johan`
  (UID 1000, primary GID 1001).
- The container runs as `agent` (UID/GID 1000:1000) with the explicit identity
  and `keep-id` mapping in `ward.container`.
- Persistence is limited to the five documented mounts. The three shell and
  tmux configuration mounts remain read-only.
- Ward uses host networking while PID, mount, IPC, UTS, and user namespaces
  remain private.
- The container drops all capabilities, uses `no-new-privileges`, and keeps the
  limits in `ward.container`.
- The writable container root is discarded on every stop.
- tmux remains the foreground process and creates the initial session `ward`.
- Quadlet and systemd own builds, startup, restarts, shutdown, and logging.
- Apply builds before restart and uses `--job-mode=ignore-requirements`, so a
  failed build leaves the running container intact.

## Changes

Keep image packages in the single `pacman -Syu` transaction in
`Containerfile`. Update the dated Arch base tag and digest together with the
Arch Linux Archive snapshot.

Keep runtime configuration in `ward.container`, and update `README.md` when
requirements or user-facing behavior change. Preserve unrelated working-tree
changes and keep secrets, host state, container storage, and `.pi` contents out
of the repository.

## Safety and validation

Host changes, builds, containers, and systemd operations require explicit user
permission. Safe static checks are:

```sh
git diff --check
QUADLET_UNIT_DIRS="$PWD" \
    /usr/lib/systemd/system-generators/podman-system-generator \
    -user -dryrun
git diff
```

Use the generator only when installed. State which host and runtime checks were
not performed.
