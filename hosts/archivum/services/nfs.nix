{
  ...
}:

{
  services.nfs = {
    server = {
      enable = true;
      lockdPort = 4001;
      mountdPort = 4002;
      statdPort = 4000;

      exports = '''';

      extraNfsdConfig = ''
        [nfsd]
        vers2=n
        vers3=y
        vers4=y
        vers4.0=y
        vers4.1=y
        vers4.2=y

        [exportfs]
        debug=0
      '';
    };
  };

  services.rpcbind.enable = true;

  networking.firewall = {
    allowedTCPPorts = [
      111
      2049
      4000
      4001
      4002
      20048
    ];
    allowedUDPPorts = [
      111
      2049
      4000
      4001
      4002
      20048
    ];
  };
}
