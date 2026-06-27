{
  description = "Janis' NixOS Konfiguration";

  inputs = {
    # Unstable, damit Hyprland & Co aktuell sind (passt zum Arch-Rolling-Gefühl)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # end-4 / illogical-impulse Hyprland-Dots als home-manager-Modul (+ QuickShell)
    illogical-flake = {
      url = "github:soymou/illogical-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Claude Desktop fuer Linux (inoffizieller Build)
    claude-desktop = {
      url = "github:k3d3/claude-desktop-linux-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nixpkgs-Fork mit dem noch nicht gemergten brave-origin (PR #511131).
    # Dient nur als Quelle fuer das eine Paket via Overlay (siehe configuration.nix).
    nixpkgs-brave.url = "github:WitteShadovv/nixpkgs/brave-origin";

    # Kompletter VS-Code-Marketplace + OpenVSX als Nix-Pakete
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";
    in {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/nixos/configuration.nix
          ./hosts/nixos/hardware-configuration.nix

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.users.janis = import ./hosts/nixos/home.nix;
          }
        ];
      };
    };
}
