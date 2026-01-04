{
  lib,
  ...
}:

{
  services.karakeep = {
    enable = true;
    # extraEnvironment = {
    #   DATA_DIR = lib.mkForce "/mnt/zpool1/karakeep";
    # };
  };

  networking.firewall = {
    allowedTCPPorts = [ 3000 ];
  };
}
