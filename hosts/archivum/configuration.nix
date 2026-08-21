{
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./services
    ./programs
    ../common
  ];

  networking.hostName = "archivum";

  # We need a hostId for ZFS. We can generate one using
  # head -c4 /dev/urandom | od -A none -t x4
  networking.hostId = "4b6d8560";

  # Do not pass -f to `zpool import` for rpool: the hostId above is stable and
  # the disks are local, so the hostid safeguard should never fire. This is the
  # new upstream default from 26.11 on; set explicitly since stateVersion is 25.11.
  # If a boot ever fails to import rpool, boot once with `zfs_force=1`.
  boot.zfs.forceImportRoot = false;

  services.zfs.autoScrub = {
    enable = true;
  };

  hardware.enableAllFirmware = true;

  hardware.graphics.enable = true;

  #### TODO: Add settings here

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.11";
}
