{
  ...
}:

let
  informAddress = "10.201.3.229";
in
{
  services.unifi-os-server = {
    enable = true;
    uosSystemIP = informAddress;
    openFirewallUiPort = true;
    openFirewallServicePorts = true;
  };

  # mongo datadir
  archivum.backup.exclude = [ "/var/lib/unifi-os-server/mongodb" ];

  systemd.services.podman-unifi-os-server.onFailure = [ "notify-failure@%n.service" ];
}
