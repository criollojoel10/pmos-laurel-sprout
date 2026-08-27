# Console configuration for laurel_sprout
# Minimal text-only system with SSH access

{ config, lib, pkgs, ... }:

{
  # Disable graphical interfaces
  services.xserver.enable = false;

  # Console only
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  # Minimal packages
  environment.systemPackages = with pkgs; [
    vim
    nano
    htop
    git
    curl
    wget
    usbutils
    kmod
    e2fsprogs
    parted
    file
    iproute2
    iputils
    nftables
  ];

  # Networking
  networking.networkmanager.enable = true;

  # SSH for remote access
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  # Dev/experimental build: allow root login via serial console on first
  # boot. Satisfies the NixOS lock-out assertion for a headless device with
  # no SSH key baked in. NOT for production use.
  users.allowNoPasswordLogin = true;

  # Disable unnecessary services
  services.xserver.displayManager.gdm.enable = false;
  services.displayManager.sddm.enable = false;
}
