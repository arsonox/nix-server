{
  pkgs,
  ...
}:

{
  services.samba = {
    enable = true;
    openFirewall = true;
    package = pkgs.samba4Full;
    settings = {
      global = {
        "workgroup" = "WORKGROUP";
        "server string" = "Archivum";
        "netbio name" = "archivum";
        "security" = "user";
        "map to guest" = "bad user";
        "guest account" = "nobody";
        "smbd profiling level" = "on";
      };
      "media" = {
        "path" = "/mnt/tank/media";
        "comment" = "Media files (movies, series, music)";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "yes";
        "create mask" = "0644";
        "directory mask" = "0755";
        "force user" = ""; # TODO: user
        "force group" = "";
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
}

# TODO: do I need to set up logrotate?
