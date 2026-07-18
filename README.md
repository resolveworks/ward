# Ward

Ward is one disposable Arch Linux `systemd-nspawn` machine that hosts pi, its
child agents, and their shared tmux server. Ansible playbooks install and
reconcile it on an Arch Linux host.

## Model

The container root `/var/lib/machines/ward` is disposable. Only these host
paths persist through bind mounts:

```text
/home/johan/Projects   -> /workspace
/home/johan/.pi        -> /home/agent/.pi
/home/johan/.tmux.conf -> /home/agent/.tmux.conf (read-only)
/home/johan/.zshrc     -> /home/agent/.zshrc (read-only)
/home/johan/.oh-my-zsh -> /home/agent/.oh-my-zsh (read-only)
```

All other container data can disappear when Ward is removed or rebuilt. The
machine root contains no required durable state: the repository, host
prerequisites, and the bind-mount sources are sufficient to reconstruct it.
Rebuild the disposable root instead of maintaining migrations for obsolete
internal state.

## Prerequisites

The controller needs Ansible, the public key
`/home/johan/.ssh/id_ed25519.pub`, regular `/home/johan/.tmux.conf` and
`/home/johan/.zshrc` files, and a `/home/johan/.oh-my-zsh` directory on the
Arch host:

```sh
sudo pacman -S --needed ansible
```

The host must run systemd-networkd and systemd-resolved. networkd configures
Ward's virtual Ethernet link with DHCP and NAT through the stock
`80-container-ve.network` file, and Ward copies its DNS servers from
resolved's uplink list (`ResolvConf=copy-uplink` in `ward.nspawn`) because
the host's `127.0.0.53` stub resolver is unreachable from inside Ward.

The inventory selects the matching `/home/johan/.ssh/id_ed25519` private key;
its contents remain outside this repository. Run the playbooks from the
repository root. Pass `-K`
(`--ask-become-pass`) when sudo needs a password.

## Install and apply

```sh
ansible-playbook install.yml -K
```

`install.yml` creates Ward when absent, authorizes the controller public key for
`root`, and enables Ward at host boot. Once Ward is running, Ansible reconciles
its packages, system settings, and `agent` account over SSH through the virtual
Ethernet connection.

Packages from `packages.txt` are reconciled **presence-only**: every declared
package is installed, but removing a line does not uninstall that package from
an existing root. Rebuilding resets Ward to the declared package set.

Routine reconciliation does not stop Ward. Ward is stopped only if required SSH
bootstrap files or packages must be repaired offline. Later applies restart
Ward only when host-side configuration requiring a restart changes.

## Use

Ward starts automatically. The `agent` user's login shell is zsh. Its host
`.zshrc` and complete Oh My Zsh tree are mounted read-only, so host shell
configuration changes are immediately visible without allowing Ward to modify
them. Commands and absolute paths referenced by `.zshrc` still need to exist in
Ward to work there.

Attach to its shared tmux session as the `agent` user:

```sh
machinectl shell agent@ward /usr/bin/tmux new-session -A -s ward
```

Host and container pi share the mounted `.pi`, so do not use the same session or
extension runtime files concurrently in both.

## Administration

```sh
ssh root@ward
machinectl shell root@ward
machinectl status ward
journalctl -u systemd-nspawn@ward.service
sudo systemctl stop systemd-nspawn@ward.service
```

## Uninstall

`uninstall.yml` is **destructive and unguarded**. It disables and stops Ward,
removes its root and host definitions, and reloads systemd. It preserves host
packages and the bind-mount sources, and is safe to re-run when Ward is absent.

```sh
ansible-playbook uninstall.yml -K
```

## Verify

Before relying on Ward, confirm mapped-mount ownership, isolation from
unrelated host files and sockets, outbound DNS and HTTPS, and the configured
resource limits. `owneridmap` maps each agent-owned mount target to the host
owner of its source, so the agent can use the bind mounts without exposing the
full host UID range inside Ward. It requires kernel and filesystem support for
id-mapped mounts.
