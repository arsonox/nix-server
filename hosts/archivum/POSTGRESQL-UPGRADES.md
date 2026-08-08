# PostgreSQL major upgrades

Archivum runs **one shared instance**, so a major upgrade is every app's
upgrade at once. It happens when it is decided here, never as a side effect:
`services/postgresql.nix` pins `package = pkgs.postgresql_18` by name. Leave
the pin.

Currently **18** (EOL Nov 2030). No reason to move before ~2029.

Data lives in `/var/lib/postgresql/$major` — bumping the package alone points
postgres at an empty directory and it will `initdb` a blank cluster rather than
fail. The old data is untouched, which is also what makes rollback easy.

## Before anything

```bash
systemctl start postgresqlBackup     # fresh dumpall, don't trust last night's
ls -l /var/backup/postgresql/
sudo -u postgres psql -l             # note what should exist afterwards
```

Read the upstream release notes for every major you skip, not just the target.
Incompatible changes accumulate per version.

## Route A — dump and restore (default)

Simple, and the dump already exists. Downtime scales with data size; at this
scale that is minutes.

```bash
systemctl stop <every service using postgres>   # gotosocial, etc.
systemctl stop postgresql

# keep the old cluster as the rollback
mv /var/lib/postgresql/18 /var/lib/postgresql/18.old
```

Bump `package` to `pkgs.postgresql_NN` in `services/postgresql.nix`, then:

```bash
sudo nixos-rebuild switch --flake .#archivum   # initdb's an empty NN cluster
zstd -dc /var/backup/postgresql/all.sql.zstd | sudo -u postgres psql -f -
sudo -u postgres vacuumdb --all --analyze-in-stages
systemctl start <the services again>
```

`ensureDatabases`/`ensureUsers` from the service files run before the restore
and collide harmlessly — `pg_dumpall` output is idempotent about roles.

**Rollback**: revert `package`, rebuild, `mv 18.old` back. Valid until an app
writes to the new cluster.

## Route B — pg_upgrade

Only worth it once dump/restore takes longer than the outage allows. Copy the
`upgrade-pg-cluster` script from the NixOS manual
(`module-services-postgres-upgrading`), which builds the new cluster in place
and skips the dump. `--link` makes it near-instant and destroys the rollback;
pick one.

## After either

- `full_page_writes = false` stays valid — it depends on ZFS, not the version.
- Re-check `shared_buffers` only if RAM or the ARC cap changed.
- Confirm the next `postgresqlBackup` run succeeds. A dump written by the new
  binaries is the only proof the upgrade is really finished.
- Delete `18.old` once a restic snapshot has run green against the new cluster,
  not before.
