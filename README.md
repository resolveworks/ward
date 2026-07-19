# Ward

Ward is a disposable Arch Linux environment for pi and its shared tmux server.
It runs as a rootless Podman container under the user systemd instance.

## Contract

Ward requires an x86_64 Arch Linux host with Podman, tmux compatible with the
image's tmux server, cgroup v2, user namespaces, at least 65536 subordinate
UIDs/GIDs, and lingering enabled.

Host bind mounts provide projects, configuration, and persistent development
state. Home-directory mounts use the same paths on the host and in the
container. Mounts and resource limits are defined in `ward.container`. The tmux
server socket is exposed at `$XDG_RUNTIME_DIR/ward/tmux.sock`; the tmux client
runs on the host. All other container state is discarded on stop. The container
account uses the host user name and home path, runs as 1000:1000 under
`keep-id`, and drops all capabilities.

Networking is shared with the host. Host loopback, abstract Unix sockets, and
host ports are therefore shared as well; Ward is not a network boundary.

## Host setup

```sh
sudo pacman --needed -S podman tmux
sudo loginctl enable-linger "$USER"
install -d -m 0755 "$HOME/.cache/uv"
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

## Start a session

```sh
tmux -S "$XDG_RUNTIME_DIR/ward/tmux.sock" new-session
```

## Remove

```sh
systemctl --user stop ward.service ward-build.service
rm -- "$HOME/.config/containers/systemd/ward"
systemctl --user daemon-reload
podman image rm localhost/ward:latest
```
