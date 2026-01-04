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

  networking.hostName = "quaesitum";

  services.qemuGuest.enable = true;

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.11";
}
