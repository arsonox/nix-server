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

## Samba

After setting up the system, set up samba login with `sudo smbpasswd -a nox`.

## Offsite backups (Hetzner Storage Box)


# run the first backup by hand

```bash
sudo nixos-rebuild switch --flake .#archivum
sudo systemctl start restic-backups-storagebox.service
journalctl -fu restic-backups-storagebox.service
```

`initialize = true` creates the repository on first run.

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