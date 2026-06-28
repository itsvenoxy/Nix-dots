{ config, pkgs, lib, inputs, ... }:

let
  # Alle Marketplace-Extensions als Nix-Pakete. Kommt aus dem Overlay
  # (siehe configuration.nix) -> respektiert nixpkgs.config.allowUnfree.
  marketplace = pkgs.vscode-marketplace;

  # Monitor-Setup fuer die Lua-Config der Dots (hl.monitor aus hyprland/lib).
  # Beide Panels 2560x1440; DP-4 (MSI MAG322CQR) mit 165 Hz, rechts neben
  # DP-3 (MAG321CURV, 4K-Panel hier auf 1440p@60).
  monitorsLua = ''
    -- Monitore (von home-manager gesetzt, siehe home.nix)
    hl.monitor({ output = "DP-3", mode = "2560x1440@60",  position = "0x0",    scale = "1" })
    hl.monitor({ output = "DP-4", mode = "2560x1440@165", position = "2560x0", scale = "1" })
  '';
in
{
  imports = [
    inputs.illogical-flake.homeManagerModules.default
  ];

  home.username = "janis";
  home.homeDirectory = "/home/janis";

  # end-4 / illogical-impulse Dots aktivieren (Bar, Sidebars, Lockscreen, QuickShell ...)
  programs.illogical-impulse = {
    enable = true;

    # Alle standardmaessig an; bei Bedarf einzeln abschalten
    dotfiles = {
      fish.enable = true;     # Fish-Config (Login-Shell bleibt bash, ausser du aenderst es)
      kitty.enable = true;    # Kitty-Terminal + Config
      starship.enable = true; # Starship-Prompt
    };
  };

  # VS Code (stable) declarative: Extensions + Settings aus deiner Arch-Installation
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;

    profiles.default = {
      extensions = with marketplace; [
        anthropic.claude-code
        formulahendry.auto-rename-tag
        miguelsolorio.symbols
        ms-azuretools.vscode-containers
        ms-python.debugpy
        ms-python.python
        ms-python.vscode-pylance
        ms-python.vscode-python-envs
        nichabosh.minimalist-dark
        pmndrs.pmndrs            # Poimandres-Theme
        raunofreiberg.vesper
      ];

      # Deine settings.json 1:1
      userSettings = {
        "workbench.colorTheme" = "poimandres";
        "workbench.iconTheme" = "symbols";
        "workbench.activityBar.location" = "top";
        "editor.cursorSmoothCaretAnimation" = "on";
        "breadcrumbs.enabled" = false;
        "material-code.primaryColor" = "#4A5475";
        "claudeCode.preferredLocation" = "panel";
      };
    };
  };

  # Cursor-Theme der end-4/illogical-Dots (sonst Default/falscher Cursor).
  # Setzt GTK, X11/XWayland und hyprcursor (Hyprland) auf einmal.
  home.pointerCursor = {
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 24;
    gtk.enable = true;
    x11.enable = true;
    hyprcursor.enable = true;
  };

  # brave-origin als Standardbrowser (Desktop-Datei: brave-origin-beta.desktop)
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "x-scheme-handler/http" = "brave-origin-beta.desktop";
      "x-scheme-handler/https" = "brave-origin-beta.desktop";
      "x-scheme-handler/about" = "brave-origin-beta.desktop";
      "x-scheme-handler/unknown" = "brave-origin-beta.desktop";
      "text/html" = "brave-origin-beta.desktop";
    };
  };

  # Monitor-Config in die Lua-Dots schreiben, NACH deren Seeding (sonst
  # ueberschreibt das Dots-Seeding custom/general.lua wieder).
  home.activation.setMonitors = lib.hm.dag.entryAfter [ "copyIllogicalImpulseConfigs" ] ''
    $DRY_RUN_CMD install -Dm644 ${pkgs.writeText "hypr-custom-general.lua" monitorsLua} "$HOME/.config/hypr/custom/general.lua"
  '';

  programs.home-manager.enable = true;

  # An die Version koppeln, mit der installiert wird
  home.stateVersion = "25.05";
}
