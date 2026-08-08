{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.archivum.backup;

  targetFile = ../secrets/storagebox-target;
  sshPasswordFile = ../secrets/storagebox-password;
  passwordFile = ../secrets/storagebox-restic-password;

  configured =
    builtins.pathExists targetFile
    && builtins.pathExists sshPasswordFile
    && builtins.pathExists passwordFile;

  target =
    let
      r = builtins.tryEval (lib.removeSuffix "\n" (builtins.readFile targetFile));
    in
    if configured && r.success then r.value else "";

  sftpCommand = lib.concatStringsSep " " [
    "sftp.command='${lib.getExe pkgs.sshpass}"
    "-f ${toString sshPasswordFile}"
    "ssh -p 23"
    "-o StrictHostKeyChecking=accept-new"
    "-o PubkeyAuthentication=no"
    "-o PreferredAuthentications=password"
    "${target} -s sftp'"
  ];

  repository = "sftp://${target}:23/restic/archivum";
in
{
  options.archivum.backup = {
    paths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Extra paths to back up, for state that lives outside the roots below.
        Declare these in the file for the service that owns the path.
      '';
    };

    exclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Paths carved back out of the backup roots. Declare these in the file
        for the service that owns the path.
      '';
    };
  };

  config = {
    warnings = lib.optional (!configured) ''
      archivum has no offsite backup: secrets/storagebox-{target,password,restic-password}
      are missing, so services.restic.backups.storagebox is not configured.
    '';

    services.restic.backups = lib.mkIf configured {
      storagebox = {
        inherit repository;
        passwordFile = toString passwordFile;
        extraOptions = [ sftpCommand ];
        initialize = true;

        paths = [
          "/var/lib"
          "/home"
          "/mnt/tank/nox"
          "/mnt/tank/photos"
        ]
        ++ cfg.paths;

        exclude = [
          "/var/lib/clamav" # signature database, re-downloaded
          "/var/lib/containers" # image store, re-pullable
          "/var/lib/docker"
          "/var/lib/systemd/coredump"
          "/home/*/.cache"
          "/home/*/.local/share/Trash"
        ]
        ++ cfg.exclude;

        extraBackupArgs = [
          "--exclude-caches"
          "--tag archivum"
        ];

        timerConfig = {
          OnCalendar = "02:15";
          RandomizedDelaySec = "30m";
          Persistent = true;
        };

        pruneOpts = [
          "--keep-daily 14"
          "--keep-weekly 8"
          "--keep-monthly 12"
          "--keep-yearly 3"
        ];
      };
    };

    systemd.services.restic-check-storagebox = lib.mkIf configured {
      description = "restic repository check (storagebox)";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      onFailure = [ "notify-failure@%n.service" ];
      path = [ config.programs.ssh.package ];
      environment = {
        RESTIC_REPOSITORY = repository;
        RESTIC_PASSWORD_FILE = toString passwordFile;
        RESTIC_CACHE_DIR = "/var/cache/restic-backups-storagebox";
      };
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        CacheDirectory = "restic-backups-storagebox";
        CacheDirectoryMode = "0700";
      };
      script = ''
        ${lib.getExe pkgs.restic} -o ${sftpCommand} check --read-data-subset=5%
      '';
    };

    systemd.timers.restic-check-storagebox = lib.mkIf configured {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "monthly";
        RandomizedDelaySec = "6h";
        Persistent = true;
      };
    };

    systemd.services.restic-backups-storagebox.onFailure = lib.mkIf configured [
      "notify-failure@%n.service"
    ];
  };
}
