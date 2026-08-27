# Device configuration for Xiaomi Mi A3 (laurel_sprout)
# Qualcomm SM6125 / Snapdragon 665 / Adreno 610

{ config, lib, pkgs, ... }:

{
  # Target platform
  nixpkgs.hostPlatform = "aarch64-linux";

  # Boot configuration
  boot = {
    # Use mainline kernel with SM6125 DTS
    kernelPackages = pkgs.linuxKernel.packagesFor (
      pkgs.linuxKernel.kernels.linux_6_12.override {
        structuredExtraConfig = with lib.kernel; {
          # SM6125 essentials
          ARM64 = yes;
          ARCH_SM6125 = yes;
          # UFS
          SCSI_UFSHCD = yes;
          SCSI_UFSHCD_PLATFORM = yes;
          SCSI_UFS_QCOM = yes;
          # Display
          DRM = yes;
          DRM_MSM = module;
          FB_SIMPLE = yes;
          DRM_FBDEV_EMULATION = yes;
          FRAMEBUFFER_CONSOLE = yes;
          DRM_PANEL_SAMSUNG_S6E8FC0 = module;
          # USB
          USB = yes;
          USB_DWC3 = yes;
          USB_DWC3_QCOM = yes;
          USB_CONFIGFS_RNDIS = yes;
          # Input
          TOUCHSCREEN_EDT_FT5X06 = yes;
          # WiFi/BT
          ATH10K = yes;
          ATH10K_SNOC = yes;
          BT_QCOMSMD = yes;
          # Power
          CPUFREQ_DT = yes;
          THERMAL = yes;
        };
      }
    );

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
