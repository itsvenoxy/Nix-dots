# Nix-dots

Minimale NixOS-Konfiguration für den Wechsel von Arch zu NixOS.
Flake-basiert. Aktuell enthalten: Bootloader, Netzwerk, Locale (CH), User,
NVIDIA RTX 4090 + Intel iGPU, Hyprland + SDDM, PipeWire, Bluetooth, Basis-Pakete
sowie die **end-4 / illogical-impulse Dots** (via home-manager + QuickShell).

## Struktur

```
flake.nix                              # Einstiegspunkt, Host "nixos" + home-manager
hosts/nixos/configuration.nix          # System-Config (hier wird das meiste eingestellt)
hosts/nixos/hardware-configuration.nix # Partitionen/Hardware (beim Install neu generieren!)
hosts/nixos/home.nix                   # User-Config: illogical-impulse Dots
```

> Hinweis: Der **erste** Build baut QuickShell und Claude Desktop aus dem
> Quellcode und dauert deutlich länger als folgende Rebuilds.

Enthält außerdem **Claude Desktop** (via `github:k3d3/claude-desktop-linux-flake`,
FHS-Variante für MCP-Server). Unfree-Pakete sind über `nixpkgs.config.allowUnfree`
freigeschaltet.

**VS Code** ist declarative über home-manager konfiguriert (Extensions via
`nix-vscode-extensions`-Flake, Settings in `home.nix`). Achtung: Extensions/
Settings werden von Nix verwaltet — Änderungen über die VS-Code-GUI sind dann
nicht mehr persistent, stattdessen `home.nix` editieren.

## Installation (Kurzfassung)

Du installierst von einem NixOS-Live-USB-Stick aus. Deine **`/home`-Partition
(`nvme0n1p3`) bleibt erhalten** – es wird nur `/` (`nvme0n1p2`) neu formatiert.

1. NixOS-ISO booten (https://nixos.org/download → "NixOS ISO").
2. Partitionen mounten (NICHT neu partitionieren, nur formatieren wo nötig):

   ```bash
   sudo mkfs.ext4 -L nixos /dev/nvme0n1p2        # / neu formatieren
   sudo mount /dev/nvme0n1p2 /mnt
   sudo mkdir -p /mnt/boot /mnt/home
   sudo mount /dev/nvme0n1p1 /mnt/boot           # EFI
   sudo mount /dev/nvme0n1p3 /mnt/home           # bestehendes /home behalten
   ```

3. Hardware-Config auf dem Zielsystem generieren und diese Repo-Datei ersetzen:

   ```bash
   sudo nixos-generate-config --root /mnt
   # -> /mnt/etc/nixos/hardware-configuration.nix mit der hier im Repo abgleichen
   ```

4. Dieses Repo nach `/mnt/etc/nixos/` (oder an einen Ort deiner Wahl) legen und:

   ```bash
   sudo nixos-install --flake /mnt/etc/nixos#nixos
   ```

5. Reboot, einloggen, fertig.

## Spätere Änderungen (im laufenden System)

```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

## Anpassen

- Hostname: `networking.hostName` in `configuration.nix`
- Mehr Pakete: `environment.systemPackages`
- Channel: in `flake.nix` (aktuell `nixos-unstable`)
