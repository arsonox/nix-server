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
    port = 8084;
    "n-gpu-layers" = 99;
    "ctx-size" = 8192;
    mlock = true;
  };

  systemd.tmpfiles.rules = [
    "d /mnt/tank/models 0755 nox users -"
  ];

  systemd.services.llama-cpp = {
    requires = [ "mnt-tank.mount" ];
    after = [ "mnt-tank.mount" ];
    onFailure = [ "notify-failure@%n.service" ];
    serviceConfig.LimitMEMLOCK = "infinity";
  };
}
