{
  ...
}:

let
  homePage = {
    name = "Home";
  };
in
{
  services.glance = {
    enable = true;
    openFirewall = true;
    settings = {
      server = {
        port = 8081;
      };
      branding = {
        hide-footer = true;
      };
      pages = [
        homePage
      ];
    };
  };
}
