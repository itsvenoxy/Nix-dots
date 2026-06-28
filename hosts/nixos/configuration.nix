{ config, pkgs, lib, inputs, ... }:

let
  # SDDM-Theme mit gewaehltem eingebettetem Look.
  # Alternativen: "black_hole" "cyberpunk" "japanese_aesthetic" "jake_the_dog" "hyprland_kath" ...
  sddm-astronaut = pkgs.sddm-astronaut.override {
    embeddedTheme = "astronaut";
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
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    package = pkgs.kdePackages.sddm;       # Qt6 (noetig fuer sddm-astronaut)
    theme = "sddm-astronaut-theme";
    extraPackages = [ sddm-astronaut ];
  };

  # XDG-Portals (Screenshare, Datei-Dialoge etc.)
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Von den illogical-impulse Dots benoetigt (QtPositioning/Wetter etc.)
  services.geoclue2.enable = true;

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
    termius           # SSH-Client
    antigravity       # Google Antigravity IDE

    # CLI-Tools
    helix
    tmux
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

    # SDDM-Theme (auch im Environment, damit der sddm-greeter es findet)
    sddm-astronaut

    # Claude Desktop (FHS-Variante -> MCP-Server via npx/uvx/docker nutzbar)
    inputs.claude-desktop.packages.${pkgs.system}.claude-desktop-with-fhs

    # kitty/fish/starship liefert das illogical-impulse home-manager-Modul
  ];

  # Flakes + neue Nix-Kommandos aktivieren
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # sudo fuer wheel ohne extra Config
  security.sudo.wheelNeedsPassword = true;

  # ---------------------------------------------------------------------------
  # NICHT aendern ohne Grund: legt das Default-Verhalten von NixOS fest.
  # Auf die Version setzen, mit der du installierst.
  # ---------------------------------------------------------------------------
  system.stateVersion = "25.05";
}
