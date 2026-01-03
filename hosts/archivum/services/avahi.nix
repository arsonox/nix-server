{ ... }:
{
  services.avahi = {
    enable = true;
    ipv4 = true;
    ipv6 = true;

    publish = {
      enable = true;
      userServices = true;
      domain = true;
      hinfo = true;
    };

    nssmdns4 = true;
    nssmdns6 = true;
    openFirewall = true;
  };
}
