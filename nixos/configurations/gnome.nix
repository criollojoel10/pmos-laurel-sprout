# GNOME configuration for laurel_sprout
# Phosh: GNOME-based mobile shell with Wayland

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
    # "feedbackd" group: required by programs.feedbackd so the user can trigger
    # haptic effects (per nixos/modules/programs/feedbackd.nix). dialout NOT
    # added: the modem is not on ttyUSB/ttyACM (no documented need).
    extraGroups = [ "wheel" "networkmanager" "video" "input" "feedbackd" ];
    initialPassword = "test"; # CHANGE on first boot
  };

  # Required by the GNOME/GTK stack (GSettings backend). Also set by
  # gnome core-os-services; explicit here for clarity.
  programs.dconf.enable = true;

  # Only packages NOT already installed by the phosh/gnome modules
  # (phosh, phoc, stevia, gnome-shell, gnome-control-center,
  # adwaita-icon-theme, gnome-settings-daemon, ... come from the modules).
  environment.systemPackages = with pkgs; [
    # Phosh companion settings app (not provided by any module)
    phosh-mobile-settings
    # Wayland utilities and Qt Wayland runtime
    wayland-utils
    qt6Packages.qtwayland
    # Diagnostics
    glmark2
    libinput
    bluez-tools
  ];

  # Desktop-only GNOME services not needed on a phone; core-shell enables them
  # with mkDefault true, so explicit false wins.
  services.gnome = {
    gnome-initial-setup.enable = false;
    gnome-remote-desktop.enable = false;
  };
  environment.gnome.excludePackages = [ pkgs.orca ];

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
  # phocConfig default already scales DSI-1 to 2; these env vars keep the
  # shell and apps coherent. QT_QPA_PLATFORM=wayland for Qt apps under Phosh.
  environment.sessionVariables = {
    PHOSH_SCALE = "2";
    GDK_SCALE = "2";
    QT_SCALE_FACTOR = "2";
    QT_QPA_PLATFORM = "wayland";
  };

  # Disable gdm (Phosh has its own greeter)
  services.displayManager.gdm.enable = false;
}
