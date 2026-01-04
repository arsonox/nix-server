{
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./services
    ../common
  ];

  networking.hostName = "archivum";
  networking.hostId = "4b6d8560";

  #### TODO: Add settings here

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.11";
}
