# Ward

Ward is a disposable Arch Linux environment for pi and its shared tmux server.
`Containerfile` defines the image; `ward.build` and `ward.container` build and
run it with rootless Podman and user-level systemd.

## Runtime

Only these host paths persist:

```text
$HOME/Projects   -> /workspace
$HOME/.pi        -> /home/agent/.pi
$HOME/.tmux.conf -> /home/agent/.tmux.conf (read-only)
$HOME/.zshrc     -> /home/agent/.zshrc (read-only)
$HOME/.oh-my-zsh -> /home/agent/.oh-my-zsh (read-only)
```

Everything else disappears when Ward stops. The container runs rootless as
`agent` (UID/GID 1000:1000) with private process and filesystem namespaces,
dropped capabilities, and the limits in `ward.container`.

Ward uses host networking. It can reach host loopback and abstract Unix
sockets, and its services consume host ports. It is not a network security
boundary.

## Requirements

Ward assumes:

- an x86_64 Arch Linux host with Podman, cgroup v2, and user namespaces;
- the five bind sources above exist;
- `/etc/subuid` and `/etc/subgid` allocate at least 65536 IDs;
- lingering is enabled.

One-time host setup, if needed:

```sh
sudo pacman --needed -S podman
sudo loginctl enable-linger "$USER"
```

## Deploy

From the repository root:

```sh
install -d -m 0700 "$HOME/.config/containers/systemd"
ln -sfT "$PWD" "$HOME/.config/containers/systemd/ward"
systemctl --user daemon-reload
systemctl --user start ward.service
```

Quadlet builds the image before starting Ward and starts it on subsequent
boots.

## Apply changes

```sh
systemctl --user daemon-reload
systemctl --user --job-mode=ignore-requirements \
    restart ward-build.service &&
systemctl --user restart ward.service
```

A failed build leaves the current container running. A successful build is
picked up by the following restart.

## Use

Attach to Ward's tmux session:

```sh
podman exec --user agent --interactive --tty ward \
    tmux new-session -A -s ward
```

Host and Ward share `.pi`; avoid using it from both at the same time.

## Remove

```sh
systemctl --user stop ward.service ward-build.service
rm -f -- "$HOME/.config/containers/systemd/ward"
systemctl --user daemon-reload
podman image rm --ignore localhost/ward:latest
```

This preserves the bind sources, host prerequisites, and unrelated Podman
state.
