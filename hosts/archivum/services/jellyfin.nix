{
  pkgs,
  inputs,
  ...
}:

{
  disabledModules = [
    "services/misc/jellyfin.nix"
  ];

  imports = [
    "${inputs.nixpkgs-unstable}/nixos/modules/services/misc/jellyfin.nix"
  ];

  services.jellyfin = {
    enable = true;
    openFirewall = true;
    hardwareAcceleration = {
      enable = true;
      type = "vaapi";
      device = "/dev/dri/renderD128"; # TODO: CHECK
    };

    transcoding = {
      hardwareEncodingCodecs = {
        hevc = true;
        av1 = true;
      };
    };
  };

  environment.systemPackages = with pkgs; [
    jellyfin
    jellyfin-web
    jellyfin-ffmpeg

    ffmpeg-full
    mediainfo
    exiftool
  ];
}
