#placeholder
{
  lib,
  ...
}:

{
  fileSystems."/" = {
    device = "/dev/by/placeholder";
    fsType = "placeholder";
  };
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
