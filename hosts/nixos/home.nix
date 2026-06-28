{ config, pkgs, inputs, ... }:

let
  # Alle Marketplace-Extensions als Nix-Pakete. Kommt aus dem Overlay
  # (siehe configuration.nix) -> respektiert nixpkgs.config.allowUnfree.
  marketplace = pkgs.vscode-marketplace;
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

  programs.home-manager.enable = true;

  # An die Version koppeln, mit der installiert wird
  home.stateVersion = "25.05";
}
