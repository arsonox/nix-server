{ ... }:

{
  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      interval = "daily";
      flags = [
        "--volumes"
        "--all"
        "--filter=until=168h" # everything older than a week
      ];
    };
  };

  virtualisation.oci-containers.backend = "docker";

  networking.firewall = {
    allowedTCPPorts = [ ];
    allowedUDPPorts = [ ];

    trustedInterfaces = [ "docker0" ];

    extraCommands = ''
      iptables -A nixos-fw -i docker+ -j ACCEPT
      iptables -A nixos-fw -o docker+ -j ACCEPT
    '';
  };
}
