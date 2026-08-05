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

```bash
echo -n 'the password' > hosts/archivum/secrets/syncthing-gui-password
git add hosts/archivum/secrets/syncthing-gui-password
sudo nixos-rebuild switch --flake .#archivum
```


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