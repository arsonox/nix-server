{
  config,
  ...
}:

{
  # Nginx configuration
  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    virtualHosts = {
      "s.nox.onl" = {
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
}
