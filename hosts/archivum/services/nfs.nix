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
    };
    settings = {
      nfsd = {
        vers2 = false;
        vers3 = true;
        vers4 = true;
        vers4_0 = true;
        vers4_1 = true;
        vers4_2 = true;
      };
      exportfs = {
        debug = 0;
      };
    };
  };

  services.rpcbind.enable = true;

  # services.nfs has no openFirewall option, so the ports (rpcbind, nfsd,
  # statd/lockd/mountd as pinned above, plus mountd's rpc port) are listed by
  # hand here - unlike samba, which uses openFirewall.
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
