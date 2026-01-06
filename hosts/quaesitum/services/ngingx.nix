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
    virtualHosts = {
      "sx.nox.onl" = {
        forceSSL = true;
        enableACME = true;
        locations = {
          "/" = {
            extraConfig = ''
              uwsgi_pass unix:${config.services.searx.uwsgiConfig.socket};
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
}
