{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vpn-confinement.url = "github:Maroka-chan/VPN-Confinement";
    unifi-os-server.url = "github:rcambrj/unifi-os-server";
    claude-code.url = "github:sadjow/claude-code-nix";
    # Private repo: fetched over SSH with the nox user's key, so `nh`/
    # nixos-rebuild must evaluate as nox (it does) rather than as root.
    noxinvest = {
      url = "git+ssh://git@github.com/arsonox/noxinvest2";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    run0-sudo-shim = {
      url = "github:lordgrimmauld/run0-sudo-shim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      vpn-confinement,
      claude-code,
      ...
    }@inputs:
    let
      defaultModules = [
        inputs.run0-sudo-shim.nixosModules.default
      ];
    in
    {
      overlays = import ./overlays { inherit inputs; };
      nixosModules = import ./modules/nixos;
      homemanagerModules = import ./modules/home-manager;

      nixosConfigurations = {
        archivum = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/archivum/configuration.nix
            vpn-confinement.nixosModules.default
            inputs.unifi-os-server.nixosModules.unifi-os-server
            inputs.noxinvest.nixosModules.default
          ]
          ++ defaultModules;
        };
        ubiqium = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/ubiqium/configuration.nix
          ]
          ++ defaultModules;
        };
        quaesitum = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/quaesitum/configuration.nix
          ]
          ++ defaultModules;
        };
        fabricum = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/fabricum/configuration.nix
          ]
          ++ defaultModules;
        };
      };
    };
}
