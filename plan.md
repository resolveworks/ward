# Ward OCI Migration Plan

## Goal

Replace the mutable systemd-nspawn machine with one immutable Arch Linux OCI
image and one rootless Podman container. Quadlet and `johan`'s user systemd
manager own image builds, boot startup, restart behavior, logging, shutdown, and
resource controls. The tmux server is the supervised foreground process.

## Declarations

- `Containerfile` pins an official dated Arch base by digest, uses a matching
  Arch Linux Archive snapshot, installs all packages, creates `agent` as
  UID/GID 1000:1000, configures locale and timezone, and starts tmux.
- `ward.build` builds `localhost/ward:latest` from the fixed repository path.
- `ward.container` runs the image with `keep-id`, host networking, five bind
  mounts, no added privileges, and fixed memory/task limits.
- `install.sh` bootstraps fixed host prerequisites and performs build-before-
  restart apply.
- `uninstall.sh` removes only Ward's Quadlets, container, and image.

No SSH server, internal systemd, network manager, Ansible, nspawn, guest
reconciliation, runtime package installation, nested container engine, or
container API socket is part of Ward.

## Persistence and identity

The only durable paths are `/home/johan/Projects`, `/home/johan/.pi`, and the
read-only `.tmux.conf`, `.zshrc`, and `.oh-my-zsh` mounts documented in
`README.md`. Everything else in the container writable layer is removed on a
service stop.

Host `johan` is UID 1000 with primary GID 1001. Rootless Podman maps that host
identity to container `agent` UID/GID 1000:1000 with
`UserNS=keep-id:uid=1000,gid=1000`. The fixed subordinate UID/GID range is
`100000:65536`.

## Apply safety

An apply reloads the user manager, restarts `ward-build.service` without
propagating that explicit restart through its requirement edge, waits for a
successful image build, and only then restarts `ward.service`. Ordering remains
honored. Podman assigns the local image tag only after a successful build, so
build failure leaves the running old container and image intact.

Legacy nspawn state is not migrated. It must be removed before the first OCI
install, and the installer rejects its fixed root and definition paths.

## Validation gates

Safe static validation precedes host mutation:

```sh
bash -n install.sh uninstall.sh
git diff --check
QUADLET_UNIT_DIRS="$PWD" \
    /usr/lib/systemd/system-generators/podman-system-generator \
    -user -dryrun
git diff
```

Image builds, service startup, lifecycle scripts, and runtime acceptance tests
run only with explicit user permission. Acceptance covers rootless identity and
ownership translation, exact mounts and read-only enforcement, namespace and
socket isolation, host network consequences, tmux attachment, resource limits,
writable-layer disposal, boot startup through lingering, failed-build safety,
and exact uninstall behavior.
