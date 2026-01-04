{
  inputs,
  ...
}:

{
  imports = [
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
}
