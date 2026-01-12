{
  inputs,
  ...
}:

{
  imports = [
    ./programs
    ./services
  ];

  services.fstrim.enable = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nixpkgs = {
    overlays = [
      inputs.self.overlays.additions
      inputs.self.overlays.modifications
      inputs.self.overlays.unstable-packages
    ];

    config = {
      allowUnfree = true;
    };
  };

  hardware.enableAllFirmware = true;

  users.users = {
    nox = {
      initialPassword = "changeme";
      isNormalUser = true;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ6cR1O87RX+NOt5EUBPdT0XNinMG7mGtkSz61hbr4za nox@fwdesktop"
      ];
      extraGroups = [
        "wheel"
        "samba"
        "docker"
      ];
    };
  };

  systemd.coredump.enable = false;

  # Sets the kernel's resource limit (ulimit -c 0)
  security.pam.loginLimits = [
    {
      domain = "*"; # Applies to all users/sessions
      type = "-"; # Set both soft and hard limits
      item = "core"; # The soft/hard limit item
      value = "0"; # Core dumps size is limited to 0 (effectively disabled)
    }
  ];

  security.polkit.enable = true;
  security.run0-sudo-shim.enable = true;

  users.groups.netdev = { };

  # dbus-broker is a little less insecure than dbus
  services.dbus.implementation = "broker";

  # Enable log rotation and configure journald
  services.logrotate.enable = true;
  services.journald = {
    storage = "volatile"; # Store logs in memory
    upload.enable = false; # Disable remote log upload (the default)
    extraConfig = ''
      SystemMaxUse=500M
      SystemMaxFileSize=50M
    '';
  };

  networking.firewall = {
    enable = true; # Enable the firewall, always
    allowPing = true;
  };

  nix.optimise = {
    automatic = true;
    dates = [ "daily" ];
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Enable auditing
  # start as early in the boot process as possible
  boot.kernelParams = [ "audit=1" ];
  security.auditd.enable = true;
  security.audit.enable = true;
  security.audit.rules = [
    # Log all program executions on 64-bit architecture
    "-a exit,always -F arch=b64 -S execve"
  ];
}
