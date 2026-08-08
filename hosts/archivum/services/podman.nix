{
  ...
}:

# Podman exists on archivum for exactly one thing: UniFi OS Server, which has
# no native NixOS packaging and no non-deprecated alternative. It is not a
# general escape hatch — anything else gets a real module first.

{
  virtualisation.podman = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  virtualisation.oci-containers.backend = "podman";
}
