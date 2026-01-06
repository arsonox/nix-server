{
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./services
    ../common
    ./secrets/acme.nix
  ];

  networking = {
    hostName = "quaesitum";
    interfaces.enp0s1 = {
      ipv6.address = [
        {
          address = "2a01:4f8:c013:85f::1";
          prefixLength = 64;
        }
      ];
      ipv4.addresses = [
        {
          address = "46.224.132.78";
          prefixLength = 24;
        }
      ];
    };

    defaultGateway = {
      address = "172.31.1.1";
      interface = "enp0s1";
    };

    defaultGateway6 = {
      address = "fe80::1";
      interface = "enp0s1";
    };

    nameservers = [
      "1.1.1.1"
      "8.8.8.8"
    ];
  };

  services.qemuGuest.enable = true;

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.11";
}
