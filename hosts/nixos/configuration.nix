{ config, pkgs, lib, inputs, ... }:

let
  # Termius (Electron, aus Snap repackaged) laedt libGL.so.1 zur Laufzeit per
  # dlopen -> findet es nicht ("Could not dlopen libGL.so.1"). autoPatchelf
  # fasst dlopen nicht an. Fix: libglvnd (pkgs.libGL) + NVIDIA-Treiberpfad
  # (/run/opengl-driver/lib) in den LD_LIBRARY_PATH des Wrappers; libGL
  # zusaetzlich in buildInputs (falls eine .so es als DT_NEEDED braucht).
  termius-fixed = pkgs.termius.overrideAttrs (old: {
    buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.libGL ];
    # Electron/Snap auf NVIDIA: libGL.so.1 wird per dlopen geladen (LD_LIBRARY_
    # PATH), und die GPU-Init muss den NVIDIA-GBM/GLX-Treiber nehmen statt am
    # Mesa-"dri_gbm.so" zu scheitern -> sonst leeres/schwarzes Fenster.
    # (--disable-gpu => Fenster bleibt leer, also NICHT verwenden.)
    postFixup = ''
      makeWrapper $out/opt/termius/termius-app $out/bin/termius-app \
        "''${gappsWrapperArgs[@]}" \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ pkgs.libGL ]}:/run/opengl-driver/lib" \
        --set-default __GLX_VENDOR_LIBRARY_NAME nvidia \
        --set-default GBM_BACKEND nvidia-drm \
        --set-default __NV_DISABLE_EXPLICIT_SYNC 1
    '';
  });

  # claude-cowork-nix bringt keinen Launcher-Eintrag mit -> selbst bauen, damit
  # "Claude" im App-Launcher auftaucht. Registriert auch den claude://-Handler
  # (OAuth-Ruecksprung nach dem Login).
  claude-desktop-launcher = pkgs.makeDesktopItem {
    name = "claude-desktop";
    desktopName = "Claude";
    comment = "Claude Desktop";
    exec = "claude-desktop %U";
    icon = "claude-desktop";
    categories = [ "Network" "Utility" ];
    startupWMClass = "Claude";
    mimeTypes = [ "x-scheme-handler/claude" ];
  };
in
{
  # Unfree-Pakete erlauben (Claude Desktop, claude-code, NVIDIA-Treiber, ...)
  nixpkgs.config.allowUnfree = true;

  # brave-origin aus dem offenen PR-Fork holen (bis es in nixpkgs gemerged ist).
  # Sobald es in nixos-unstable ist: Overlay + Input entfernen, brave-origin
  # bleibt dann einfach in systemPackages stehen.
  nixpkgs.overlays = [
    (final: prev: {
      brave-origin = (import inputs.nixpkgs-brave {
        inherit (prev) system;
        config.allowUnfree = true;
      }).brave-origin;
    })

    # VS-Code-Marketplace als pkgs.vscode-marketplace.*. Ueber das Overlay (statt
    # ueber den Flake-Output) werden die Extensions mit DIESEM pkgs gebaut, sodass
    # nixpkgs.config.allowUnfree hier greift (sonst: "unfree license"-Fehler bei
    # anthropic.claude-code). Kein NIXPKGS_ALLOW_UNFREE=1 mehr noetig.
    inputs.nix-vscode-extensions.overlays.default
  ];

  # ---------------------------------------------------------------------------
  # Bootloader (UEFI -> systemd-boot, einfachste Variante)
  # ---------------------------------------------------------------------------
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # Aktuellster Kernel (gut fuer neue Hardware wie Raptor Lake / RTX 4090)
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # ---------------------------------------------------------------------------
  # Netzwerk
  # ---------------------------------------------------------------------------
  networking.hostName = "nixos";          # <- nach Wunsch aendern
  networking.networkmanager.enable = true;

  # ---------------------------------------------------------------------------
  # Zeit & Sprache
  # ---------------------------------------------------------------------------
  time.timeZone = "Europe/Zurich";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_TIME = "de_CH.UTF-8";
    LC_MONETARY = "de_CH.UTF-8";
    LC_MEASUREMENT = "de_CH.UTF-8";
  };
  # Tastatur-Layout (Konsole + X/Wayland-Apps)
  console.keyMap = "de_CH-latin1";
  services.xserver.xkb = {
    layout = "ch";
    variant = "de";
  };

  # ---------------------------------------------------------------------------
  # User
  # ---------------------------------------------------------------------------
  users.users.janis = {
    isNormalUser = true;
    description = "Janis";
    extraGroups = [ "wheel" "networkmanager" "video" "audio" ];
    shell = pkgs.bash;
  };

  # ---------------------------------------------------------------------------
  # NVIDIA RTX 4090 + Intel UHD 770 (Hybrid)
  # ---------------------------------------------------------------------------
  hardware.graphics = {
    enable = true;
    enable32Bit = true;                   # noetig fuer Steam/Wine/32-Bit-Apps
  };

  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;            # Pflicht fuer Wayland/Hyprland
    open = true;                          # Ada Lovelace (4090) -> Open-Modul empfohlen
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    powerManagement.enable = true;
  };

  # ---------------------------------------------------------------------------
  # Hyprland + SDDM (Wayland)
  # ---------------------------------------------------------------------------
  programs.hyprland.enable = true;

  # SilentSDDM Login-Theme (uiriansan/SilentSDDM) via dessen NixOS-Modul.
  # Das Modul richtet SDDM komplett ein: Qt6-sddm, Theme "silent", die noetigen
  # extraPackages und qtvirtualkeyboard-Settings. Ersetzt sddm-astronaut.
  programs.silentSDDM = {
    enable = true;
    # Themes: default default-left default-right rei ken silvia everforest
    #         gruvbox nord catppuccin-{mocha,macchiato,frappe,latte}
    theme = "default";
    # settings = { ... };  # Feintuning, siehe Modul-Beispiel / SilentSDDM-Wiki
  };

  # XDG-Portals (Screenshare, Datei-Dialoge etc.)
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Von den illogical-impulse Dots benoetigt (QtPositioning/Wetter etc.)
  services.geoclue2.enable = true;

  # ---------------------------------------------------------------------------
  # Brave: Extensions deklarativ erzwingen (Managed Policy) + Plasma-Host
  # ---------------------------------------------------------------------------
  # Force-Install via Chrome-Web-Store-Update-URL. Hinweis: brave-origin ist ein
  # Fork ("brave-origin-beta"); falls der einen anderen Policy-Pfad als
  # /etc/brave nutzt, einfach manuell aus dem Store nachinstallieren.
  environment.etc."brave/policies/managed/extensions.json".text = builtins.toJSON {
    ExtensionInstallForcelist = [
      "ghmbeldphafepmbegfdlkpapadhbakde;https://clients2.google.com/service/update2/crx"  # Proton Pass
      "cimiefiiaegbelhefglklhhakcgmhkai;https://clients2.google.com/service/update2/crx"  # Plasma Integration
    ];
  };

  # Native-Messaging-Host, damit die Plasma-Integration-Extension wirklich
  # funktioniert (u.a. Browser-Medien -> MPRIS -> illogical-impulse Media-Widget).
  environment.etc."brave/native-messaging-hosts/org.kde.plasma.browser_integration.json".source =
    "${pkgs.kdePackages.plasma-browser-integration}/etc/chromium/native-messaging-hosts/org.kde.plasma.browser_integration.json";

  # Fonts fuer die Dots. material-symbols = Icon-Font der end-4/illogical-
  # impulse Shell; ohne sie erscheinen Icons als Text (z.B. "arrow_upward").
  fonts.packages = with pkgs; [
    rubik
    material-symbols
    nerd-fonts.ubuntu
    nerd-fonts.jetbrains-mono
  ];

  # ---------------------------------------------------------------------------
  # Audio (PipeWire)
  # ---------------------------------------------------------------------------
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # ---------------------------------------------------------------------------
  # Bluetooth
  # ---------------------------------------------------------------------------
  hardware.bluetooth.enable = true;

  # ---------------------------------------------------------------------------
  # Steam (FHS-Env + udev fuer Controller). 32-Bit-Grafik ist via
  # hardware.graphics.enable32Bit oben schon aktiv (Pflicht fuer Steam/Proton).
  # ---------------------------------------------------------------------------
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;        # Ports fuer Remote Play / Streaming
    dedicatedServer.openFirewall = false;  # nur fuer eigene Game-Server noetig
  };
  programs.gamemode.enable = true;         # Feral GameMode -> bessere Performance

  # ZRAM als Swap (wie auf Arch)
  zramSwap.enable = true;

  # ---------------------------------------------------------------------------
  # Basis-Pakete (bewusst minimal, Rest fuegen wir spaeter hinzu)
  # ---------------------------------------------------------------------------
  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    curl
    pavucontrol
    spotifyd
    htop
    vesktop          # Discord-Client (Vencord) statt offiziellem Discord
    obsidian
    claude-code
    brave-origin     # aus PR #511131 via Overlay (siehe oben)

    # Proton
    protonmail-desktop
    proton-pass
    proton-vpn        # offizieller ProtonVPN-Client (GUI)

    # Telegram
    materialgram      # Material-You Telegram-Client
    telegram-desktop  # offizieller Client

    # Weitere Apps
    spotify           # GUI (zusaetzlich zum spotifyd-Daemon oben)
    termius-fixed     # SSH-Client (mit libGL-Fix, siehe oben)
    antigravity       # Google Antigravity IDE

    # CLI-Tools
    helix
    tmux
    yazi          # TUI-Dateimanager
    fastfetch
    duf
    gum
    unzip
    smartmontools
    zbar
    zenity
    pipx
    inetutils
    nano

    # Laufzeit-Abhaengigkeit fuer Hyprlands GUI-Dialoge (update/plugin/dialog).
    hyprland-qtutils

    # Datei-Manager (Default fuer den fileManager-Keybind der Dots)
    nautilus

    # Host fuer die "Plasma Integration"-Browser-Extension (Medien->MPRIS etc.)
    kdePackages.plasma-browser-integration

    # Claude Desktop kommt ueber programs.claude-desktop (Modul, siehe unten);
    # der Launcher-Eintrag fehlt im Paket -> selbst gebaut:
    claude-desktop-launcher
    # kitty/fish/starship liefert das illogical-impulse home-manager-Modul
  ];

  # Claude Desktop (Reginleif88/claude-cowork-nix): aktuelle Version, Electron 41,
  # Cowork + Claude-Code-Integration. claudeCodePackage verdrahtet das lokale
  # "Code"-Feature (CLAUDE_CODE_LOCAL_BINARY) mit dem claude-code aus nixpkgs.
  programs.claude-desktop = {
    enable = true;
    claudeCodePackage = pkgs.claude-code;
  };

  # Flakes + neue Nix-Kommandos aktivieren
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # fish aktivieren, damit environment.shellAliases auch in der fish-Shell
  # greifen (die illogical-Dots starten fish im Terminal).
  programs.fish.enable = true;

  # Praktische Aliase fuers Rebuilden (Config liegt unter /home/janis/Nix-dots)
  environment.shellAliases = {
    nrs = "sudo nixos-rebuild switch --flake /home/janis/Nix-dots#nixos --impure";
    nrt = "sudo nixos-rebuild test   --flake /home/janis/Nix-dots#nixos --impure";
    nrb = "sudo nixos-rebuild boot   --flake /home/janis/Nix-dots#nixos --impure";
    # erst neueste Config ziehen, dann switchen
    nixup = "git -C /home/janis/Nix-dots pull origin main && sudo nixos-rebuild switch --flake /home/janis/Nix-dots#nixos --impure";
  };

  # sudo fuer wheel ohne extra Config
  security.sudo.wheelNeedsPassword = true;

  # ---------------------------------------------------------------------------
  # NICHT aendern ohne Grund: legt das Default-Verhalten von NixOS fest.
  # Auf die Version setzen, mit der du installierst.
  # ---------------------------------------------------------------------------
  system.stateVersion = "25.05";
}
