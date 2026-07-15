# AGENTS.md

## Purpose

Ward defines one long-lived Arch Linux `systemd-nspawn` machine for pi, child
agents, and their shared tmux server. Local Ansible playbooks manage it with
privilege escalation. Only these host bind mounts persist:

```text
/home/johan/Projects -> /workspace
/home/johan/.pi       -> /home/agent/.pi
```

The container root (`/var/lib/machines/ward`) is disposable.

## Repository contents

- `ward.nspawn` - machine definition.
- `resources.conf` - service resource limits.
- `packages.txt` - container package declarations.
- `ansible.cfg`, `inventory.ini` - local Ansible configuration.
- `install.yml`, `uninstall.yml` - lifecycle playbooks.
- `README.md` - user documentation.

Keep the repository limited to these files, additional playbooks, and their
documentation. Do not add roles, custom plugins, third-party collections, or
other abstractions unless necessary.

## Rules

- Preserve the unprivileged `agent` user (UID 1000), private user namespace,
  id-mapped (`owneridmap`) bind mounts, virtual Ethernet, and the absence of
  broad home or socket mounts.
- Treat concrete paths, names, UID, timezone, and resource limits as
  deliberate. Keep `ward.nspawn`, `resources.conf`, `packages.txt`, and the
  playbook variables consistent with one another.
- Keep one explicit Arch package per line in `packages.txt`. Project-specific
  dependencies belong to their projects, not Ward. Reconciliation is
  PRESENCE-ONLY: removing a line does not uninstall that package.
- Prefer fully-qualified `ansible.builtin.*` module names and idempotent
  modules over `shell`/`command`. Use `connection: local` and `become: true`
  rather than embedding `sudo` in commands.
- Install/apply must create Ward when absent and reconcile it when present;
  do not add a reinstall path. Detect whether `systemd-nspawn@ward.service` is
  running at apply time. Stop a running Ward before offline reconciliation and
  restore it only after success. Leave an initially stopped Ward stopped, and
  leave Ward stopped if reconciliation fails. Reload `systemd`, via a handler
  flushed before restore, only when copied unit/drop-in definitions changed.
- Uninstall must remain separate, destructive, and unguarded (no prompt or
  assertion). It must stop Ward, remove its root, nspawn definition, and
  dedicated service drop-in, reload `systemd`, and remain idempotent when Ward
  is absent.
- Host dependencies installed by install/apply must not be removed by uninstall.
  The host source directories bind-mounted into Ward (/home/johan/Projects,
  /home/johan/.pi) must never be deleted.
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
ansible-playbook uninstall.yml --syntax-check
ansible-playbook uninstall.yml --list-tasks
```

Host validation (performed by the user, not the agent) must confirm writable
id-mapped mounts, filesystem and socket isolation, outbound DNS and HTTPS, and
the configured resource limits. State when it was not performed.
