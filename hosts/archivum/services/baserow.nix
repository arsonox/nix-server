{
  config,
  lib,
  ...
}:

let
  envFile = ../secrets/baserow.env;
  configured = builtins.pathExists envFile;

  port = 8083;
in
{
  warnings = lib.optional (!configured) ''
    archivum runs no baserow: hosts/archivum/secrets/baserow.env does not
    exist
  '';

  services.postgresql = lib.mkIf configured {
    ensureDatabases = [ "baserow" ];
    ensureUsers = [
      {
        name = "baserow";
        ensureDBOwnership = true;
      }
    ];
  };

  systemd.services.baserow-db-password = lib.mkIf configured {
    description = "Set the baserow postgres role password";
    requires = [ "postgresql-setup.service" ];
    after = [ "postgresql-setup.service" ];
    before = [ "podman-baserow.service" ];
    requiredBy = [ "podman-baserow.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "postgres";
      Group = "postgres";
      EnvironmentFile = toString envFile;
    };

    script = ''
      ${config.services.postgresql.finalPackage}/bin/psql \
        -v ON_ERROR_STOP=1 -v pw="$DATABASE_PASSWORD" <<'SQL'
      ALTER ROLE baserow WITH LOGIN PASSWORD :'pw';
      SQL
    '';

    onFailure = [ "notify-failure@%n.service" ];
  };

  # The image bakes in UID/GID 9999
  systemd.tmpfiles.rules = lib.mkIf configured [
    "d /var/lib/baserow 0755 9999 9999 -"
  ];

  virtualisation.oci-containers.containers.baserow = lib.mkIf configured {
    # digest pinning the version
    image = "baserow/baserow:2.3.3@sha256:41adb3493379403946a493f30873f743bb65b19b5f387d630ec75f41e25d5b5b";

    environment = {
      BASEROW_PUBLIC_URL = "https://baserow.nox.onl";
      BASEROW_CADDY_ADDRESSES = ":80"; # caddy needs no ssl cert, we proxy
      DATABASE_HOST = "host.containers.internal";
      DATABASE_PORT = "5432";
      DATABASE_NAME = "baserow";
      DATABASE_USER = "baserow";
    };

    environmentFiles = [ (toString envFile) ];
    ports = [ "127.0.0.1:${toString port}:80" ];
    volumes = [ "/var/lib/baserow:/baserow/data" ];
    extraOptions = [ "--add-host=host.containers.internal:host-gateway" ];
  };

  services.nginx.virtualHosts."baserow.nox.onl" = lib.mkIf configured {
    useACMEHost = "nox.onl";
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      proxyWebsockets = true;
      extraConfig = ''
        client_max_body_size 1G;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
      '';
    };
  };

  archivum.backup.exclude = [ "/var/lib/baserow/redis" ];

  systemd.services.podman-baserow.onFailure = lib.mkIf configured [
    "notify-failure@%n.service"
  ];
}
