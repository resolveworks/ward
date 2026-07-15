# AGENTS.md

## Purpose

Ward is a minimal, declarative definition of one long-lived Arch Linux
`systemd-nspawn` machine for pi and its child agents. It is not an application
or automated installer.

## Rules

- Keep the repository limited to `ward.nspawn`, `resources.conf`,
  `packages.txt`, and their documentation.
- Preserve the unprivileged `agent` user, private user namespace, id-mapped
  mounts, virtual Ethernet, and absence of broad home or socket mounts.
- Treat concrete paths, names, UID, timezone, and limits as deliberate. Keep
  configuration and documentation consistent.
- Keep one explicit Arch package per line in `packages.txt`. Project-specific
  dependencies belong to their projects.
- Update `README.md` when behavior changes. Wrap prose near 80 columns and use
  fenced `sh` blocks for commands.
- Do not overwrite unrelated working-tree changes.

## Safety and validation

Do not run `sudo`, `pacstrap`, `systemctl`, `machinectl`, stress tests, or rebuild
commands without explicit permission. Never add secrets, machine-root contents,
or files from `/home/johan/.pi`.

Check changes with:

```sh
git diff --check
git diff
```

Host validation must confirm writable mapped mounts, filesystem and socket
isolation, outbound DNS and HTTPS, and resource limits. State when it was not
performed.
