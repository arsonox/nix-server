{
  lib,
  ...
}:

{
  services.journald = {
    storage = lib.mkForce "persistent";
    extraConfig = lib.mkForce ''
      SystemMaxUse=2G
      SystemMaxFileSize=200M
      MaxRetentionSec=1month
    '';
  };
}
