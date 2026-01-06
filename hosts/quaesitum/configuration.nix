{
  lib,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./services
    ../common
  ];

  networking = {
    hostName = "quaesitum";
    interfaces.enp1s0 = {
      ipv6.addresses = [
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
      interface = "enp1s0";
    };

    defaultGateway6 = {
      address = "fe80::1";
      interface = "enp1s0";
    };

    nameservers = [
      "1.1.1.1"
      "8.8.8.8"
    ];
  };

  services.qemuGuest.enable = true;

  # Hetzner does not support UEFI on the old servers I'm currently on.
  # So just for this machine we make an exception and use GRUB instead.
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.11";
}
