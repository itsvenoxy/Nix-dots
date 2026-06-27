{ config, lib, pkgs, modulesPath, ... }:

# ACHTUNG: Diese Datei ist anhand deiner aktuellen Arch-Partitionen vorgebaut.
# Beim Installieren bitte mit `nixos-generate-config` neu erzeugen lassen und
# diese Datei damit ersetzen -> dann sind Kernel-Module/UUIDs garantiert korrekt.

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # / -> nvme0n1p2 (ext4)
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/209f864e-0f7b-4125-a1ca-954381f15ceb";
    fsType = "ext4";
  };

  # /boot -> nvme0n1p1 (EFI/vfat)
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/AFF9-610F";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  # /home -> nvme0n1p3 (ext4) - deine bestehende Home-Partition bleibt erhalten
  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/d5d7d1bf-146d-467e-96ba-2acdae3bf6bf";
    fsType = "ext4";
  };

  swapDevices = [ ];

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
