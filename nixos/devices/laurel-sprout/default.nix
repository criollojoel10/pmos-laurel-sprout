# Device configuration for Xiaomi Mi A3 (laurel_sprout)
# Qualcomm SM6125 / Snapdragon 665 / Adreno 610

{ config, lib, pkgs, ... }:

{
  # Target platform
  nixpkgs.hostPlatform = "aarch64-linux";

  # Boot configuration
  boot = {
    # El kernel real de arranque es el COMPARTIDO 7.1.0 (Image/DTB/modules
    # parcheados para SM6125) que se inserta en boot.img a partir del artefacto
    # `kernel-debug` (ver build-nixos-rootfs.sh). NixOS SOLO debe proveer el
    # paquete de kernel de userspace: usamos el linuxPackages_6_12 stock
    # (LTS, ya servido por cache.nixos.org para aarch64). NO usar
    # `linux_6_12.override { structuredExtraConfig = {...} }`: esa derivación
    # no está en caché, se recompila emulada vía QEMU y generate-config.pl
    # falla con "Error in reading or end of file." (nixpkgs#59914/#521048).
    kernelPackages = pkgs.linuxPackages_6_12;

    # DTB
    loader.grub.enable = false;
    loader.generic-extlinux-compatible.enable = true;

    # Initrd
    initrd = {
      availableKernelModules = [
        "ufshcd-qcom"
        "usb_dwc3"
        "dwc3_qcom"
        "phy_qcom_qusb2"
        "phy_qcom_qmp"
      ];
    };

    # Kernel command line
    kernelParams = [
      "console=ttyMSM0,115200n8"
      "consoleblank=0"
      "androidboot.hardware=laurel_sprout"
      "panic=10"
    ];
  };

  # Filesystems
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_ROOT";
      fsType = "ext4";
    };
  };

  # Networking
  networking = {
    hostName = "laurel-pmos";
    networkmanager.enable = true;
    firewall.enable = false; # Experimental port
  };

  # SSH (for testing, no default passwords)
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  # Users
  users.users.root = {
    openssh.authorizedKeys.keys = [
      # Placeholder: replace with actual test key
    ];
  };

  users.mutableUsers = false;

  # System packages
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
  ];

  # Time zone
  time.timeZone = "UTC";

  # System version
  system.stateVersion = "25.05";
}
