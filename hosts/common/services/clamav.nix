{
  pkgs,
  ...
}:

{
  environment.systemPackages = with pkgs; [
    clamav
  ];

  services.clamav = {
    # Enable clamd daemon
    daemon.enable = true;
    updater.enable = true;
    updater.frequency = 12; # Number of database checks per day
    scanner = {
      enable = true;
      interval = "*-*-* 06:00:00"; # Every day at 6:00
      scanDirectories = [
        "/home"
        "/var/lib"
        "/tmp"
        "/etc"
        "/var/tmp"
      ];
    };
  };
}
