{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./services
    ../common
  ];

  nixpkgs = {
    overlays = [
      inputs.self.overlays.additions
      inputs.self.overlays.modifications
      inputs.self.overlays.unstable-packages
    ];

    config = {
      allowUnfree = true;
    };
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  #### TODO: Add settings here

  networking.hostName = "archivum";
  users.users = {
    nox = {
      initialPassword = "changeme";
      isNormalUser = true;
      openssh.authorizedKeys.keys = [
        # TODO: add ssh keys
      ];
      extraGroups = [
        "wheel"
        "samba"
        "docker"
      ];
    };
  };

  networking.firewall = {
    enable = true;
    allowPing = true;
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.11";
}
