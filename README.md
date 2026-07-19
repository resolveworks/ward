# Ward

Ward is a disposable Arch Linux environment for pi and its shared tmux server.
It runs as a rootless Podman container under the user systemd instance. It
exists to give a coding agent an exact, reproducible toolchain that can be
rebuilt and discarded at any time, without touching host state.

The image pins an Arch snapshot and installs the full package set in one
transaction. The container runs rootless with dropped capabilities and private
namespaces; its writable root is discarded on stop, and only declared bind
mounts — projects, selected configuration, and agent state — persist. The
tmux server runs in the container and exposes its socket, so sessions are
driven by host clients. Networking is shared with the host; Ward isolates
state, not the network.

## Host setup

```sh
sudo pacman --needed -S openssh podman tmux
sudo loginctl enable-linger "$USER"
systemctl --user enable --now ssh-agent.socket
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
tmux -S "$XDG_RUNTIME_DIR/ward/tmux.sock"
```

## Remove

```sh
systemctl --user stop ward.service ward-build.service
rm -- "$HOME/.config/containers/systemd/ward"
systemctl --user daemon-reload
podman image rm localhost/ward:latest
```
