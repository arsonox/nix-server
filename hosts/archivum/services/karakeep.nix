{
  lib,
  ...
}:

{
  services.karakeep = {
    enable = true;
    # extraEnvironment = {
    #   DATA_DIR = lib.mkForce "/mnt/tank/karakeep";
    # };
  };

  networking.firewall = {
    allowedTCPPorts = [ 3000 ];
  };
}
