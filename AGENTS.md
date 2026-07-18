# AGENTS.md

## Purpose

Ward defines one disposable Arch Linux OCI image and one rootless Podman
container for pi, child agents, and their shared tmux server. `Containerfile`
defines the unmounted filesystem, while user-level systemd Quadlets build and
run it under host user `johan`.

Only these host bind mounts persist:

```text
/home/johan/Projects   -> /workspace
/home/johan/.pi        -> /home/agent/.pi
/home/johan/.tmux.conf -> /home/agent/.tmux.conf (read-only)
/home/johan/.zshrc     -> /home/agent/.zshrc (read-only)
/home/johan/.oh-my-zsh -> /home/agent/.oh-my-zsh (read-only)
```

The image and container writable layer are disposable. A clean uninstall and
install must reconstruct Ward from this repository, the pinned official Arch
image, the declared Arch package snapshot, and the bind sources. Runtime state
outside the allowlisted mounts is never a provisioning input.

## Repository contents

- `Containerfile` declares packages, accounts, system configuration, and the
  foreground process.
- `.containerignore` limits the OCI build context.
- `ward.build` declares the Quadlet image build.
- `ward.container` declares runtime, mounts, hardening, and resource limits.
- `install.sh` and `uninstall.sh` are fixed host lifecycle boundaries.
- `README.md` documents operation and security consequences.
- `plan.md` records architecture and validation intent.

Do not add provisioning frameworks, guest reconcilers, or compatibility files.
Packages have one authority (`Containerfile`) and runtime limits have one
authority (`ward.container`).

## Rules

- Preserve rootless Podman execution under host user `johan` (UID 1000,
  primary GID 1001), user-level systemd, and lingering startup.
- Preserve container user and group `agent` as UID/GID 1000:1000 and the
  explicit `UserNS=keep-id:uid=1000,gid=1000`, `User=1000`, and `Group=1000`
  declarations. Do not run Ward as root or depend on privilege escalation in
  the image.
- Preserve shared host networking. Ward reaches host loopback and abstract
  Unix-domain sockets, and its services consume host ports. Keep this risk
  visible in `README.md`; Ward is not a network security boundary.
- Preserve the exact five-path bind allowlist and all read-only modes. Never
  mount a host home broadly, Docker or Podman socket, SSH-agent socket, D-Bus
  socket, display socket, device, or broad `/run` path.
- Keep every Ward package explicit in the single `pacman -Syu` transaction in
  `Containerfile`. Pin the official Arch base by dated tag and digest and use a
  deliberate Arch Linux Archive snapshot. Update those inputs together and do
  not claim byte-for-byte reproducibility unless it is demonstrated.
- Never run `pacman`, create users, or reconcile files when the container
  starts. Package removal is image replacement, not presence-only
  reconciliation. Project-specific dependencies belong to their projects.
- Keep tmux in foreground server mode as the supervised container process and
  preserve the initial session named `ward` unless requirements materially
  change. Do not use an init system, SSH daemon, or `sleep infinity` to keep
  Ward alive.
- Use Quadlet and systemd for build dependencies, boot startup, restart policy,
  shutdown, logging, and resource controls. Build must succeed before apply
  restarts a running Ward. Preserve the explicit apply-time suppression of
  `Requires=` restart propagation; otherwise restarting the active build unit
  also restarts Ward before the build has succeeded.
- Preserve private PID, mount, IPC, UTS, and user namespaces. Do not add
  capabilities, devices, privileged mode, host PID/IPC, or socket mounts.
  Security relaxations must be narrow, justified, tested, and documented.
- Keep the container root writable while running but expendable on every stop.
  Do not add named volumes or other persistence without an explicit design
  change.
- Keep lifecycle scripts idempotent, fail-fast, noninteractive, and specific to
  the fixed host paths and identities. They require root and must not invoke
  `sudo` internally. Use arrays, quote expansions, avoid evaluated command
  strings, and keep destructive targets exact.
- Host scripts may install Podman, validate or add only the fixed subordinate-ID
  ranges, enable lingering, deploy the two Quadlets, and control `johan`'s user
  manager. They must not execute configuration commands inside Ward or use
  root's Podman storage.
- Uninstall remains destructive, unguarded, and idempotent. It removes only
  Ward's generated service/container and exact image. Never prune or reset
  unrelated Podman images, containers, volumes, storage, or build cache. Keep
  the Podman package, subordinate IDs, lingering, and all bind sources.
- Do not add nspawn, Ansible, SSH, internal systemd, mutable-machine migration,
  Docker dependencies, or compatibility paths. Legacy nspawn removal remains a
  documented manual cutover prerequisite, not installer migration logic.
- Update `README.md` whenever packages, base/snapshot pins, mounts, identity,
  networking, hardening, limits, process model, or lifecycle behavior changes.
  Wrap prose near 80 columns and use fenced `sh` blocks for commands.
- Do not overwrite unrelated working-tree changes or add secrets, host
  configuration contents, container storage, or files from `/home/johan/.pi`.

## Safety and validation

Do not run `sudo`, `pacman`, either lifecycle script, Podman builds, Ward
containers, `systemctl`, `loginctl`, stress tests, or privileged host changes
without explicit permission.

Safe static checks include:

```sh
bash -n install.sh uninstall.sh
git diff --check
git diff
QUADLET_UNIT_DIRS="$PWD" \
    /usr/lib/systemd/system-generators/podman-system-generator \
    -user -dryrun
```

Use the installed Quadlet generator only when present. Inspect generated units
for the build dependency, rootless user mapping, exact mounts, host networking,
resource limits, restart behavior, and absence of privileged or socket access.
A suitable already-installed Containerfile linter may be used, but do not add a
framework solely for linting.

Image builds and runtime acceptance checks require explicit permission. The
user must verify ownership translation, read-only mounts, filesystem and socket
isolation, host-loopback and port behavior, outbound DNS/HTTPS, tmux attachment,
writable-layer disposal, resource limits, failed-build safety, boot startup,
and exact uninstall behavior. State which host and runtime checks were not
performed.
