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

The only controller prerequisite is Ansible on the Arch host:

```sh
sudo pacman -S --needed ansible
```

Run the local playbooks from the repository root. Pass `-K`
(`--ask-become-pass`) when sudo needs a password.

## Install and apply

```sh
ansible-playbook install.yml -K
```

`install.yml` creates Ward when absent and otherwise reconciles its definitions,
packages, system settings, and `agent` account.

Packages from `packages.txt` are reconciled **presence-only**: every declared
package is installed, but removing a line never uninstalls that package.

Reconciliation requires a stopped container. A running Ward is stopped and
restored after a successful apply; an initially stopped Ward remains stopped.
On failure, it remains stopped.

## Start and use

Start Ward and attach to its shared tmux session as the `agent` user:

```sh
sudo systemctl start systemd-nspawn@ward.service
machinectl shell agent@ward /usr/bin/tmux new-session -A -s ward
```

Host and container pi share the mounted `.pi`, so do not use the same session or
extension runtime files concurrently in both.

## Administration

```sh
machinectl shell root@ward
machinectl status ward
journalctl -u systemd-nspawn@ward.service
sudo systemctl stop systemd-nspawn@ward.service
```

## Uninstall

`uninstall.yml` is **destructive and unguarded**. It stops Ward, removes its
root and host definitions, and reloads systemd. It preserves host packages and
the two bind-mount sources, and is safe to re-run when Ward is absent.

```sh
ansible-playbook uninstall.yml -K
```

## Verify

Before relying on Ward, confirm mapped-mount ownership, isolation from
unrelated host files and sockets, outbound DNS and HTTPS, and the configured
resource limits. `owneridmap` requires kernel and filesystem support for
id-mapped mounts.
