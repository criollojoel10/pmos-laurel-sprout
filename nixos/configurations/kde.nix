# KDE configuration for laurel_sprout
# Plasma Mobile via the custom plasma-mobile module (plasma6 + plasma-mobile session)

{ config, lib, pkgs, ... }:

{
  imports = [ ../modules/plasma-mobile.nix ];

  programs.plasmaMobile.enable = true;

  # User account
  users.users.user = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" "input" "audio" ];
    initialPassword = "test"; # CHANGE on first boot
  };

  # Enable Bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # Audio via PipeWire
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # Kernel modules / firmware helpers used by Plasma Mobile daemons
  services.upower.enable = true;
}