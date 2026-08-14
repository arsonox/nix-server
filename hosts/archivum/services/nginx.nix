{
  lib,
  ...
}:

let
  acmeEnvFile = ../secrets/acme-cloudflare.env;
  emailFile = ../../../secrets/email;

  configured = builtins.pathExists acmeEnvFile;

  email =
    let
      r = builtins.tryEval (lib.removeSuffix "\n" (builtins.readFile emailFile));
    in
    if builtins.pathExists emailFile && r.success then r.value else "";
in
{
  warnings = lib.optional (!configured) ''
    archivum has no reverse proxy: secrets/acme-cloudflare.env does not exist,
    so nginx and the *.nox.onl wildcard certificate are not configured.
  '';

  security.acme = lib.mkIf configured {
    acceptTerms = true;
    defaults.email = email;

    certs."nox.onl" = {
      domain = "nox.onl";
      extraDomainNames = [ "*.nox.onl" ];
      dnsProvider = "cloudflare";
      environmentFile = toString acmeEnvFile;
      dnsResolver = "1.1.1.1:53";
      group = "nginx";
    };
  };

  services.nginx = lib.mkIf configured {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    commonHttpConfig = ''
      http2 on;
    '';

    virtualHosts."_" = {
      default = true;
      useACMEHost = "nox.onl";
      addSSL = true;
      locations."/".return = "444";
    };

    virtualHosts."kuma.nox.onl" = {
      useACMEHost = "nox.onl";
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:3001";
        proxyWebsockets = true;
      };
    };

    virtualHosts."unifi.nox.onl" = {
      useACMEHost = "nox.onl";
      forceSSL = true;
      # self-signed cert on backend; proxy_ssl_verify off by default
      locations."/" = {
        proxyPass = "https://127.0.0.1:11443";
        proxyWebsockets = true;
        extraConfig = ''
          client_max_body_size 1G;
          proxy_read_timeout 86400s;
          proxy_send_timeout 86400s;
        '';
      };

      # UniFi checks Origin against hostname and refuses live-update
      # socket when it sees proxy. Stripping header as workaround.
      locations."/wss/" = {
        proxyPass = "https://127.0.0.1:11443";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Origin "";
          proxy_buffering off;
          proxy_read_timeout 86400s;
          proxy_send_timeout 86400s;
        '';
      };
    };

    virtualHosts."invest.nox.onl" = {
      useACMEHost = "nox.onl";
      forceSSL = true;
      locations."/".proxyPass = "http://127.0.0.1:8770";
    };

    virtualHosts."syncthing.nox.onl" = {
      useACMEHost = "nox.onl";
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:8384";
        proxyWebsockets = true;
      };
    };
  };

  networking.firewall.allowedTCPPorts = lib.mkIf configured [
    80
    443
  ];
}
