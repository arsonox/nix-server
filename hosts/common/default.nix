{
  inputs,
  ...
}:

{
  imports = [
    ./programs
    ./services
  ];
  services.fstrim.enable = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
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

  users.users = {
    nox = {
      initialPassword = "changeme";
      isNormalUser = true;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ6cR1O87RX+NOt5EUBPdT0XNinMG7mGtkSz61hbr4za nox@fwdesktop"
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
}
