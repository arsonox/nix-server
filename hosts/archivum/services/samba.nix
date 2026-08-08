{
  ...
}:

{
  services.samba = {
    enable = true;
    openFirewall = true;

    # No AD domain here: nmbd only serves NetBIOS name resolution (samba-wsdd
    # already handles discovery for Windows clients) and winbindd is only
    # useful when joined to a domain.
    nmbd.enable = false;
    winbindd.enable = false;

    settings = {
      global = {
        "workgroup" = "WORKGROUP";
        "server string" = "Archivum";
        "netbios name" = "archivum";
        "security" = "user";
        "map to guest" = "bad user";
        "guest account" = "nobody";
        "server min protocol" = "SMB3";
        "server smb encrypt" = "desired";
        "smbd profiling level" = "on";
      };
      "media" = {
        "path" = "/mnt/tank/media";
        "comment" = "Media files (movies, series, music)";
        "browseable" = "yes";
        "read only" = "no";
        # Deliberately writable by anyone on the LAN: guests are mapped onto
        # nox:media so they share the library with qbittorrent and jellyfin.
        "guest ok" = "yes";
        "force user" = "nox";
        "force group" = "media";
        "create mask" = "0664";
        "directory mask" = "0775";
        "force directory mode" = "2000"; # keep new dirs setgid to `media`
      };
      "nox" = {
        "path" = "/mnt/tank/nox";
        "comment" = "Nox' files";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "create mask" = "0644";
        "directory mask" = "0755";
        "force user" = "nox";
        "force group" = "users";
        "valid users" = "nox";
      };
    };
  };

  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };

  # Shared group for everything that touches the media library.
  users.groups.media.members = [
    "nox"
    "qbittorrent"
    "jellyfin"
  ];

  # `z` only adjusts an already existing path, so this is a no-op if tank/media
  # happens not to be mounted. Setgid keeps the group on anything created
  # outside of samba.
  systemd.tmpfiles.rules = [
    "z /mnt/tank/media 2775 nox media -"
    "z /mnt/tank/nox 0755 nox users -"
  ];
}
