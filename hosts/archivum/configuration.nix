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
  networking.hostId = ""; # TODO: add hostId

  #### TODO: Add settings here

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.11";
}
