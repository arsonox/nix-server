{
  ...
}:

{
  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      extraArgs = "--keep 3";
      dates = "daily";
    };
    flake = "/home/nox/etc/nixos";
  };
}
