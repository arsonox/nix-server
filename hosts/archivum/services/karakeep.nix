{ ... }:

{
  serivces.karakeep = {
    enable = true;
    extraEnvironment = {
      DATA_DIR = "/mnt/zpool1/karakeep";
    };
  };

  networking.firewall = {
    allowedTcpPorts = [ 3000 ];
  };
}
