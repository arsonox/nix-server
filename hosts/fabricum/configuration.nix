{
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./services
    ./programs
    ../common
  ];

  networking.hostName = "fabricum";

  services.qemuGuest.enable = true;

  /*
    # Test AppArmor on Fabricum
    security.apparmor = {
      enable = true;
      killUnconfinedConfinables = true;
      packages = with pkgs; [
        apparmor-utils
        apparmor-profiles
      ];
    };

    security.pam.services = {
      login.enableAppArmor = true;
      sshd.enableAppArmor = true;
      su.enableAppArmor = true;
      greetd.enableAppArmor = true;
      u2f.enableAppArmor = true;
    };

    services.dbus.apparmor = "enabled";
  */

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.11";
}
