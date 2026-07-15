# AGENTS.md

## Purpose

Ward is a small Ansible project that defines one long-lived Arch Linux
`systemd-nspawn` machine for pi, its child agents, and their shared tmux
server. Playbooks install/apply the machine and reconcile its declared
definitions; they are run locally with privilege escalation.

Persistent data lives only in host bind mounts:

```text
/home/johan/Projects -> /workspace
/home/johan/.pi       -> /home/agent/.pi
```

The container root (`/var/lib/machines/ward`) need not preserve data.

## Repository contents

- `ward.nspawn` - machine definition (boot, hostname, private user namespace,
  id-mapped bind mounts, virtual Ethernet).
- `resources.conf` - `systemd-nspawn@ward.service.d` drop-in (resource limits).
- `packages.txt` - container packages, one explicit Arch package per line.
- `ansible.cfg`, `inventory.ini` - localhost Ansible configuration.
- `install.yml` - install/apply playbook (idempotent; create when absent,
  reconcile when present).
- `README.md` - user documentation.

Keep the repository limited to these files plus any later playbook (for
example `uninstall.yml`) and its documentation. Do not add roles, custom
plugins, third-party collections, or extra abstractions unless genuinely
necessary.

## Rules

- Preserve the unprivileged `agent` user (UID 1000), private user namespace,
  id-mapped (`owneridmap`) bind mounts, virtual Ethernet, and the absence of
  broad home or socket mounts.
- Treat concrete paths, names, UID, timezone, and resource limits as
  deliberate. Keep `ward.nspawn`, `resources.conf`, `packages.txt`, and the
  playbook variables consistent with one another.
- Keep one explicit Arch package per line in `packages.txt`. Project-specific
  dependencies belong to their projects, not Ward.
- Prefer fully-qualified `ansible.builtin.*` module names and idempotent
  modules over `shell`/`command`. Use `connection: local` and `become: true`
  rather than embedding `sudo` in commands.
- Install/apply must be idempotent: create when absent and reconcile when
  present. Do not add a reinstall path. Uninstall is a separate, explicitly
  invoked, destructive operation.
- Host dependencies installed by install/apply must not be removed by uninstall.
- Do not start the machine as a side effect of install/apply.
- Update `README.md` when behavior changes. Wrap prose near 80 columns and use
  fenced `sh` blocks for commands.
- Do not overwrite unrelated working-tree changes.

## Safety and validation

Do not run `sudo`, `pacstrap`, `systemctl`, `machinectl`, the playbooks (which
perform those operations), stress tests, or rebuild commands without explicit
permission. Never add secrets, machine-root contents, or files from
`/home/johan/.pi`.

Safe, non-mutating checks:

```sh
git diff --check
git diff
ansible-playbook install.yml --syntax-check
ansible-playbook install.yml --list-tasks
```

Host validation (performed by the user, not the agent) must confirm writable
id-mapped mounts, filesystem and socket isolation, outbound DNS and HTTPS, and
the configured resource limits. State when it was not performed.
