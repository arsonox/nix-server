{
  lib,
  ...
}:

let
  credentialsFile = ../secrets/cloudflared-tunnel.json;
  tunnelId = "53ac69f4-9260-477f-9800-f31198468116";

  # Hostnames this tunnel is allowed to carry. Everything else gets the 404 catch-all
  publicHosts = [ "kuma.nox.onl" "invest.nox.onl" ];

  hasCredentials = builtins.pathExists credentialsFile;
  configured = tunnelId != "" && hasCredentials;
in
{
  warnings =
    lib.optional (tunnelId == "") ''
      archivum has no cloudflare tunnel: tunnelId in
      hosts/archivum/services/cloudflared.nix is still empty, so nothing is
      reachable from outside the LAN. See hosts/archivum/README.md.
    ''
    ++ lib.optional (tunnelId != "" && !hasCredentials) ''
      archivum's cloudflare tunnel is declared but has no credentials:
      hosts/archivum/secrets/cloudflared-tunnel.json does not exist
    ''
    ++ lib.optional (configured && publicHosts == [ ]) ''
      archivum's cloudflare tunnel carries no hostnames
    '';

  services.cloudflared = lib.mkIf configured {
    enable = true;

    tunnels.${tunnelId} = {
      credentialsFile = toString credentialsFile;
      ingress = lib.genAttrs publicHosts (host: {
        service = "https://127.0.0.1:443";
        originRequest.originServerName = host;
      });

      default = "http_status:404";
    };
  };

  systemd.services."cloudflared-tunnel-${tunnelId}" = lib.mkIf configured {
    onFailure = [ "notify-failure@%n.service" ];
    after = [ "nginx.service" ];
    wants = [ "nginx.service" ];
  };
}
