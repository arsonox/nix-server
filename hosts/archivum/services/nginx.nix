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
  };

  networking.firewall.allowedTCPPorts = lib.mkIf configured [
    80
    443
  ];
}
