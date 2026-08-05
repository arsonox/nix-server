{
  lib,
  ...
}:

let
  deviceIdFile = ../secrets/syncthing-iphone-id;
  guiPasswordFile = ../secrets/syncthing-gui-password;

  configured = builtins.pathExists deviceIdFile;
  hasPassword = builtins.pathExists guiPasswordFile;

  deviceId =
    let
      r = builtins.tryEval (lib.removeSuffix "\n" (builtins.readFile deviceIdFile));
    in
    if configured && r.success then r.value else "";
in
{
  warnings = lib.optional (!configured) ''
    archivum syncs no photos: hosts/archivum/secrets/syncthing-iphone-id does
    not exist, so syncthing runs with no devices and no folders. Pair the phone
    in the GUI at https://syncthing.nox.onl, then write its device ID to that
    file — see hosts/archivum/README.md.
  ''
  ++ lib.optional (!hasPassword) ''
    Syncthing has no password. Anyone who can reach https://syncthing.nox.onl
    can add folders and devices until it does.
  '';

  services.syncthing = {
    enable = true;
    group = "photos";
    guiAddress = "127.0.0.1:8384";
    guiPasswordFile = lib.mkIf hasPassword (toString guiPasswordFile);
    openDefaultPorts = true;

    overrideDevices = true;
    overrideFolders = true;

    settings = {
      options.urAccepted = -1; # no usage reporting

      gui = {
        user = "nox";
        insecureSkipHostcheck = true;
      };

      devices = lib.mkIf configured {
        iphone.id = deviceId;
      };

      folders = lib.mkIf configured {
        "iphone-camera" = {
          path = "/mnt/tank/photos/iphone";
          devices = [ "iphone" ];
          type = "receiveonly";

          versioning = {
            type = "staggered";
            params = {
              cleanInterval = "3600";
              maxAge = "31536000"; # 1 year
            };
          };
        };
      };
    };
  };

  users.groups.photos.members = [ "nox" ];

  systemd.tmpfiles.rules = [
    "d /mnt/tank/photos 2750 syncthing photos -"
    "d /mnt/tank/photos/iphone 2750 syncthing photos -"
  ];

  services.samba.settings."photos" = {
    "path" = "/mnt/tank/photos";
    "comment" = "Phone photo backup (read-only)";
    "browseable" = "yes";
    "read only" = "yes";
    "guest ok" = "no";
    "valid users" = "nox";
  };

  systemd.services.syncthing.onFailure = [ "notify-failure@%n.service" ];
}
