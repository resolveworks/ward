# Ward

Ward is one long-lived Arch Linux `systemd-nspawn` machine for pi, its child
agents, and their shared tmux server.

This repository is only the machine definition. Nothing from it is copied into
the machine. `/home/johan/Projects` is bind-mounted read-write at `/workspace`.
Everything else, including the agent's ordinary `/home/agent`, lives in the
machine root at `/var/lib/machines/ward`.

## Files

- `ward.nspawn` — mounts, user namespace, and networking
- `resources.conf` — memory and process limits
- `packages.txt` — packages installed in the disposable Arch root

The checked-in paths and limits are intentionally concrete. Edit them before
installing Ward on a computer with a different username, checkout location, or
amount of memory.

## Install

These commands are documentation; this repository does not run them
automatically.

Install the host tools:

```sh
sudo pacman -S --needed arch-install-scripts systemd-container
```

Create the container root:

```sh
sudo install -d /var/lib/machines/ward
sudo pacstrap -K /var/lib/machines/ward $(< packages.txt)
```

Initialize the root and create the unprivileged user. The `/workspace` mount
point must be owned by `agent` for the `owneridmap` bind in `ward.nspawn`.

```sh
sudo systemd-firstboot \
  --root=/var/lib/machines/ward \
  --hostname=ward \
  --locale=en_US.UTF-8 \
  --timezone=Europe/Amsterdam

sudo systemd-nspawn -D /var/lib/machines/ward \
  /usr/sbin/useradd --uid 1000 --user-group --create-home \
  --shell /bin/bash agent

sudo install -d -o 1000 -g 1000 /var/lib/machines/ward/workspace
```

Link the definitions into the locations read by systemd:

```sh
sudo install -d /etc/systemd/nspawn
sudo ln -s /home/johan/Projects/ward/ward.nspawn \
  /etc/systemd/nspawn/ward.nspawn

sudo install -d /etc/systemd/system/systemd-nspawn@ward.service.d
sudo ln -s /home/johan/Projects/ward/resources.conf \
  /etc/systemd/system/systemd-nspawn@ward.service.d/resources.conf

sudo systemctl daemon-reload
```

## Use

Start Ward and attach to its tmux session:

```sh
sudo systemctl start systemd-nspawn@ward.service
machinectl shell agent@ward /usr/bin/tmux new-session -A -s ward
```

Other useful commands:

```sh
machinectl shell agent@ward             # ordinary agent shell
machinectl shell root@ward              # administrative shell
machinectl status ward
journalctl -u systemd-nspawn@ward.service
sudo systemctl stop systemd-nspawn@ward.service
```

Install pi, its extensions, provider credentials, and project-specific
toolchains from inside Ward. Their user state belongs in `/home/agent`. Add
required system packages to `packages.txt` so the environment is documented.

## Networking

`ward.nspawn` creates a virtual Ethernet link. Normal outbound networking
requires the host to configure and masquerade that link; systemd-networkd does
this with its standard container network configuration. Verify outbound DNS and
HTTPS before installing pi. Do not change to host networking merely to work
around an unconfigured veth without considering access to host-local services.

## Rebuild

The agent home is part of the machine root. Deleting the root therefore also
deletes pi state, credentials, configuration, and caches. Back up anything you
want to retain before rebuilding:

```sh
sudo systemctl stop systemd-nspawn@ward.service
sudo rm -rf --one-file-system /var/lib/machines/ward
```

The bind-mounted project tree is not deleted with the machine root.

## Before relying on it

Confirm on the installed system that:

- `agent` can create and edit files in `/workspace` and `/home/agent`;
- created project files have the expected host ownership;
- container root cannot access unrelated host paths;
- host SSH, browser, cloud, and container-engine sockets are absent;
- outbound DNS and HTTPS work;
- `MemoryMax` and `TasksMax` contain deliberate stress tests.

The `owneridmap` mounts require filesystem and kernel support for id-mapped
mounts. They intentionally map the owner of each container mount point to the
owner of its host source instead of identity-mapping the container's full UID
range. Test this ownership model before placing important work in the machine.
