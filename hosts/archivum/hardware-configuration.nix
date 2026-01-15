{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "thunderbolt"
    "ahci"
    "nvme"
    "usbhid"
    "uas"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "rpool/root";
    fsType = "zfs";
    options = [ "zfsutil" ];
  };

  fileSystems."/nix" = {
    device = "rpool/nix";
    fsType = "zfs";
    options = [ "zfsutil" ];
  };

  fileSystems."/var" = {
    device = "rpool/var";
    fsType = "zfs";
    options = [ "zfsutil" ];
  };

  fileSystems."/home" = {
    device = "rpool/home";
    fsType = "zfs";
    options = [ "zfsutil" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/BBAA-792A";
    fsType = "vfat";
    options = [ "umask=0077" ];
  };

  fileSystems."/mnt/tank" = {
    device = "tank/root";
    fsType = "zfs";
    options = [ "zfsutil" ];
  };

  fileSystems."/mnt/tank/media" = {
    device = "tank/media";
    fsType = "zfs";
    options = [ "zfsutil" ];
  };

  fileSystems."/mnt/tank/nox" = {
    device = "tank/nox";
    fsType = "zfs";
    options = [ "zfsutil" ];
  };

  fileSystems."/mnt/tank/incomplete" = {
    device = "tank/incomplete";
    fsType = "zfs";
    options = [ "zfsutil" ];
  };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
