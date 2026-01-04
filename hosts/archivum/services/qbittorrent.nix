{
  config,
  ...
}:

{
  vpnNamespaces.qbtwg = {
    enable = true;
    wireguardConfigFile = ../../../secrets/wg-qbtwg.conf;
    accessibleFrom = [
      "10.100.0.0/24"
      "10.201.0.0/24"
    ];
    portMappings = [
      {
        from = 8080;
        to = 8080;
        protocol = "tcp";
      }
    ];
  };

  services.qbittorrent = {
    enable = true;
    openFirewall = false;
    webuiPort = 8080;
    serverConfig = {
      Core.AutoDeleteAddedTorrentFile = "Never";
      Preferences.WebUI = {
        LocalHostAuth = false;
        # generate with the following command (make sure to prefix with a space to avoid going into shell history!)
        # nix run git+https://codeberg.org/feathecutie/qbittorrent_password -- -p [password here]
        Password_PBKDF2 = "@ByteArray(JZ5/MxLJ1RAG6FO9E9qE3g==:R41kCnc/Sw/4ekMTD0uBT9DYyLzY/RUuAmPq2lMXZ6z8qalsVXIbxquEunMrpDZZmAgAzb3BvOfsrEHB9fMzww==)";
      };
      BitTorrent.Session = [
        {
          DefaultSavePath = "/mnt/zpool1/media";
          TempPath = "/mnt/zpool1/incomplete";
          TempPathEnabled = true;
          AnonymousModeEnabled = true;
          GlobalMaxSeedingMinutes = -1;
          MaxActiveTorrents = -1;
          MaxActiveDownloads = 8;
          MaxActiveUploads = -1;
        }
      ];
    };
  };

  assertions = [
    {
      # do not let qbittorrent run if we aren't sure we've quarantined it to the network namespace
      # that is running behind the VPN
      assertion = config.systemd.services ? qbittorrent;
      message = "systemd service 'qbittorrent' not found - the qbittorrent service name may have changed";
    }
  ];

  systemd.services.qbittorrent.vpnConfinement = {
    enable = true;
    vpnNamespace = "qbtwg";
  };

  networking.firewall = {
    allowedTcpPorts = [ 8080 ];
  };
}
