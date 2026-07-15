# Ward

Ward is one disposable Arch Linux `systemd-nspawn` machine that hosts pi, its
child agents, and their shared tmux server. Ansible playbooks install and
reconcile it on an Arch Linux host.

## Model

The container root `/var/lib/machines/ward` is disposable. Only two host
directories persist through bind mounts:

```text
/home/johan/Projects  -> /workspace
/home/johan/.pi       -> /home/agent/.pi
```

All other container data can disappear when Ward is removed or rebuilt.

## Prerequisites

The controller needs Ansible and the public key
`/home/johan/.ssh/id_ed25519.pub` on the Arch host:

```sh
sudo pacman -S --needed ansible
```

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
package is installed, but removing a line never uninstalls that package.

Routine reconciliation does not stop Ward. An existing installation is stopped
once if it needs SSH bootstrap files or packages. Later applies restart Ward
only when `ward.nspawn` or `resources.conf` changes.

## Use

Ward starts automatically. Attach to its shared tmux session as the `agent`
user:

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
packages and the two bind-mount sources, and is safe to re-run when Ward is
absent.

```sh
ansible-playbook uninstall.yml -K
```

## Verify

Before relying on Ward, confirm mapped-mount ownership, isolation from
unrelated host files and sockets, outbound DNS and HTTPS, and the configured
resource limits. `owneridmap` requires kernel and filesystem support for
id-mapped mounts.
