{ modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  deployment.targetHost = "192.168.1.110";

  # Need to allow unfree packages on this machine for the NVIDIA drivers
  nixpkgs.config.allowUnfree = true;

  boot = {
    # Kernel modules to load
    initrd.availableKernelModules = [
      "xhci_pci"
      "ehci_pci"
      "ahci"
      "usb_storage"
      "sd_mod"
      "sr_mod"
      "sdhci_pci"
      "rtsx_pci_sdmmc"
    ];
    kernelModules = [ "kvm-intel" ];

    # Bootloader configuration
    loader = {
      timeout = 0;
      efi.canTouchEfiVariables = true;
      systemd-boot = {
        enable = true;
        editor = false;
      };
    };
  };

  # Filesystems to mount at boot
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NixOS";
      fsType = "ext4";
    };
    "/boot" = {
      device = "/dev/disk/by-label/EFI";
      fsType = "vfat";
    };
  };

  # Swap partition
  swapDevices = [{ device = "/dev/disk/by-label/Swap"; }];

  # Configure networking from DHCP
  networking.interfaces.enp8s0.useDHCP = true;

  hardware = {
    # Enable and setup OpenGL drivers
    opengl.enable = true;
    # Enable the NVIDIA persistence daemon
    nvidia.nvidiaPersistenced = true;
  };

  services = {
    # Don't suspend the machine when the lid is closed
    logind.lidSwitch = "ignore";
    # Setup NVIDIA drivers
    xserver.videoDrivers = [ "nvidia" ];
  };
}
