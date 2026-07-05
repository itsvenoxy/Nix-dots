{ config, pkgs, lib, inputs, ... }:

let
  # Alle Marketplace-Extensions als Nix-Pakete. Kommt aus dem Overlay
  # (siehe configuration.nix) -> respektiert nixpkgs.config.allowUnfree.
  marketplace = pkgs.vscode-marketplace;

  # Monitor-Setup fuer die Lua-Config der Dots (hl.monitor aus hyprland/lib).
  monitorsLua = ''
    -- Monitore (von home-manager gesetzt, siehe home.nix)
    -- BEIDE Monitore sind native 2560x1440 (DP-3 = MAG321CURV @60Hz,
    -- DP-4 = MSI MAG322CQR @165Hz) -> keine Skalierung noetig, beide scale 1,
    -- damit die UI auf beiden gleich gross ist. DP-4 per "auto" buendig rechts.
    hl.monitor({ output = "DP-3", mode = "2560x1440@60",  position = "0x0",  scale = "1" })
    hl.monitor({ output = "DP-4", mode = "2560x1440@165", position = "auto", scale = "1" })
  '';

  # Standard-Apps der Dots-Keybinds umbiegen. Die Dots laden
  # ~/.config/hypr/custom/variables.lua VOR den Keybinds (offizieller
  # Override-Hook, siehe hyprland/keybinds.lua) -> globale Neuzuweisung der
  # Variablen genuegt, und die bestehenden Kombis starten unsere Apps:
  #   Super+T / Super+Return / Ctrl+Alt+T -> terminal
  #   Super+E                             -> fileManager
  #   Super+W                             -> browser
  # (Super+B bleibt der Sidebar-Toggle der Shell.) KEIN "local" davor --
  # es muessen die Globals der Dots ueberschrieben werden.
  variablesLua = ''
    -- Standard-Apps (von home-manager gesetzt, siehe home.nix)
    terminal    = "kitty"
    browser     = "brave-origin-beta"
    fileManager = "kitty yazi"
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

  # VSCodium declarative: Extensions + Settings aus deiner Arch-Installation.
  # programs.vscodium (statt programs.vscode mit vscodium-package), damit die
  # Config in die richtigen Pfade geschrieben wird (~/.config/VSCodium statt
  # ~/.config/Code) -- sonst kommen Settings/Extensions im Editor nie an.
  programs.vscodium = {
    enable = true;

    profiles.default = {
      extensions = with marketplace; [
        anthropic.claude-code
        formulahendry.auto-rename-tag
        miguelsolorio.symbols
        ms-azuretools.vscode-containers
        ms-python.debugpy
        ms-python.python
        detachhead.basedpyright   # Pylance-Ersatz (Open Source, laeuft auf VSCodium)
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
        # basedpyright statt Pylance: ms-python's eigenen LSP abschalten
        "python.languageServer" = "None";
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

  # Dark Mode als Standard, systemweit. GTK-Apps und Flatpaks (z.B. Termius)
  # fragen die Praeferenz ueber das XDG-Portal ab, das sie aus dconf liest
  # (org.freedesktop.appearance color-scheme). Ohne das starten Flatpaks hell
  # (bekannt: flathub/com.termius.Termius#82).
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
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

  # Monitor- und App-Variablen-Config in die Lua-Dots schreiben, NACH deren
  # Seeding (das Dots-Seeding loescht/kopiert ~/.config/hypr bei jedem Switch
  # neu, wuerde die Dateien also sonst wieder ueberschreiben).
  home.activation.setMonitors = lib.hm.dag.entryAfter [ "copyIllogicalImpulseConfigs" ] ''
    $DRY_RUN_CMD install -Dm644 ${pkgs.writeText "hypr-custom-general.lua" monitorsLua} "$HOME/.config/hypr/custom/general.lua"
    $DRY_RUN_CMD install -Dm644 ${pkgs.writeText "hypr-custom-variables.lua" variablesLua} "$HOME/.config/hypr/custom/variables.lua"
  '';

  programs.home-manager.enable = true;

  # An die Version koppeln, mit der installiert wird
  home.stateVersion = "25.05";
}
