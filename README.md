# Ward

Ward is one disposable Arch Linux `systemd-nspawn` machine that hosts pi, its
child agents, and their shared tmux server. Ansible playbooks install and
reconcile it on an Arch Linux host.

## Model

The container root `/var/lib/machines/ward` is disposable: it can be removed and
rebuilt without losing anything that matters. Only two host directories are
bind-mounted in and persist across rebuilds:

```text
/home/johan/Projects  -> /workspace
/home/johan/.pi       -> /home/agent/.pi
```

Anything that lives only inside Ward (for example `/home/agent` apart from the
mounted `.pi`) can disappear when the machine is removed or rebuilt.

## Prerequisites

The only controller prerequisite is Ansible on the Arch host:

```sh
sudo pacman -S --needed ansible
```

The playbooks run locally (`connection: local`) and escalate privileges with
`become: true`, so run them from the repository root. Pass `-K`
(`--ask-become-pass`) when sudo needs a password; omit it if your account has
passwordless sudo.

## Install and apply

```sh
ansible-playbook install.yml -K
```

`install.yml` is idempotent: it creates Ward when absent and reconciles the
declared `ward.nspawn`, `resources.conf`, `packages.txt`, hostname/locale/
timezone, and `agent` account when present. Re-running it keeps Ward converged.

Packages from `packages.txt` are reconciled **presence-only**: every declared
package is installed, but removing a line never uninstalls that package.

Offline-root reconciliation runs against a stopped container, so `install.yml`
detects whether `systemd-nspawn@ward.service` is running: if it is, Ward is
stopped for the reconcile and started again afterward; if it was stopped it is
left stopped. If apply fails after stopping Ward, it stays stopped rather than
booting a half-reconciled image.

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

`uninstall.yml` is **destructive and unguarded**: it removes Ward with no
confirmation prompt. It stops the machine, deletes the entire root
`/var/lib/machines/ward`, removes the installed nspawn definition and the
dedicated service drop-in, and reloads systemd. It is idempotent and safe to
re-run when Ward is already gone.

It preserves the host bind-mount sources (`/home/johan/Projects`,
`/home/johan/.pi`) and the host packages that `install.yml` installed.

```sh
ansible-playbook uninstall.yml -K
```

## Verify

Before relying on Ward, confirm mapped-mount ownership, isolation from
unrelated host files and sockets, outbound DNS and HTTPS, and the configured
resource limits. `owneridmap` requires kernel and filesystem support for
id-mapped mounts.
