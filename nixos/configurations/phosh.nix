# Phosh configuration for laurel_sprout
# GNOME-based mobile shell with Wayland

{ config, lib, pkgs, ... }:

{
  # Enable X11/Wayland for Phosh
  services.xserver = {
    enable = true;
    desktopManager.phosh = {
      enable = true;
      user = "user";
      group = "users";
    };
  };

  # Phosh settings
  services.xserver.desktopManager.phosh.phocConfig = {
    xwayland = "immediate";
  };

  # User account
  users.users.user = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" "input" ];
    initialPassword = "test"; # CHANGE on first boot
  };

  # Packages for Phosh environment
  environment.systemPackages = with pkgs; [
    # Phosh dependencies
    phosh
    phosh-mobile-settings
    phoc
    
    # GNOME integration
    adwaita-icon-theme
    gnome-control-center
    gnome-session
    
    # Wayland
    wayland-utils
    qt6-wayland
    
    # Diagnostics
    mesa-utils
    eglinfo
    glmark2-es2-wayland
    libinput
    htop
    vim
    
    # Network
    networkmanagerapplet
    
    # Bluetooth
    bluez
    bluez-tools
  ];

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

  # Display scaling for 720x1560
  environment.sessionVariables = {
    PHOSH_SCALE = "2";
    GDK_SCALE = "2";
    QT_SCALE_FACTOR = "2";
  };

  # Disable gdm (Phosh has its own greeter)
  services.xserver.displayManager.gdm.enable = false;
}
