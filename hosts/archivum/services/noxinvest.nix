{
  ...
}:

{
  services.noxinvest = {
    enable = true;
    host = "127.0.0.1";
    port = 8770;
    hours = 6;
    passwordFile = ../secrets/noxinvestp;
    regions = [
      "us"
      "nl"
      "de"
      "fr"
      "gb"
    ];
  };

  systemd.services.noxinvest.onFailure = [ "notify-failure@%n.service" ];

  services.nginx.virtualHosts."noxinvest.nox.onl" = {
    useACMEHost = "nox.onl";
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:8770";
    };
  };
}
