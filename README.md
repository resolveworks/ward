# Ward

Ward is a disposable Arch Linux environment for pi and its shared tmux server.
It runs as a rootless Podman container under the user systemd instance.

## Contract

Ward requires an x86_64 Arch Linux host with Podman, cgroup v2, user namespaces,
at least 65536 subordinate UIDs/GIDs, and lingering enabled.

The following paths must exist:

```text
$HOME/Projects   -> /workspace
/opt             -> /opt (read-only)
$HOME/.pi        -> /home/agent/.pi
$HOME/.tmux.conf -> /home/agent/.tmux.conf (read-only)
$HOME/.zshrc     -> /home/agent/.zshrc (read-only)
$HOME/.oh-my-zsh -> /home/agent/.oh-my-zsh (read-only)
```

No other container state persists. The container runs as `agent` (1000:1000),
drops all capabilities, and uses the limits in `ward.container`.

Networking is shared with the host. Host loopback, abstract Unix sockets, and
host ports are therefore shared as well; Ward is not a network boundary.

## Host setup

```sh
sudo pacman --needed -S podman
sudo loginctl enable-linger "$USER"
```

## Deploy

From the repository root:

```sh
install -d -m 0700 "$HOME/.config/containers/systemd"
ln -sT "$PWD" "$HOME/.config/containers/systemd/ward"
systemctl --user daemon-reload
systemctl --user start ward.service
```

## Apply

```sh
systemctl --user daemon-reload
systemctl --user --job-mode=ignore-requirements \
    restart ward-build.service &&
systemctl --user restart ward.service
```

The container is restarted only after a successful build.

## Attach

```sh
podman exec --user agent --interactive --tty ward \
    tmux new-session -A -s ward
```

The host and Ward share `.pi`; do not use it concurrently.

## Remove

```sh
systemctl --user stop ward.service ward-build.service
rm -- "$HOME/.config/containers/systemd/ward"
systemctl --user daemon-reload
podman image rm localhost/ward:latest
```
