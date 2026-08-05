{
  ...
}:

{
  services.sanoid = {
    enable = true;

    templates = {
      system = {
        hourly = 24;
        daily = 14;
        monthly = 3;
        autosnap = true;
        autoprune = true;
      };
      data = {
        hourly = 12;
        daily = 30;
        monthly = 6;
        autosnap = true;
        autoprune = true;
      };
      media = {
        daily = 7;
        monthly = 1;
        autosnap = true;
        autoprune = true;
      };
      # Photos are the irreplaceable set — everything else on tank exists
      # somewhere else or can be re-downloaded — so they keep the longest tail.
      photos = {
        hourly = 12;
        daily = 30;
        monthly = 12;
        yearly = 3;
        autosnap = true;
        autoprune = true;
      };
    };

    datasets = {
      "rpool/root".useTemplate = [ "system" ];
      "rpool/var".useTemplate = [ "system" ];
      "rpool/home".useTemplate = [ "data" ];
      "tank/nox".useTemplate = [ "data" ];
      "tank/media".useTemplate = [ "media" ];
      "tank/photos".useTemplate = [ "photos" ];
    };
  };

  systemd.services.sanoid.onFailure = [ "notify-failure@%n.service" ];
}
