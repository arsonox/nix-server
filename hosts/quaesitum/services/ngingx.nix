{
  config,
  lib,
  ...
}:

let
  # The email address is encrypted so if it cannot be read we'll use an empty
  # string until git-crypt can be enabled to decrypt the file.
  emailAddress = builtins.tryEval (builtins.readFile ../secrets/email);
in
{
  # Nginx configuration
  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    commonHttpConfig = ''
      http2 on;
      ssl_early_data on;
    '';

    virtualHosts = {
      "s.nox.onl" = {
        forceSSL = true;
        enableACME = true;
        locations."/".return = "301 https://sx.nox.onl";
      };
      "sx.nox.onl" = {
        forceSSL = true;
        enableACME = true;
        http3 = true;
        quic = true;
        locations = {
          "/" = {
            extraConfig = ''
              uwsgi_pass unix:${config.services.searx.uwsgiConfig.socket};
              add_header Alt-Svc 'h3=":443"; ma=86400' always;
            '';
          };
        };
      };
    };
  };

  security.acme.acceptTerms = true;
  security.acme.defaults.email = if emailAddress.success then emailAddress.value else "";

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
  networking.firewall.allowedUDPPorts = [
    443
  ];
}
