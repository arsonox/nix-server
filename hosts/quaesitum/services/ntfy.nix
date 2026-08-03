{
  lib,
  ...
}:

let
  provisionFile = ../secrets/ntfy.env;
  provisioned = builtins.pathExists provisionFile;
in
{
  warnings = lib.optional (!provisioned) ''
    ntfy on quaesitum has no users: hosts/quaesitum/secrets/ntfy.env does not
    exist, and auth-default-access is deny-all, so nothing can publish or read.
  '';

  services.ntfy-sh = {
    enable = true;

    environmentFile = lib.mkIf provisioned (toString provisionFile);

    settings = {
      base-url = "https://ntfy.nox.onl";
      listen-http = "127.0.0.1:2586";
      behind-proxy = true;
      auth-default-access = "deny-all";
      auth-access-cache = true;
      enable-signup = false;
      enable-login = true;
      cache-duration = "24h";
      attachment-cache-dir = "";
      upstream-base-url = "https://ntfy.sh";
    };
  };

  services.nginx.virtualHosts."ntfy.nox.onl" = {
    forceSSL = true;
    enableACME = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:2586";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_buffering off;
        proxy_request_buffering off;
        proxy_redirect off;
        proxy_connect_timeout 3m;
        proxy_send_timeout 3m;
        proxy_read_timeout 3m;
      '';
    };
  };
}
