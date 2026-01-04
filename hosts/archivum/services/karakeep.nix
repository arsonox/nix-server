{
  ...
}:

{
  services.karakeep = {
    enable = true;
    extraEnvironment = {
      DATA_DIR = "/mnt/zpool1/karakeep";
    };
  };

  networking.firewall = {
    allowedTCPPorts = [ 3000 ];
  };
}
