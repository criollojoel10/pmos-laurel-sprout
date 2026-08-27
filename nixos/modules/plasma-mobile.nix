# Custom Plasma Mobile module for laurel_sprout.
#
# nixpkgs ships the kdePackages.plasma-mobile package and the
# services.displayManager.plasma-login-manager module, but it has no official
# services.desktopManager.plasma6.mobile yet (nixpkgs#432702; PR #459790 still
# a draft). Until one lands, we enable the plasma6 desktop manager for its
# well-tested plumbing (kwin_wayland security wrapper, powerdevil, plasma-nm,
# bluedevil, xdg portals) and run the Plasma Mobile shell on top of it, with
# Plasma Login Manager as the display manager.

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.plasmaMobile;
in
{
  options.programs.plasmaMobile.enable = mkEnableOption "Plasma Mobile (custom, layered over plasma6)";

  config = mkIf cfg.enable {
    # Desktop plumbing shared with Plasma Mobile: kwin/wayland, KCMs, portals,
    # powerdevil, bluedevil, plasma-nm.
    services.desktopManager.plasma6.enable = true;

    # Plasma Mobile session (package ships startplasmamobile + wayland-session).
    services.displayManager = {
      defaultSession = "plasma-mobile";
      sessionPackages = [ pkgs.kdePackages.plasma-mobile ];
    };

    # Use Plasma Login Manager (greeter) instead of the sddm that plasma6 pulls.
    services.displayManager.sddm.enable = false;
    services.displayManager.plasma-login-manager.enable = true;

    environment.systemPackages = [ pkgs.kdePackages.plasma-mobile ];

    # Mobile-friendly scaling for the 720x1560 panel.
    environment.sessionVariables = {
      QT_SCALE_FACTOR = "2";
      GDK_SCALE = "2";
    };
  };
}