{
  pkgs,
  ...
}:

{
  programs.git = {
    enable = true;
    config = {
      safe.directory = "/home/nox/etc/nixos";
    };
  };

  environment.systemPackages = with pkgs; [
    git-crypt
  ];
}
