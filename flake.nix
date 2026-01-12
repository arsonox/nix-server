{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vpn-confinement.url = "github:Maroka-chan/VPN-Confinement";
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
