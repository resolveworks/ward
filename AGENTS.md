# AGENTS.md

## Purpose

Ward defines one reproducible Arch Linux `systemd-nspawn` machine for pi, child
agents, and their shared tmux server. Local Ansible playbooks manage it with
privilege escalation. Only these host bind mounts persist:

```text
/home/johan/Projects -> /workspace
/home/johan/.pi       -> /home/agent/.pi
```

The container root (`/var/lib/machines/ward`) is disposable and must contain no
required durable state. A clean uninstall followed by install must reconstruct
Ward from the repository, host prerequisites, and the two bind-mount sources.
Runtime state elsewhere in the root is expendable and must never become a
provisioning input.

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
  owner-mapped (`owneridmap`) bind mounts, virtual Ethernet, and the absence of
  broad home or socket mounts. Create bind-mount targets as the agent in the
  machine root before starting Ward; do not identity-map the full container UID
  range onto host UIDs.
- Treat concrete paths, names, UID, timezone, and resource limits as
  deliberate. Keep `ward.nspawn`, `resources.conf`, `packages.txt`, and the
  playbook variables consistent with one another.
- Keep one explicit Arch package per line in `packages.txt`. Project-specific
  dependencies belong to their projects, not Ward. Reconciliation is
  PRESENCE-ONLY: removing a line does not uninstall that package from an
  existing root; rebuilding resets the machine to the declared package set.
- Treat the repository as the source of truth for all required machine
  configuration. Do not add migrations, compatibility paths, or markers for
  obsolete machine-root state. Reconcile the current declaration when possible;
  otherwise uninstall and rebuild the disposable root.
- Prefer fully-qualified `ansible.builtin.*` module names and idempotent
  modules over `shell`/`command`. Run host lifecycle tasks with
  `connection: local` and `become: true`, and reconcile the running Ward machine
  over SSH as root. Never embed `sudo` in commands.
- Install/apply must create Ward when absent and reconcile it when present;
  do not add a reinstall path. Bootstrap Python, OpenSSH, and the controller's
  `/home/johan/.ssh/id_ed25519.pub` key offline only when needed. Enable Ward at
  boot, then perform routine package and machine configuration over SSH without
  stopping it. Restart Ward only when its nspawn definition, resource limits,
  or pre-mount configuration changed. Reload `systemd`, via a handler flushed
  before start or restart, only when copied unit/drop-in definitions changed.
- Uninstall must remain separate, destructive, and unguarded (no prompt or
  assertion). It must disable and stop Ward, remove its root, nspawn definition,
  and dedicated service drop-in, reload `systemd`, and remain idempotent when
  Ward is absent.
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
