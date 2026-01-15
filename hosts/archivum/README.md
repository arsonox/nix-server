# The Archivum

This is Nox' NAS.

## Disk Configuration

```
zpool create -o ashift=12 -o autotrim=on -O atime=off -O acltype=posixacl -O xattr=sa -O dnodesize=auto -O normalization=formD -O compression=zstd -O mountpoint=none rpool /dev/disk/by-id/nvme-KIOXIA-EXCERIA_PLUS_G3_SSD_8E9KF1QUZ0E9-part2

zfs create zpool/root
zfs create zpool/nix
zfs create zpool/var
zfs create zpool/home

zpool create -o ashift=12 -o autotrim=on -O atime=off -O acltype=posixacl -O xattr=sa -O dnodesize=auto -O normalization=formD -O compression=zstd -O mountpoint=none tank ata-WDC_WUH721414ALE6L4_9MGEJ6BJ ata-WDC_WUH721414ALE6L4_9MGRPHTT ata-WDC_WUH721414ALE6L4_81G6Y31V
zfs create tank/root
zfs create tank/media
zfs create tank/nox
zfs create tank/incomplete
```

## Samba

After setting up the system, set up samba login with `sudo smbpasswd -a nox`.