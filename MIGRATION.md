# Proxmox → archivum migration roadmap

Goal: retire the Proxmox host (loud, power-hungry) and land its remaining
workloads on **archivum**, which becomes the main home server.

Decisions taken (2026-07-29):

- Prefer upstream NixOS modules; `virtualisation.oci-containers` with **podman**
  is an accepted *temporary* fallback where no module exists. Two permanent
  exceptions: openspeedtest (no module anywhere) and UniFi OS Server (the only
  non-deprecated option is a third-party flake running podman).
- Secrets start as git-crypt over `secrets/**`, and **move to sops-nix in Phase
  2** (2026-08-05). It is not a blocker for anything, but it is no longer just a
  "possible later step": git-crypt leaves every secret world-readable in the nix
  store, and that is the wrong state to hand a machine that is about to become
  the only copy of things.
- Offsite backups currently run from the **TrueNAS VM** to a **Hetzner Storage
  Box**. That must be reproduced on archivum *and verified* before TrueNAS is
  shut down.
- **fabricum** is itself a Proxmox VM and does not survive in its current form
  (Phase 6).
- **External access stays on the Cloudflare tunnel.** quaesitum is a small
  Hetzner VM doing search; it is not a reverse-proxy candidate.
- **Alerting lives on quaesitum**, not archivum (2026-08-03). It is the one
  service this migration *adds* to that host, and it goes there because an alert
  channel hosted on the machine it monitors cannot report that machine being
  down. Separate power, separate uplink, separate failure domain.
- **One shared PostgreSQL instance** on archivum, as today, with per-app
  databases and roles over the unix socket.
- **immich is dropped, not migrated** (2026-08-04). It cannot be pinned: the
  mobile app enforces server/app version compatibility and updates on the App
  Store's schedule, so a third party would be choosing when archivum runs an
  irreversible database migration. Nothing else here has that property.

  Replaced by **syncthing** into `tank/photos` plus a read-only samba share —
  see Phase 4. This deletes the highest-risk item of the whole migration, drops
  the pgvector/vectorchord requirement from the shared Postgres, and frees ~4 GB
  of RAM. What is genuinely lost is face recognition and semantic search;
  PhotoPrism can be pointed at the same directory later if they are missed,
  without ever gating the phone on a server version.
- The video-through-a-tunnel question is closed: owncast serves its segments
  from **R2**, so only the HTML/API layer crosses the tunnel, and jellyfin is
  LAN-only.

## Inventory

| VM | Contents | Target | Module in nixpkgs 26.05 |
| --- | --- | --- | --- |
| UniFi controller | Ubiquiti network controller | archivum | **UniFi OS Server** via `github:rcambrj/unifi-os-server` (podman) — see Phase 5 |
| Docker VM | qbittorrent, cloudflared, homepage, openspeedtest, speedtest-tracker, prowlarr, gotosocial | archivum | all but openspeedtest have modules — see below. **immich is dropped, not migrated** |
| TrueNAS | file storage + Hetzner Storage Box backups | archivum `tank` | native ZFS + `services.restic` |
| Owncast | live streaming | archivum | `services.owncast` (0.2.5) |
| Jellyfin | media server | archivum (**already running there**) | `services.jellyfin` (10.11.11) |
| PostgreSQL | all databases (currently **16**) | archivum | `services.postgresql`, pinned to `postgresql_18` (18.4) |
| Minecraft | idle, nobody plays | **delete** | `services.minecraft-server` if ever revived |
| fabricum | dev/general | Phase 6 decision | — |

Two duplicates fall out of this: **qbittorrent** and **jellyfin** already run on
archivum. Neither needs migrating as a service — only their state does, and only
if you care about seeding history and watch progress.

`hosts/ubiqium/` is a planned NixOS VM (`services.qemuGuest.enable = true`,
disko config) that was meant to replace the UniFi VM on Proxmox. With Proxmox
going away it has no hypervisor, so unifi should move into archivum and ubiqium
should be retired from `flake.nix` — unless you want it as a microvm for
isolation.

## Dependency order

```
restic → Hetzner            ─┐
PostgreSQL on archivum      ─┼─→ gotosocial, speedtest-tracker
cloudflared (external)      ─┘        │
TrueNAS data → tank ───────────────→ jellyfin cutover, samba/nfs clients
```

Postgres and external access gate the interesting services, so they come first
even though nothing user-visible changes when they land.

## Guiding rules

1. **Backups first.** Nothing is decommissioned until archivum's offsite backup
   runs green *and* a restore has been tested.
2. **One service per change**, each its own commit in `hosts/archivum/services/`.
   The auto-import in `services/default.nix` picks up new files automatically.
3. **Both sides run in parallel** through a soak period. Migrate by pointing
   clients at archivum, not by deleting the source.
4. **The Proxmox host stays powered off but intact** for a grace period after
   the last cutover — that is the rollback plan.
5. Every migrated service gets an uptime-kuma check *before* its source stops.
6. **Match versions before moving state.** Every app-with-a-database below can
   restore a dump from an older version into a newer app, but never the reverse.
   Check the container's current version against the nixpkgs version in the
   table above *before* dumping.

## Phase 0 — Baseline

- [x] Wall-meter the Proxmox host and archivum, so the win is quantified.
- [x] RAM: archivum has **64 GB**, the Postgres VM runs in 4 GB. No hardware
      bump needed — see the resource budget in Phase 2.
- [ ] For each service: current version, ports, DNS names, and which clients
      (phones, TVs, scripts) point at it.
- [ ] Note any USB passthrough in use (Zigbee/Z-Wave/UPS dongles).

## Phase 1 — Foundations on archivum

Written and evaluating as of 2026-08-03, in `hosts/archivum/services/`. Every
piece that needs a credential is **inert until the secret exists** and warns on
every rebuild until then, so a half-finished Phase 1 cannot look finished. Setup
commands for each live in `hosts/archivum/README.md`.

- [x] **Backups.** `services/restic.nix` — `/var/lib`, `/home` and
      `/mnt/tank/nox` to the Storage Box nightly at 02:15, 14 daily / 8 weekly /
      12 monthly / 3 yearly, `--exclude-caches` plus explicit excludes for
      jellyfin metadata, clamav signatures and netdata. Media is deliberately
      absent — re-downloadable, and 14 TB does not fit.

      The Storage Box only offers **password auth**, so the sftp connection goes
      through `sshpass` rather than a key. Needs
      `secrets/storagebox-{target,password,restic-password}` — note that the
      login password and the restic repository password are two different
      things.

      A monthly `restic check --read-data-subset=5%` runs on its own timer
      rather than after every backup: over sftp a full structural check every
      night costs a lot and proves little.
- [x] **Snapshots.** `services/sanoid.nix` — hourly, with three retention
      templates: `rpool/{root,var}` and `tank/nox`, `rpool/home` longer,
      `tank/media` short. `rpool/nix` and `tank/incomplete` excluded as
      rebuildable and scratch respectively.
- [x] **Restore test.** Pull one dataset back from Hetzner and diff it. Until
      this passes, TrueNAS is still the system of record. Procedure is in
      `hosts/archivum/README.md`; also open the repository from a machine that
      is *not* archivum, since a backup only one host can read dies with it.
- [x] **Update policy — unchanged.** `auto-updates.nix` keeps rebuilding at
      04:40 and rebooting on kernel changes. A reboot while everyone is asleep
      is not the problem worth solving.

      Most breakage never gets that far: eval and build failures stop at
      `nixos-rebuild boot`, nothing activates, and the old generation keeps
      running.

      There is also four years of precedent — the Docker VM auto-updates every
      container, including immich and gotosocial, with zero incidents. NixOS
      updates are the more conservative arrangement of the two: they arrive only
      when a `flake.lock` bump is committed, off a pinned stable branch, with
      atomic activation and a bootable previous generation. Treat unattended
      updates as a settled question, not a migration risk.
- [x] **Log persistence.** `services/journald.nix` — `storage = "persistent"`
      overriding `hosts/common`, 2 GB cap, one month retention. A 04:40 failure
      no longer erases its own evidence before you wake up.
- [x] **Alerting.** `services/notifications.nix` — one `notify-mail` command
      that restic failures, smartd warnings and ZED events (scrubs, resilvers,
      checksum errors, degraded pools) all funnel into. It always writes to the
      journal, and pushes to ntfy when `secrets/ntfy-{url,token}` exist.

      `ZED_NOTIFY_VERBOSE` is on, so *clean* scrubs report too — that is what
      makes a silent month mean something rather than nothing. Attach any future
      unit with `onFailure = [ "notify-failure@%n.service" ]`.
- [x] **ntfy on quaesitum.** `hosts/quaesitum/services/ntfy.nix` —
      `https://ntfy.nox.onl` behind the nginx already on that box,
      `auth-default-access = deny-all`, users/ACLs/tokens provisioned
      declaratively from `hosts/quaesitum/secrets/ntfy.env` (the sqlite user db
      becomes a cache, not the source of truth).

      archivum gets a **write-only** token on the `alerts` topic — it publishes
      and cannot read back. Each future publisher gets its own line, so revoking
      one costs a line instead of a fleet-wide rotation.

      Needs an A/AAAA record for `ntfy.nox.onl` before the first rebuild:
      quaesitum issues certs over HTTP-01, so ACME fails while the name does not
      resolve.
- [x] **Reverse proxy + internal names.** `services/nginx.nix` — one DNS-01
      wildcard for `*.nox.onl` via Cloudflare, a default vhost that returns 444,
      and `kuma.nox.onl` as the first tenant. Inert until
      `secrets/acme-cloudflare.env` holds a `Zone:DNS:Edit` token.

      Each name needs a DNS record pointing at `10.201.3.229`. A public A record
      for a private address is fine and avoids running split-horizon DNS.

## Phase 2 — Shared infrastructure

- [x] **PostgreSQL — 16 on the VM → 18 on archivum** (confirmed 2026-08-05;
      `services/postgresql.nix` written 2026-08-06 — the config, not the data
      migration, which is still to run).
      Set `package = pkgs.postgresql_18` explicitly. Without it the module
      derives the major from `system.stateVersion` (`"25.11"` → `postgresql_17`)
      and `pkgs.postgresql` is 17.10 — 18.4 is packaged but only if asked for by
      name. Upstream even warns, at `postgresql.nix:645`, that a
      `stateVersion`-derived package is "not pinned"; pinning makes the version
      a decision in the file rather than a side effect of a variable set for
      unrelated reasons.

      Note `nh search` defaults to `--channel nixos-unstable`, where the
      `postgresql` alias *is* 18.4. This repo pins `nixos-26.05`, where it is
      17.10. Use `nh search -c nixos-26.05` to see what will actually be built.

      18 over 17 because this is a *shared* instance: upgrades are
      all-or-nothing across every app, and 18 is supported to Nov 2030 against
      17's Nov 2029. Same migration effort either way — 16 → 18 is one
      dump/restore, no intermediate hop. Nothing left here constrains the
      choice now that immich (pgvector/vectorchord) is dropped.

      Dump with the **target** version's `pg_dumpall` — new client against old
      server is the supported direction, not the reverse. The VM only has 16's
      binaries, so run it from archivum over the network (`-h <vm>`) rather than
      on the VM itself. Check first that the VM's Postgres actually listens
      somewhere archivum can reach and that `pg_hba.conf` will let it in — if it
      is bound to localhost or a Docker bridge, that is a prerequisite, not a
      surprise to hit halfway through.

      Per-app databases via `ensureDatabases`/`ensureUsers`, unix-socket auth
      where possible so no passwords are needed — declared by each service's
      own file, not centrally, so nothing outlives the service that wanted it.

      Backups are `services.postgresqlBackup` (`pg_dumpall`, zstd, 01:15 — an
      hour before restic), and restic now **excludes `/var/lib/postgresql`**:
      backing up a live datadir produces a torn copy that restores cleanly
      right up until it doesn't. The dump is the backup; the datadir is not.

      `full_page_writes = false` is set, which is safe *only* because the
      datadir is on ZFS (`rpool/var`) — CoW makes a partially-written page
      impossible. It is the one line in that file that becomes a data-loss bug
      if postgres ever moves to a non-ZFS filesystem.
**One shared instance**, mirroring the single Postgres VM you run today. Wiring
per service, all over the `/run/postgresql` unix socket so no passwords are
needed:

| Service | How |
| --- | --- |
| gotosocial | `services.gotosocial.setupPostgresqlDB = true` — sets `db-type`, points `db-address` at the socket, creates DB and role |
| speedtest-tracker | No `createLocally` equivalent; needs hand-written `ensureDatabases`/`ensureUsers` and `DB_CONNECTION = "pgsql"`. Honestly, SQLite is fine here — it is speedtest history, and it saves the wiring |

Accept the tradeoff knowingly: a shared instance means major-version upgrades
are all-or-nothing for every app at once. In exchange, one `pg_dumpall` in
restic covers everything. The major is pinned explicitly in the config (see
above), so no nixpkgs bump will move it under you — the upgrade happens when you
choose it.
- [x] **cloudflared.** `services.cloudflared` (2026.5.2) with the tunnel
      credentials JSON under `secrets/`. Declarative ingress rules replace the
      container's config.
- [ ] **sops-nix, replacing git-crypt.** The point is the risk row below: today
      every secret is copied into the world-readable `/nix/store`. git-crypt
      protects the *repository*, not the *machine*. sops-nix decrypts at
      activation into `/run/secrets`, so the value never enters the store.

      Do it **after the restore test, before decommissioning TrueNAS** — while
      breaking archivum is still cheap. Migrate archivum first, confirm, then
      quaesitum; the two schemes coexist, so it need not be one sitting.

      Keys: each host's existing `/etc/ssh/ssh_host_ed25519_key`, converted with
      `ssh-to-age`. No new key material to provision on any host — but it does
      mean a host key must survive a reinstall, or its secrets must be re-keyed.
      One personal age key on fabricum for editing. `nixos-rebuild build` from
      fabricum keeps working without the target's key, since decryption happens
      at activation, not eval.

      Twelve secrets, splitting by *when* the value is needed:

      | Kind | Secrets | Work |
      | --- | --- | --- |
      | Runtime file path | `acme-cloudflare.env`, `ntfy-url`, `ntfy-token`, `storagebox-password`, `storagebox-restic-password`, `syncthing-gui-password`, `wg-qbtwg.conf`, quaesitum `ntfy.env` + `searxng.env` | Mechanical: `toString ../secrets/x` → `config.sops.secrets.x.path` |
      | Read at eval | `searxng-secret`, `secrets/email`, `syncthing-iphone-id` | All three dissolve — see below |
      | Read at eval | `storagebox-target` | The one real snag |

      The eval-time ones cannot survive as-is, because sops has nothing to give
      nix at eval. Three of the four go away rather than migrate:
      `searxng-secret` becomes `secret_key = "$SEARXNG_SECRET"` in the
      environment file (the searx module interpolates `$VAR` into settings);
      `secrets/email` is an ACME registration address, already hardcoded in
      cleartext in `hosts/quaesitum/secrets/acme.nix`, so inline it and delete
      the file; a syncthing device ID is a public key fingerprint, so inline it.

      `storagebox-target` is the awkward one. `services.restic.backups.*` has
      `repositoryFile`, which covers the repo URL — but `sftp.command` also
      needs the hostname, and that string is built at eval. It needs a wrapper
      reading the target at runtime (`sh -c 'exec sshpass -f … ssh … $(cat
      /run/secrets/storagebox-target) -s sftp'`). Fiddly, and it touches the one
      service that is expensive to test.

      Two things to keep in mind. Put the sops files **outside** `secrets/`
      (e.g. `hosts/archivum/secrets.yaml`) or narrow `.gitattributes`, otherwise
      git-crypt encrypts them too and the double layer breaks confusingly
      whenever the repo is locked. And the repo-wide "inert until the secret
      exists" pattern weakens: an encrypted file is always present, so a missing
      secret becomes a service failing at activation instead of an eval warning.
      Gating on `builtins.pathExists ./secrets.yaml` keeps the property at
      per-host rather than per-secret granularity, which is worth doing.

### Tunnel ingress

Current state, and what each becomes:

| Hostname | Service | Plan |
| --- | --- | --- |
| `social.nox.onl` | gotosocial | Keep. The cutover moment for Phase 5 |
| `party.nox.onl` | owncast | Keep. Segments come from R2, so only HTML/API crosses the tunnel |
| `jelly.nox.onl` | jellyfin | Either way — one click in the Cloudflare dashboard to drop or repoint. Decide at cutover, not now. LAN-only in practice |
| `tlapbot.nox.onl` | owncast bot (python) | Retired, not running. Do not recreate; if it comes back it is a new service, not a migration item |

So the tunnel that has to work on day one carries exactly two hostnames.

**The existing tunnel is token-based, i.e. remotely managed** (confirmed
2026-08-05 — the container runs `tunnel run` with `TUNNEL_TOKEN` and nothing
else). Its ingress rules live in the Cloudflare dashboard, not on the VM, so
there is no `config.yml` to transcribe. Read the mapping off Zero Trust →
Networks → Tunnels → Public Hostnames; that is the source data for both
`publicHosts` and the nginx vhosts, and nothing on the VM records it.

Note the `TUNNEL_TOKEN` is a full credential — base64 of account tag, tunnel ID
and tunnel secret, equivalent to a credentials JSON. Rotate rather than reuse if
it has ever been in a shared or committed file.

The NixOS module only supports **locally managed** tunnels: `credentialsFile`
plus ingress declared in nix, with no token option. That is the right direction
anyway — it is the difference between the routing living in this repo and living
in a dashboard — but it means the archivum tunnel is a new one, not a moved one.

**Use a second tunnel rather than moving the existing one.** Create a new tunnel
on archivum with its own credentials, and cut over one hostname at a time by
repointing that hostname's CNAME to `<new-tunnel-uuid>.cfargotunnel.com`.
Rollback is then a DNS change rather than a config restore, and the old tunnel
keeps serving whatever has not moved yet. Delete the old tunnel once both
hostnames have moved and soaked. This also sidesteps converting a
remotely-managed tunnel to a locally-managed one.

Do not run the *same* tunnel from two machines during the migration — Cloudflare
treats that as replicas and load-balances between them, which would send half
your requests to whichever box does not have the service yet.

- [x] **`services/cloudflared.nix` written.** All hostnames route through nginx
      at `https://127.0.0.1:443` with a per-host `originServerName`, so SNI
      matches the wildcard cert and nothing has to disable TLS verification on
      the loopback hop. `publicHosts` is an allowlist over a `http_status:404`
      catch-all, so a stray CNAME cannot on its own expose `kuma.nox.onl` or
      `syncthing.nox.onl`. No firewall ports — the tunnel dials out. Adding a
      public service is one nginx vhost plus one string.
- [x] Create the archivum tunnel — interactive, so it is a by-hand step:
      `cloudflared tunnel login` (browser, writes `cert.pem`) then
      `cloudflared tunnel create archivum` (writes `~/.cloudflared/<uuid>.json`).
      UUID into `tunnelId`, JSON into
      `hosts/archivum/secrets/cloudflared-tunnel.json`. `cert.pem` is only
      needed for management commands, not for `run`, so it stays out of the
      config.
- [ ] `jelly.nox.onl`: drop or repoint at cutover time, whichever you feel like.
- [ ] Cut over `party.nox.onl` first — owncast is the low-stakes one, and it
      proves the tunnel works end to end.
- [ ] `social.nox.onl` moves as part of the gotosocial procedure in Phase 5,
      not before.

### Resource budget (64 GB)

Capacity is not the constraint; *double caching* is the only thing worth
tuning. On ZFS, ARC and Postgres' `shared_buffers` cache the same blocks twice,
so the fix is to keep Postgres modest rather than generous:

| Consumer | Suggested | Note |
| --- | --- | --- |
| ZFS ARC | cap ~16–24 GB (`boot.kernelParams` / `zfs_arc_max`) | Linux default is 50 % of RAM = 32 GB, which is more than this workload needs |
| PostgreSQL | `shared_buffers` 2–4 GB | The whole VM lives in 4 GB today; a huge value would fight ARC, not help |
| syncthing | negligible | Scales with file count, not library size |
| UniFi OS Server (podman, bundles its own mongo) | ~4–8 GB | Ubiquiti's stated sizing; grows with retention |
| jellyfin | ~1–2 GB | VAAPI transcode, not CPU |
| Everything else + slack | remainder | Comfortable |

Placement matters more than sizing: keep `/var/lib/postgresql` on the NVMe
`rpool` (it already is, via `rpool/var`) and *not* on spinning `tank`. Bulk
data is the opposite — photos and media belong on `tank`, where capacity and
snapshots matter more than latency.

If you want the last few percent, a dedicated dataset for Postgres with
`recordsize=16K` and `atime=off` matches its page size, and `full_page_writes`
can safely be turned off on ZFS since CoW makes torn pages impossible. Both are
optimisations, not prerequisites.

## Phase 3 — TrueNAS data

Both ends are ZFS, so this is `zfs send | zfs recv`, not rsync.

### 3a — Rebuild `tank` as raidz1 first

`tank` is currently a **3× 14 TB stripe — zero redundancy** (confirmed
2026-07-30; the creation command in `hosts/archivum/README.md` has no `raidz1`
vdev keyword). Any single disk failure loses the whole pool. This must be fixed
*before* TrueNAS data lands on it, because a stripe→raidz1 conversion is a
**destroy-and-recreate** — ZFS raidz expansion (2.4.3, in this nixpkgs) can add
a disk to an existing raidz vdev, but cannot convert a stripe into one.

The rebuild is cheap right now: everything on `tank` today is a copy of data
that exists in two other locations (confirmed 2026-07-30), so there is nothing
to evacuate and no Phase 1 dependency — this can happen immediately, and gets
strictly more expensive the longer it waits.

- [x] Sanity-check that nothing new landed: `zfs list -o space -r tank`, eyeball
      `tank/nox`.
- [x] Stop writers (qbittorrent, samba/nfs clients, jellyfin scans).
- [x] `zpool destroy tank`, then recreate with the same options **plus raidz1**
      (corrected command is in `hosts/archivum/README.md`).
- [x] Recreate the datasets (`tank/root`, `tank/media`, `tank/nox`,
      `tank/incomplete`), restart writers, re-copy or re-download at leisure.
- [x] Verify with `zpool status tank` — the vdev must read `raidz1-0`.
- [x] Update `hosts/archivum/README.md`: make the raidz1 command the canonical
      one and drop the stripe warning.

Post-rebuild capacity is ≈ 25 TiB usable (down from ≈ 38 TiB) — check incoming
TrueNAS data fits with headroom before Phase 3b. One disk of parity still means
a resilver at 14 TB capacity runs for many hours under full load — the window
where a second failure is fatal — which is why the Phase 1 offsite backup still
precedes the *data migration*, even though it no longer gates the rebuild. If
you later want more capacity, raidz expansion makes adding a fourth disk a
non-destructive operation.

### 3b — Data migration

- [ ] Inventory datasets: names, sizes, snapshot layout, active writers.
- [ ] Confirm `tank` headroom alongside existing media (snapshots hold space
      too).
- [ ] Seed with `zfs send -R` of a base snapshot while TrueNAS stays live.
- [ ] Incremental `zfs send -i` passes until the delta is small.
- [ ] Final pass with writers stopped, then flip clients to archivum's
      samba/nfs shares.
- [ ] Reconcile permissions: archivum's `media` share is deliberately
      guest-writable. Anything arriving with stricter ACLs needs an explicit
      decision rather than silently inheriting that.
- [ ] Repoint the Hetzner backup source to archivum; run both for one cycle
      before disabling the TrueNAS job.

## Phase 4 — Quick wins (no dependencies)

Low risk, builds confidence, shrinks the Docker VM.

- [x] **Photo backup (replaces immich).** `services/syncthing.nix` — the phone's
      camera roll into `tank/photos/iphone`, plus a read-only `photos` samba
      share for browsing. Inert until
      `hosts/archivum/secrets/syncthing-iphone-id` holds the phone's device ID;
      pairing is the one manual step. Setup is in `hosts/archivum/README.md`.

      The folder is **send-only on the phone, receive-only on archivum**, so a
      deletion cannot propagate in either direction, with a year of staggered
      versioning under that. `tank/photos` gets the longest sanoid retention on
      the box (30 daily / 12 monthly / 3 yearly) and is in the restic paths — it
      is the only dataset on `tank` with no second copy anywhere.

      Needs `zfs create tank/photos` before the first rebuild.
- [ ] **Rescue the existing immich library.** Before the Docker VM goes away,
      copy `UPLOAD_LOCATION/library/` out of the immich container — those are
      the original files, and they are what survives. The immich database is
      *not* worth rescuing: albums and faces are rebuildable or expendable, and
      keeping the DB is what forced the migration in the first place. Drop the
      files into `tank/photos/immich-export/` alongside the syncthing folder,
      confirm a restic run has carried them offsite, and only then delete the
      container.
- [ ] **Minecraft** — delete. Archive the world dir somewhere cheap first;
      rebuild with `services.minecraft-server` if anyone ever asks.
- [ ] **openspeedtest** — the one service with no module. `oci-containers`
      podman container, commented as temporary.
- [ ] **speedtest-tracker** — `services.speedtest-tracker`. Needs an `APP_KEY`
      secret; can use the shared Postgres or its own SQLite.
- [ ] **prowlarr** — `services.prowlarr`. Stop the container, copy its config
      dir (SQLite) into `/var/lib/prowlarr`, start. Verify indexers still
      resolve. Note it currently has no *arr apps downstream.
- [ ] **owncast** — `services.owncast`. Occasional use and no VODs, so a fresh
      install is fine: stand it up, re-enter the stream key and the R2 settings
      (endpoint, bucket, access key, secret) in the admin UI. Copying the old
      data dir is optional convenience, not a requirement. Jot the R2 settings
      down before the VM goes away so you are not hunting for them afterwards.
- [ ] **homepage vs glance** — you would be running two dashboards.
      `services.homepage-dashboard` (1.12.3) exists if homepage wins; otherwise
      port the tiles into the existing glance config and drop homepage.
- [ ] **qbittorrent** — do *not* migrate the container; archivum's native
      instance is VPN-confined and already points at `/mnt/tank/media`. To keep
      seeding, copy `BT_backup/` from the container's state into
      `/var/lib/qbittorrent` while stopped. Otherwise just stop the container.

## Phase 5 — Heavy / stateful

One at a time, each stop → dump → restore → verify → soak.

- [ ] **gotosocial** — see the dedicated procedure below.
- [ ] **jellyfin** — already running on archivum, so this is a state merge, not
      an install. Decide whether the VM's watch history and metadata matter. If
      yes: stop both, copy `/var/lib/jellyfin` from the VM (config, DB, metadata)
      onto archivum, and make sure library paths resolve to `/mnt/tank/media`
      post-Phase-3. Version check: archivum imports the *unstable* jellyfin
      module; do not restore a newer library DB into an older server.
- [ ] **unifi → UniFi OS Server** — see the dedicated procedure below.
      `hosts/ubiqium/services/unifi.nix` is not carried over; ubiqium retires
      with the hypervisor.

### unifi: straight to UniFi OS Server

Status as of July 2026: Ubiquiti has **deprecated the standalone UniFi Network
Application** and points self-hosters at **UniFi OS Server**. The standalone app
is in maintenance mode — security and bug fixes, no new features; Organizations,
Site Magic, Teleport and Identity are UniFi-OS-only.

Decision: **go straight to UOS Server** via `github:rcambrj/unifi-os-server`,
rather than migrating to the deprecated `services.unifi` and again later. One
migration instead of two, onto the platform Ubiquiti actually develops. SSO
account already exists, so that dependency is not a blocker.

Accepted with open eyes: the flake self-describes as *"Current state: unstable"*,
is not affiliated with Ubiquiti, runs UOS Server in **podman containers**, and
auto-updates weekly. This is the one permanent podman service on archivum — the
standing "podman only as a temporary fallback" preference does not apply here,
because there is no native alternative that is not deprecated.

Sizing is a non-issue: UOS Server wants ~4 vCPU / 4–8 GB RAM / 40 GB SSD.

#### Networking: single-homed on VLAN 201

archivum is `10.201.3.229` on VLAN 201; the management network is VLAN 99
(`10.99.0.0/24`) and the old controller was `10.99.0.16`. archivum's switch port
has access to VLAN 99, but **we are not using it** — no tagged VLAN leg, no
second IP. The controller runs on archivum's existing address.

Rationale: the only thing a VLAN 99 leg bought was preserving `10.99.0.16` so
devices would not need re-pointing. With **two APs**, re-pointing is two SSH
commands. That is not worth dual-homing the server, the per-interface firewall
discipline it forces, or the `ip_forward` segmentation question it raises.

The module runs **one privileged podman container** (systemd inside) with
published port mappings. `uosSystemIP` is written into `system.properties` as
`system_ip` — the inform address handed to devices — so it must be archivum's
real LAN IP, never the `127.0.0.1` default.

```nix
services.unifi-os-server = {
  enable = true;
  uosSystemIP = "10.201.3.229";
  openFirewallUiPort = true;
  openFirewallServicePorts = true;
  # port defaults are fine: UI 11443, inform 8080, controller 8443,
  # speedtest 6789, captive portal 8880/8843, STUN 3478/udp, discovery 10001/udp
};
```

Consequences to handle:

- **The APs live on VLAN 99 and the controller now lives on VLAN 201**, so allow
  VLAN 99 → `10.201.3.229` on tcp 8080 and 8443, plus udp 3478, at the gateway.
  Without that the APs simply never check in.
- **Point each AP at the new controller once**: `ssh ubnt@<ap-ip>` then
  `set-inform http://10.201.3.229:8080/inform`. Two devices, one time.
- **Broadcast discovery is irrelevant here** — it would not cross VLANs anyway,
  container or not. New devices get the same `set-inform` treatment, or adopt
  via the mobile app.

Prerequisites:

- [ ] Add the flake input, wire its module into archivum in `flake.nix`.
- [ ] Enable podman and `virtualisation.oci-containers.backend = "podman"` —
      the module asserts both. Note `hosts/unused/services/docker.nix` is
      *docker*; do not adopt it, write the podman config fresh.

Cutover:

- [ ] **Take a `.unf` backup from the current controller and keep it forever.**
      Settings → System → Backups. This is the universal rollback artifact: it
      restores into UOS Server *or* into a classic controller, so it is the
      escape hatch if the flake turns out to be too unstable to live with.
- [ ] Stand up UOS Server on archivum, complete the setup wizard, install the
      Network application inside it.
- [ ] Restore the `.unf` under Settings → System → Backups → Upload Backup.
- [ ] Open VLAN 99 → `10.201.3.229` (tcp 8080/8443, udp 3478) at the gateway.
- [ ] `set-inform` both APs at the new address; they appear in the restored
      controller within a minute or two.
- [ ] Old controller VM can be shut down once both APs are checking in.
- [ ] Expect a short window where the network is unmanaged. APs keep forwarding
      traffic throughout; you lose visibility and config changes, not the
      network.
- [ ] Add UOS Server's state to restic once it is up.

Fallback if it does not work out: `services.unifi` (unifi 10.2.105 in nixpkgs,
two maintainers, a NixOS VM test) still exists and the preserved `.unf` restores
into it. Note the version rule — a backup restores into an equal or newer
version, never older — so keep the *pre-migration* backup rather than relying on
one taken after UOS has upgraded the Network app.

### gotosocial in detail

The one service where the database *is* the thing being migrated. Media files
can be re-fetched or lived without; the DB holds the instance's identity — the
actor keypair remote servers have cached, every follow relationship in both
directions, and the delivery queue. Restore it wrong and the instance cannot
prove it is itself.

**This service is an exception to guiding rule 3: never run both copies at
once.** Two servers answering for the same domain will both consume the inbox,
both sign deliveries, and diverge — with no clean way to merge them afterwards.
It is stop-old → migrate → start-new, in that order, with the old one kept
*stopped but intact* as the rollback.

Preparation:

- [ ] Record the running container's exact GtS version. Migrations run forward
      on startup, so older → 0.21.3 is fine; **newer → 0.21.3 is not**. If the
      container is ahead of nixpkgs, pin `services.gotosocial.package` to match
      before migrating and upgrade afterwards as a separate step.
- [ ] Check the storage backend: local disk or S3/R2 (you already use R2 for
      owncast). If it is R2, media does not move at all — only credentials and
      bucket config carry over, which makes this considerably easier.
- [ ] Transcribe the live `config.yaml` into `services.gotosocial.settings`.
      `host` must stay byte-identical; also carry over `account-domain` if a
      split-domain setup is in use, plus `protocol`, storage and db settings.
      The `host` value is not a configuration preference — it is the instance's
      name in every remote database that knows about you.
- [ ] Decide the DB password path under `secrets/`, or use unix-socket auth
      against the shared Postgres.

### Keeping the window short

The concern is being penalised by peers for an outage. Worth aiming at the right
risk: peers do not blacklist for downtime. Mastodon has a *delivery
availability* mechanism (an `unavailable` state at
`/admin/instances?availability=unavailable`, added in mastodon/mastodon#15771),
but it is reversible suppression after repeated failures, and it clears once you
are reachable again. Exact thresholds unconfirmed — do not plan against a
specific day-count.

The thing that does permanent damage is the split-brain this section already
forbids: two servers answering for one domain leave remote instances with
missing posts, broken threads and inconsistent follow state, and no retry fixes
that. **Do not trade split-brain risk for a shorter window.** The goal is a
short, rehearsed, single-writer cutover — not a minimal one. 10–20 minutes is
the target and is comfortably within tolerance.

So keep everything out of the window that can be:

- [ ] **Rehearse the dump/restore against a scratch DB on archivum**, days
      ahead. This is the highest-value prep step by a distance: it produces a
      measured duration instead of an estimate, and it proves the 16 → 18
      restore path before it is load-bearing. An unrehearsed cutover is how ten
      minutes becomes two hours. Do it twice; the second should be boring.
- [ ] **Prune remote media cache first.** It shrinks the copy and the dump
      together, and it is the cheapest size reduction available.
- [ ] **Bulk-copy media in advance** if storage is local, repeatedly over the
      preceding days, so the in-window pass is only a delta. On R2 this step is
      zero. Target a `tank` dataset — it grows without bound, so it does not
      belong on `rpool`.
- [ ] **Pre-build everything else**: Postgres role and database, the
      `services.gotosocial` unit present but stopped, config transcribed and
      evaluated. TLS is already covered by archivum's `*.nox.onl` wildcard, so
      no certificate is issued inside the window.

Rejected: logical replication from 16 to 18 for a near-zero window. It does not
replicate sequences, so they need hand-syncing — and this database *is* the
instance identity. That is exactly where a subtle error is unrecoverable rather
than merely annoying.

Cutover — only the delta belongs in here:

- [ ] Pick a quiet window. Stop the container. Leave it stopped for the rest of
      the procedure.
- [ ] Final `pg_dump` of the gotosocial DB with the target version's client
      (18.x), and restore into the shared Postgres.
- [ ] Final media rsync — the delta only.
- [ ] Start gotosocial, watch the first-run migration log complete before
      touching anything else.
- [ ] Cut the ingress. **Stop the VM's `cloudflared` connector first.**
      `cloudflared` supports multiple replicas of one tunnel for HA and
      Cloudflare distributes requests across connectors, so leaving the old one
      running is split-brain by default — and it is why the tunnel cannot be
      used for a graceful overlap. Stopping the app is not enough; stop the
      connector.

      This is the cutover moment and therefore the rollback: stop archivum's
      connector and gotosocial, start the VM's, and the old container is still
      intact behind it. That rollback stays valid only until the new instance
      federates — after the first inbox delivery lands on archivum, going back
      means losing whatever arrived. Verify quickly, in that order.

Verification — do all of these before declaring it done:

- [ ] `/.well-known/webfinger?resource=acct:<user>@<domain>` resolves.
- [ ] The instance actor fetches cleanly (`curl -H 'Accept: application/activity+json' https://<domain>/users/<user>`).
- [ ] A post from your account appears on a remote instance you follow — this
      is the real test that the signing key survived.
- [ ] An interaction *from* a remote account arrives in your inbox.
- [ ] Avatars, headers and media attachments load (proves storage config).
- [ ] Old posts still render their attachments, not just new ones.
- [ ] Add the DB and media to restic before the soak period, not after.

Only once all of that passes should the old container be deleted rather than
merely stopped.

## Phase 6 — fabricum's fate

fabricum is a Proxmox VM, so retiring the host retires it. Options, in my order
of preference:

1. **Fold its role into archivum** — one fewer machine; costs the separation
   between "server" and "place I break things".
2. **microvm.nix or nixos-container on archivum** — keeps isolation and the
   `flake.nix` entry, adds machinery.
3. **Move to existing hardware** (desktop/laptop/mini PC) — keeps a real dev
   box, costs whatever it draws.

Whichever wins: `flake.nix`, `hosts/fabricum/` and the auto-update service need
updating, and the repo checkout that auto-updates pull from currently lives at
`/home/nox/etc/nixos` on fabricum.

## Phase 7 — Decommission

- [ ] Final backup + snapshot of every VM disk image, archived off the Proxmox
      host.
- [ ] Power off Proxmox, leave disks intact for 4–6 weeks of archivum running
      everything.
- [ ] Re-measure power draw against the Phase 0 baseline.
- [ ] Prune the repo: `hosts/unused/`, `hosts/ubiqium/` (if retired),
      dead `flake.nix` entries.
- [ ] Update `CLAUDE.md` — it still claims four active hosts and nixpkgs/state
      version 25.11, while `flake.nix` tracks nixos-26.05.

## Risks

| Risk | Mitigation |
| --- | --- |
| Backup gap between TrueNAS shutdown and archivum's job working | Phase 1 backup + restore test precedes Phase 3; overlap one cycle |
| **`tank` is currently a stripe — zero redundancy until the Phase 3a rebuild** | Rebuild as raidz1 immediately (Phase 3a) — nothing on it is a sole copy today, so the rebuild is free; it stops being free once TrueNAS data lands |
| Everything then on one box with one raidz1 pool — one disk of parity, long resilver window on 14 TB drives | Offsite restic before Phase 3, ZFS snapshots, tested restores, smartd alerts wired up, UPS |
| Photos exist only on the phone until syncthing is paired, and iOS syncs only in foreground/background windows rather than continuously | Do not export the immich library out of the old container until `tank/photos` has a full copy and one restic cycle has carried it offsite. Treat "same-day offsite" as untrue for photos |
| gotosocial domain or identity change | Domain is immutable in practice — keep it byte-identical |
| UniFi OS Server flake is third-party and self-described as unstable, and sits in the nightly auto-update path | Preserve the pre-migration `.unf` as a universal rollback; `services.unifi` remains a working fallback. A flake update that fails to build stops before activation |
| `tank` fills during data migration | Check headroom before the first send |
| ZFS ARC and Postgres `shared_buffers` double-caching the same blocks | Cap `zfs_arc_max`, keep `shared_buffers` small — see the Phase 2 budget |
| `secrets/*` are read into the world-readable nix store — now including the Storage Box password, since Hetzner offers no key auth | Existing behaviour, not a regression; the subaccount is scoped to its own directory, and restic's own encryption is what actually protects the backup. **Closed by the sops-nix item in Phase 2**, which is where this stops being an accepted tradeoff |

## Open questions

- Keep glance, homepage, or something else? (Undecided — homepage is my
  recommendation, but nothing is written yet.)
