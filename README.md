# Ward

Ward is one Arch Linux `systemd-nspawn` machine for pi, its child agents, and
their shared tmux server.

```text
/home/johan/Projects  -> /workspace
/home/johan/.pi       -> /home/agent/.pi
```

Everything else lives in `/var/lib/machines/ward`.

## Install

Run from this repository. Nothing runs automatically.

```sh
sudo pacman -S --needed arch-install-scripts systemd
sudo mkdir -p /var/lib/machines/ward
sudo pacstrap -K /var/lib/machines/ward $(< packages.txt)

sudo systemd-firstboot \
  --root=/var/lib/machines/ward \
  --hostname=ward \
  --locale=en_US.UTF-8 \
  --timezone=Europe/Amsterdam

sudo systemd-nspawn -D /var/lib/machines/ward \
  useradd --uid 1000 --user-group --create-home --shell /bin/bash agent

sudo mkdir -p \
  /var/lib/machines/ward/workspace \
  /var/lib/machines/ward/home/agent/.pi
sudo chown 1000:1000 \
  /var/lib/machines/ward/workspace \
  /var/lib/machines/ward/home/agent/.pi
```

The mount-point ownership is required by `owneridmap`.

Install root-owned copies of the definitions into systemd:

```sh
sudo install -Dm644 ward.nspawn /etc/systemd/nspawn/ward.nspawn
sudo install -Dm644 resources.conf \
  /etc/systemd/system/systemd-nspawn@ward.service.d/resources.conf

sudo systemctl daemon-reload
```

## Use

```sh
sudo systemctl start systemd-nspawn@ward.service
machinectl shell agent@ward /usr/bin/tmux new-session -A -s ward
```

Administration:

```sh
machinectl shell root@ward
machinectl status ward
journalctl -u systemd-nspawn@ward.service
sudo systemctl stop systemd-nspawn@ward.service
```

Host and container pi share `.pi`. Do not use the same session or extension
runtime files concurrently.

## Rebuild

This deletes the machine root, including `/home/agent` except for the mounted
`.pi`. Projects and `.pi` remain on the host.

```sh
sudo systemctl stop systemd-nspawn@ward.service
sudo rm -rf --one-file-system /var/lib/machines/ward
```

Repeat the installation steps.

## Verify

Before relying on Ward, confirm mapped-mount ownership, isolation from unrelated
host files and sockets, outbound DNS and HTTPS, and the configured resource
limits. `owneridmap` requires kernel and filesystem support for id-mapped mounts.
