{
  pkgs,
  ...
}:

{
  services.llama-cpp = {
    enable = true;
    package = pkgs.llama-cpp-vulkan;
    modelsDir = "/mnt/tank/models";
    host = "127.0.0.1";
    port = 8080;
  };

  systemd.tmpfiles.rules = [
    "d /mnt/tank/models 0755 nox users -"
  ];

  systemd.services.llama-cpp = {
    requires = [ "mnt-tank.mount" ];
    after = [ "mnt-tank.mount" ];
    onFailure = [ "notify-failure@%n.service" ];
  };
}
