{
  imports = [
    ./avahi.nix
    # ./docker.nix # disable docker for now: let's try to do this with Nix containers
    ./jellyfin.nix
    ./netdata.nix
    ./nfs.nix
    ./samba.nix
    ./karakeep.nix
  ];
}
