{
  ...
}:

{
  services.uptime-kuma = {
    enable = true;
    openFirewall = true;
    settings = {
      HOST = "0.0.0.0";
      PORT = "3001";
    };
  };
}
