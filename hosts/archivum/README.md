# The Archivum

This is Nox' NAS.

## Disk Configuration

```
zpool create -o ashift=12 -o autotrim=on -O atime=off -O acltype=posixacl -O xattr=sa -O dnodesize=auto -O normalization=formD -O compression=zstd -O mountpoint=none rpool /dev/disk/by-id/nvme-KIOXIA-EXCERIA_PLUS_G3_SSD_8E9KF1QUZ0E9-part2

zfs create zpool/root
zfs create zpool/nix
zfs create zpool/var
zfs create zpool/home

zpool create -o ashift=12 -o autotrim=on -O atime=off -O acltype=posixacl -O xattr=sa -O dnodesize=auto -O normalization=formD -O compression=zstd -O mountpoint=none tank raidz1 ata-WDC_WUH721414ALE6L4_9MGEJ6BJ ata-WDC_WUH721414ALE6L4_9MGRPHTT ata-WDC_WUH721414ALE6L4_81G6Y31V
zfs create tank/root
zfs create tank/media
zfs create tank/nox
zfs create tank/incomplete
zfs create tank/photos
```

**A dataset is not mounted until `hardware-configuration.nix` says so.** Every
`tank/*` dataset has `mountpoint=none` and is mounted by an explicit
`fileSystems."/mnt/tank/<name>"` entry with `options = [ "zfsutil" ]`.

### Current layout

```
rpool   928G    nvme0n1p2            KIOXIA EXCERIA PLUS G3 1TB
tank   38.2T    raidz1, 3× 14TB      25.3T usable

nvme1n1, nvme2n1   1TB each, unused  (identical model to rpool's disk)
```

The two spares are going into `rpool` as a 3-way mirror — see below. They are
*not* an L2ARC candidate for `tank`: `l2arc_noprefetch=1` means sequential
reads are never cached, and streaming media arrives entirely through prefetch.
If `tank` ever needs help it is a mirrored **special vdev** (metadata + small
blocks), not a cache device.

### Making rpool a 3-way mirror

`rpool` is a single disk holding `/`, `/nix`, `/home` and `/var` — every
service's state and the postgres cluster. `tank` has parity and `rpool` does
not, which is backwards: the pool holding the irreplaceable data is the one
without redundancy, and restic/`pg_dumpall` are nightly, so a disk failure at
23:00 costs a full day.

Both spare NVMes are the same model, so this is two online commands, no
downtime, nothing to move. The disks carry stale ZFS labels from an old pool,
hence the `labelclear` (2026-08-08: confirmed nothing on them is wanted).

```bash
sudo zpool labelclear -f /dev/nvme1n1p1
sudo zpool labelclear -f /dev/nvme2n1p1

# attach both to the existing vdev, one at a time
sudo zpool attach rpool \
  nvme-KIOXIA-EXCERIA_PLUS_G3_SSD_8E9KF1QUZ0E9-part2 \
  /dev/disk/by-id/nvme-KIOXIA-EXCERIA_PLUS_G3_SSD_8EAKF1F8Z0E9
zpool status rpool                     # let the resilver finish (13G — seconds)

sudo zpool attach rpool \
  nvme-KIOXIA-EXCERIA_PLUS_G3_SSD_8E9KF1QUZ0E9-part2 \
  /dev/disk/by-id/nvme-KIOXIA-EXCERIA_PLUS_G3_SSD_8E7KF3ZKZ0E9
zpool status rpool                     # vdev must now read `mirror-0` with 3 members
```

**`attach`, never `add`.** `add` appends a second top-level vdev, striping the
pool across it — the opposite of what is wanted, and not undoable. `ashift=12`
matches automatically since the disks are identical.

Three-way rather than two-way-plus-hot-spare: the third copy is already
resilvered, so there is no activation to trust and no window at all. A hot
spare's only advantage is replacing a disk without a human, and ZFS faults
already push to ntfy within seconds — so it would add a mechanism that fires
once a decade, for a benefit the alerting already covers.

**`/boot` is not covered by this.** It is a plain vfat partition on
`nvme0n1p1`, and `systemd-boot` has no equivalent of grub's `mirroredBoots`. If
`nvme0n1` dies the pool survives on the other two, but the machine will not
boot until an ESP is recreated — from the installer, or by hand onto a
surviving disk. Losing that disk costs an hour, not the machine.

## Samba

After setting up the system, set up samba login with `sudo smbpasswd -a nox`.

### Discovery

Three separate mechanisms, one per client family:

| Clients | Mechanism | Where |
| --- | --- | --- |
| macOS, Linux | mDNS / Bonjour | `services/avahi.nix` |
| Windows | WS-Discovery | `services.samba-wsdd` |
| — | NetBIOS | off; `nmbd.enable = false` |

```bash
avahi-browse -at            # what this host is advertising
getent hosts archivum.local # does resolution work at all
```

For Avahi, generate a list of allowed interfaces with
```bash
cd /sys/class/net && for i in *; do [ -e "$i/device" ] && echo "$i"; done
```

## Offsite backups (Hetzner Storage Box)


# run the first backup by hand

```bash
sudo nixos-rebuild switch --flake .#archivum
sudo systemctl start restic-backups-storagebox.service
journalctl -fu restic-backups-storagebox.service
```

`initialize = true` creates the repository on first run.

### What gets backed up

The roots are broad on purpose — `/var/lib`, `/home`, `tank/nox`,
`tank/photos` — so a new service's state is backed up without anyone
remembering to ask. An allowlist would get that wrong silently, and you would
find out at restore time.

Carving something back out is the opt-in, and it belongs in the file for the
service that owns the path, not in `restic.nix`:

```nix
archivum.backup.exclude = [ "/var/lib/foo/cache" ];
archivum.backup.paths = [ "/var/backup/foo" ];   # state outside the roots
```

Delete the service, and its exclusions leave with it.

### Restore test

```bash
sudo restic-storagebox snapshots
sudo restic-storagebox restore latest --target /mnt/tank/restore-test --include /mnt/tank/nox
sudo diff -r /mnt/tank/nox /mnt/tank/restore-test/mnt/tank/nox && echo "restore verified"
sudo rm -rf /mnt/tank/restore-test
```

## Photos (syncthing)

`services/syncthing.nix` pulls the phone's camera roll into
`/mnt/tank/photos/iphone` and exposes it as a **read-only** samba share. It
replaces immich: see the decision note in `MIGRATION.md`.

### GUI password

`https://syncthing.nox.onl` via nginx; the GUI listens on loopback only. Set the
password before pairing anything.

```bash
echo -n 'the password' > hosts/archivum/secrets/syncthing-gui-password
git add hosts/archivum/secrets/syncthing-gui-password
sudo nixos-rebuild switch --flake .#archivum
```

Behind a proxy, syncthing 403s every request with "Host check error", it
rejects any `Host` that is not localhost or an IP, to blunt DNS rebinding. Hence
`gui.insecureSkipHostcheck`.


### Pairing the phone

On the phone, install SyncTrain (free) or Möbius Sync (paid), add archivum as a
device, and share the camera roll folder **as send-only**.

After pairing:

```bash
echo "AAAAAAA-BBBBBBB-..." > hosts/archivum/secrets/syncthing-iphone-id
git add hosts/archivum/secrets/syncthing-iphone-id   # flakes ignore untracked files
sudo nixos-rebuild switch --flake .#archivum
```

A device ID is a public key fingerprint, not a secret. It lives under
`secrets/` only because that is where this repo keeps gated files.

`overrideDevices`/`overrideFolders` are on, so anything added through the GUI is
removed on the next restart.


## PostgreSQL

One shared instance, `services/postgresql.nix`, unix socket only. Apps declare
their own database and role; nothing is declared centrally.

The major version is **pinned by name** (`postgresql_18`). Do not remove the
pin: without it the module derives the major from `system.stateVersion`.
The procedure is in `POSTGRESQL-UPGRADES.md`.

```bash
sudo -u postgres psql              # socket auth, no password
sudo -u postgres psql -l           # what exists
```

### Backups

`services.postgresqlBackup` writes a `pg_dumpall` to
`/var/backup/postgresql/all.sql.zstd` at 01:15, an hour before restic. Restic
backs up that dump and **excludes `/var/lib/postgresql`**.

Restoring means replaying the dump, not dropping files back in place:

```bash
zstd -dc /var/backup/postgresql/all.sql.zstd | sudo -u postgres psql -f -
```

### Migrating from the old VM

Dump with the **target** version's `pg_dumpall` — new client against old server
is the supported direction, never the reverse. The VM only has 16's binaries,
so run it from archivum:

```bash
sudo -u postgres pg_dumpall -h <vm> -U postgres > /var/tmp/vm.sql
sudo -u postgres psql -f /var/tmp/vm.sql
```

Check first that the VM's postgres listens somewhere archivum can reach and
that its `pg_hba.conf` allows it. If it is bound to localhost or a docker
bridge, that is a prerequisite, not a surprise to hit halfway through.

## UniFi

`services/unifi.nix` runs **UniFi OS Server** from
`github:rcambrj/unifi-os-server`, running one privileged podman container.

UI at `https://unifi.nox.onl`, or directly on `https://10.201.3.229:11443`.
Direct port stays open as fallback.

Devices use 8080 (inform), 8443 and 3478/udp.

Two UniFi quirks the vhost works around: it validates `Host` as part of its
CSRF handling, so the header must pass through unrewritten (NixOS'
`recommendedProxySettings` does this), and it rejects a proxied `Origin` on the
websocket path, so that header is stripped on `/wss/`.

Point a device at the controller:

```bash
ssh ubnt@<ap-ip>
set-inform http://10.201.3.229:8080/inform
```

### Backups

Turn on `.unf` autobackups in the UI (Settings → System → Backups). They land
in the state dir and restic picks them up. Restic **excludes**
`/var/lib/unifi-os-server/mongodb`.

## Baserow

`services/baserow.nix` runs the **all-in-one** image
(`baserow/baserow`, digest-pinned) in podman. UI at 
`https://baserow.nox.onl`.

### Setup

Baserow is inert until `secrets/baserow.env` exists. Create it with:

```bash
{
  echo "DATABASE_PASSWORD=$(nix run nixpkgs#openssl -- rand -hex 32)"
  echo "SECRET_KEY=$(nix run nixpkgs#openssl -- rand -hex 32)"
  echo "BASEROW_JWT_SIGNING_KEY=$(nix run nixpkgs#openssl -- rand -hex 32)"
} > hosts/archivum/secrets/baserow.env
git add hosts/archivum/secrets/baserow.env
```

### The data dir needs mode 0755, not just the right owner

`/var/lib/baserow` is `0755` owned by **UID/GID 9999**. Both halves matter, and
the mode is the one that actually bites.

The image bakes in 9999 and runs caddy, the backend and celery as it — but not
redis, which supervisor starts as its own `redis` user (`user=redis` in
`supervisor/includes/disabled/embedded-redis.conf`). `baserow.sh` chowns
`DATA_DIR/redis` to `redis:redis` on every start, so that subdirectory is
always right. What breaks is the **parent**: at `0700` the redis user cannot
traverse into `DATA_DIR` to reach it, no matter who owns it. Redis then dies
with `FATAL CONFIG FILE ERROR … 'dir "/baserow/data/redis"' Permission denied`,
and every migration traceback after that is a cascade from that one line.

`0755` is simply what upstream's own `mkdir -p` produces, so this matches what
the image expects rather than second-guessing it. The sensitive files under
`DATA_DIR/secrets` are `chmod 600`ed by baserow itself.

Upstream avoids this by recommending a named volume, which inherits ownership
from the image. That is the wrong trade here — a named volume lives under
`/var/lib/containers`, which restic excludes as re-pullable, so the user
uploads would silently stop being backed up. Hence a bind mount with the
ownership set on the host by tmpfiles.

Do **not** `chown -R 9999:9999` the tree to fix this — that takes
`DATA_DIR/redis` away from the redis user. Only the top level is ours; the
entrypoint owns the subdirectories:

```bash
sudo chmod 0755 /var/lib/baserow
sudo chown 9999:9999 /var/lib/baserow
sudo systemctl restart podman-baserow
```

### Backups

The tables live in postgres, so `pg_dumpall` already covers them.
`/var/lib/baserow` is backed up for the user-uploaded files; restic
**excludes** `/var/lib/baserow/redis`

## Snapshots

`services/sanoid.nix` snapshots `rpool/{root,var,home}`, `tank/nox`,
`tank/photos` and `tank/media` hourly, and prunes automatically. `rpool/nix` and
`tank/incomplete` are deliberately excluded.
`tank/photos` keeps the longest tail (30 daily / 12 monthly / 3 yearly)

```bash
zfs list -t snapshot -o name,used,creation -s creation | tail
zfs rollback tank/nox@autosnap_2026-08-03_12:00:00_hourly   # the undo button
```

## Alerting

`services/notifications.nix` funnels restic failures, smartd warnings and ZFS
events (scrubs, resilvers, checksum errors, pool degradation) into one
`notify-mail` command. It always writes to the journal, and additionally pushes 
to the ntfy server on **quaesitum**

Attach it to any future unit with `onFailure = [ "notify-failure@%n.service" ]`.

## Reverse proxy

`services/nginx.nix` needs `secrets/acme-cloudflare.env`, containing a 
Cloudflare token scoped to `Zone:DNS:Edit` on `nox.onl`:

secrets/acme-cloudflare.env
```
CF_DNS_API_TOKEN=...
```

If the token has an **IP address filter**, it must list the IPv6 prefix as well
as the IPv4 address — archivum prefers v6, so a v4-only filter denies the API
call and the certificate silently stays self-signed.

## Cloudflare tunnel

`services/cloudflared.nix` is the only route in from outside the LAN. Everything
goes through nginx, so adding a public service is one vhost plus one string in
`publicHosts` — and `publicHosts` is an allowlist over a 404 catch-all, so
creating a CNAME is not on its own enough to expose a vhost.

Creating the tunnel is interactive and has to be done by hand:

```bash
cloudflared tunnel login             # browser; writes ~/.cloudflared/cert.pem
cloudflared tunnel create archivum   # writes ~/.cloudflared/<uuid>.json
```

Put the UUID in `tunnelId` at the top of `services/cloudflared.nix`. It is not
a secret, it is published in DNS as `<uuid>.cfargotunnel.com` and the JSON at
`hosts/archivum/secrets/cloudflared-tunnel.json`:

```bash
git add hosts/archivum/secrets/cloudflared-tunnel.json
sudo nixos-rebuild switch --flake .#archivum
```

`cert.pem` is only needed for management commands (`create`, `route`, `delete`),
never for `run`, so it does not belong in the config.

Point a hostname at the tunnel with `cloudflared tunnel route dns archivum
<hostname>`, or by creating the CNAME by hand.

**Never run the same tunnel from two machines.** Cloudflare treats multiple
connectors as replicas and load-balances across them, so half the requests would
land on whichever box does not have the service.