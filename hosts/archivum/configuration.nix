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

  # We need a hostId for ZFS. We can generate one using
  # head -c4 /dev/urandom | od -A none -t x4
  networking.hostId = "4b6d8560";

  #### TODO: Add settings here

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.11";
}
