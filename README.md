# Ward

Ward is one disposable Arch Linux OCI container for pi, child agents, and their
shared tmux server. A `Containerfile` builds the image and rootless Podman runs
it under `johan` through user-level systemd Quadlets. Ward is not a booted
machine: it has no internal systemd, network manager, or SSH server.

## Model

`ward.build` builds `localhost/ward:latest` from the repository. The
`Containerfile` pins the official Arch base image by dated tag and immutable
digest, then upgrades and installs packages from the Arch Linux Archive
snapshot dated 2026-07-12. Updating packages is a deliberate change to both
pins. These fixed inputs make clean reconstruction possible, but Ward does not
claim byte-for-byte-identical image output.

The container starts directly as `agent` (UID/GID 1000:1000). tmux runs in
foreground server mode as the supervised process. `/etc/tmux.conf` creates a
detached session named `ward`; the mounted user configuration is loaded after
the system configuration. Foreground mode keeps the tmux server alive even if
all sessions are closed, and the attach command recreates `ward` when needed.
If the tmux server fails, the container exits and systemd may restart it.

Only these host paths persist:

```text
/home/johan/Projects   -> /workspace
/home/johan/.pi        -> /home/agent/.pi
/home/johan/.tmux.conf -> /home/agent/.tmux.conf (read-only)
/home/johan/.zshrc     -> /home/agent/.zshrc (read-only)
/home/johan/.oh-my-zsh -> /home/agent/.oh-my-zsh (read-only)
```

Quadlet removes the container whenever its service stops. Changes elsewhere,
including caches and files under unmounted parts of `/home/agent`, disappear on
every stop or restart. Package changes belong in `Containerfile` and take
effect only after an image rebuild. The five bind sources are never copied into
the image.

Ward shares the host network namespace. It can reach host-loopback TCP and UDP
services and abstract Unix-domain sockets, and a service started in Ward
consumes the corresponding host port. Ward is therefore not a network security
boundary. PID, mount, IPC, UTS, and user namespaces remain private.

No Docker or Podman API socket, SSH agent, D-Bus socket, display socket, device,
or broad host directory is mounted. Docker is not required and its removal is
outside Ward's lifecycle.

## Prerequisites

Ward is deliberately tied to this x86_64 Arch Linux host:

- host user `johan` has UID 1000, primary GID 1001, and home `/home/johan`;
- the five bind sources above already exist with the documented types;
- `/home/johan/Projects/ward` is this repository;
- unprivileged user namespaces and cgroup v2 are available;
- `johan:100000:65536` is available in both `/etc/subuid` and `/etc/subgid`.

`install.sh` installs the Arch `podman` package if needed, adds the fixed
subordinate-ID declarations when they are absent and nonconflicting, and
enables lingering for `johan`. Lingering lets the user manager start Ward at
boot without an interactive login.

Before the first OCI install, remove any legacy nspawn Ward with its old
uninstaller. If that source is no longer available, remove the legacy service,
root, definition, and dedicated drop-in explicitly:

```sh
sudo systemctl disable --now systemd-nspawn@ward.service
sudo rm -rf --one-file-system /var/lib/machines/ward
sudo rm -f /etc/systemd/nspawn/ward.nspawn
sudo rm -rf --one-file-system \
    /etc/systemd/system/systemd-nspawn@ward.service.d
sudo systemctl daemon-reload
```

The new installer refuses to proceed while those fixed legacy paths remain.

## Install and apply

Run the lifecycle command as root; it never invokes `sudo` itself:

```sh
sudo ./install.sh
```

The script links `ward.build` and `ward.container` into
`/etc/containers/systemd/users/1000`, reloads `johan`'s user manager, and builds
the image. It restarts `ward.service` only after `ward-build.service` succeeds.
Because systemd normally propagates a required unit's restart, the script
suppresses requirement propagation for that explicit build job; ordering is
still honored. A failed build therefore leaves an already-running Ward
container intact. Re-running the script is the apply operation; Podman reuses
unchanged build layers. Nothing is reconciled inside a running container.

## Use

Run these commands as regular user `johan`.

Attach to the shared session:

```sh
podman exec --user agent --interactive --tty ward \
    tmux new-session -A -s ward
```

Open a separate zsh instead:

```sh
podman exec --user agent --interactive --tty ward /bin/zsh
```

Host and Ward share `.pi` runtime state. Do not run host and Ward pi sessions or
extension runtimes against it concurrently.

## Administration

Run user-service and Podman commands as `johan`:

```sh
systemctl --user status ward.service
systemctl --user status ward-build.service
systemctl --user restart ward.service
journalctl --user -u ward.service
journalctl --user -u ward-build.service
podman inspect ward
podman image inspect localhost/ward:latest
```

A service restart discards the old writable layer. Applying source changes is
instead done with the root lifecycle command so the image is built before Ward
is replaced.

The container drops all Linux capabilities and sets `no-new-privileges`.
Privileged tests, nested containers, FUSE, ptrace, device access, and workflows
that need setuid or file capabilities are not guaranteed. Any relaxation needs
specific review; do not use privileged mode as a workaround.

## Resource limits

`ward.container` applies the limits to the complete systemd service process
tree and also sets Podman's container PID limit:

```text
MemoryHigh=12G
MemoryMax=16G
TasksMax=4096
PidsLimit=4096
```

systemd owns startup, bounded restart behavior, shutdown, and logging. Podman's
internal restart policy is not used.

## Uninstall

`uninstall.sh` is destructive and unguarded. Run it as root:

```sh
sudo ./uninstall.sh
```

It stops Ward through `johan`'s user manager, removes only Ward's two Quadlet
links, exact container, and `localhost/ward:latest` image, then reloads the user
manager. It preserves all bind sources, unrelated Podman containers, images,
volumes and build cache, the Podman package, subordinate IDs, and lingering.
It is safe to run again when Ward is absent.

## Verification

After installation, verify the runtime before relying on it:

- Ward is rootless and processes run as UID/GID 1000:1000 inside it;
- writes in `/workspace` and `.pi` have host ownership `johan:johan`;
- the three configuration mounts reject writes;
- no unlisted host files or filesystem sockets are visible;
- host loopback, DNS, HTTPS, and host-port consumption behave as documented;
- tmux can be attached repeatedly and remains the primary workload;
- the memory and effective 4096 task/PID limits apply;
- unmounted data disappears, while the two writable bind mounts persist, after
  a restart;
- a failed build does not interrupt the currently running container;
- uninstall leaves bind sources and unrelated rootless Podman state untouched.
