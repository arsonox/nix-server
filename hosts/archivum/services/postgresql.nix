{
  pkgs,
  ...
}:

{
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_18;

    settings = {
      shared_buffers = "2GB"; # small cache due to ZFS arc
      effective_cache_size = "8GB";
      maintenance_work_mem = "512MB";
      full_page_writes = false; # safe because the data directory is on ZFS
    };
  };

  services.postgresqlBackup = {
    enable = true;
    backupAll = true;
    compression = "zstd";
    compressionLevel = 9;
    startAt = "01:15"; # restic runs at 02:15
  };

  archivum.backup = {
    paths = [ "/var/backup/postgresql" ];
    exclude = [ "/var/lib/postgresql" ];
  };

  systemd.services.postgresql.onFailure = [ "notify-failure@%n.service" ];
  systemd.services.postgresqlBackup.onFailure = [ "notify-failure@%n.service" ];
}
