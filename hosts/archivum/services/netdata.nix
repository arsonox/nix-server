{ pkgs, ... }:
{
  services.netdata = {
    enable = true;
    package = pkgs.netdata.override {
      withCloudUi = true;
    };

    config = {
      global = {
        "memory mode" = "ram";
        "debug log" = "none";
        "access log" = "none";
        "error log" = "syslog";
      };
    };

    configDir."python.d.conf" = pkgs.writeText "python.d.conf" ''
      samba: yes
    '';
  };

  networking.firewall.allowedTCPPorts = [ 19999 ];

  systemd.services.netdata.path = [
    pkgs.samba
    "/run/wrappers"
  ];

  security.sudo.extraConfig = ''
    netdata ALL=(root) NOPASSWD: ${pkgs.samba}/bin/smbstatus
  '';

  systemd.services.netdata.serviceConfig.CapabilityBoundingSet = [ "CAP_SETGID" ];
}
