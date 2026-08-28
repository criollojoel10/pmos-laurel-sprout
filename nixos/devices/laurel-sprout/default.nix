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
        # En linux >= 6.7 el módulo QCOM UFS es `ufs_qcom` (renombrado desde
        # `ufshcd-qcom`, drivers/ufs/host/ufs-qcom.ko).
        "ufs_qcom"
        # En linux >= 6.4 el core de dwc3 es el módulo `dwc3` (renombrado
        # desde `usb_dwc3`); la capa de glue Qualcomm es `dwc3_qcom`.
        "dwc3"
        "dwc3_qcom"
        "phy_qcom_qusb2"
        # En linux >= 6.6 el QMP PHY de Qualcomm se dividió en varios módulos;
        # `phy_qcom_qmp` ya no existe como módulo y rompe el módulo-shrunk
        # del initrd (modprobe FATAL: not found).
        "phy_qcom_qmp_combo"
        "phy_qcom_qmp_pcie"
        "phy_qcom_qmp_ufs"
        "phy_qcom_qmp_usb"
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
