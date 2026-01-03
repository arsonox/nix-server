{ pkgs, ... }:
{
  services.jellyfin = {
    enable = true;
    openFirewall = true;
    hardwareAcceleration = {
      enable = true;
      type = "vaapi";
    };

    hardwareEncodingCodecs = {
      hevc = true;
      av1 = true;
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
