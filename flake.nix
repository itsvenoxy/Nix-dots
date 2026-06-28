{
  description = "Janis' NixOS Konfiguration";

  inputs = {
    # Unstable, damit Hyprland & Co aktuell sind (passt zum Arch-Rolling-Gefühl)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # home-manager: KEIN release-Branch -> folgt master, weil master der zu
    # nixos-unstable passende Zweig ist (release-XX.XX gehoert zu nixos-XX.XX).
    # Wichtig: master nutzt nixpkgs' portable-services-Framework via
    #   import (pkgs.path + "/lib/services/lib.nix")
    # (Modul services-modular). Das gibt es in nixpkgs erst ab 2026-04-04
    # (commit a338deb8, "lib/services: move portable service infrastructure
    # out of nixos/"). Darum MUSS die in flake.lock gepinnte nixpkgs-unstable-
    # Revision >= diesem Datum sein, sonst:
    #   error: path '.../lib/services/lib.nix' does not exist
    # Die committete flake.lock haelt beide Inputs auf einem zueinander
    # kompatiblen, frischen Stand fest -> reproduzierbarer nixos-install.
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # end-4 / illogical-impulse Hyprland-Dots als home-manager-Modul (+ QuickShell).
    # Upstream soymou = der urspruenglich funktionierende Stand (klassische
    # .conf-Config). Hinweis: ein paar veraltete Hyprland-Optionen
    # (dwindle:pseudotile, misc:vfr) werfen nicht-fatale Config-Error-Warnungen
    # (rote Box), der Desktop laeuft aber.
    illogical-flake = {
      url = "github:soymou/illogical-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Eigener nixpkgs-Snapshot NUR fuer claude-desktop: letzter nixos-unstable-
    # Commit vor dem Entfernen von nodePackages (2026-03-03). claude-desktop
    # (pkgs/claude-desktop.nix) nutzt nodePackages.asar; in aktuellem unstable
    # wirft das "nodePackages has been removed". Upstream-HEAD ist noch nicht
    # gefixt. Darum baut diese eine Leaf-App (FHS-Sandbox) gegen ein aelteres
    # nixpkgs -> das System-nixpkgs bleibt unangetastet auf unstable.
    nixpkgs-claude.url = "github:NixOS/nixpkgs/bcf5e671df4efb886d8f787ef8cb54e5867c749a";

    # Claude Desktop fuer Linux (inoffizieller Build)
    claude-desktop = {
      url = "github:k3d3/claude-desktop-linux-flake";
      inputs.nixpkgs.follows = "nixpkgs-claude";
    };

    # nixpkgs-Fork mit dem noch nicht gemergten brave-origin (PR #511131).
    # Dient nur als Quelle fuer das eine Paket via Overlay (siehe configuration.nix).
    nixpkgs-brave.url = "github:WitteShadovv/nixpkgs/brave-origin";

    # Kompletter VS-Code-Marketplace + OpenVSX als Nix-Pakete
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # SilentSDDM Login-Theme (ersetzt sddm-astronaut). Liefert ein NixOS-Modul,
    # das SDDM komplett einrichtet (siehe programs.silentSDDM in configuration.nix).
    silentSDDM = {
      url = "github:uiriansan/SilentSDDM";
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

          inputs.silentSDDM.nixosModules.default

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            # Bestehende, von HM nicht erzeugte Dateien (z.B. die beim ersten
            # Start der illogical-Dots ins ~/.config geschriebenen Configs)
            # sichern statt "would be clobbered"-Abbruch.
            home-manager.backupFileExtension = "hmbak";
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.users.janis = import ./hosts/nixos/home.nix;
          }
        ];
      };
    };
}
