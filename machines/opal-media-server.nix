{ config, modulesPath, ... }:

{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  # Set deployment IP
  deployment.targetHost = "192.168.1.10";

  boot = {
    # Set avaliable kernel modules
    initrd.availableKernelModules =
      [ "ata_piix" "uhci_hcd" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" ];

    # Configure GRUB for booting
    loader.grub = {
      enable = true;
      device = "/dev/sda";
    };
  };

  # Enable QEMU guest agent
  services.qemuGuest.enable = true;

  networking = {
    # Set hostname
    hostName = "media";

    # Use DHCP for internet interface
    interfaces.ens18.useDHCP = true;
  };

  # Enable the Jellyfin media server
  services.jellyfin = {
    enable = true;
    openFirewall = true;
  };

  # Sets up Nginx entries on opal-gateway to proxy to Jellyfin
  srxl.services.http = let localIP = config.deployment.targetHost;
  in {
    media = {
      locations = {
        "= /" = { return = "302 https://$host/web/"; };
        "/" = {
          proxyPass = "http://${localIP}:8096";
          extraConfig = "proxy_buffering off;";
        };
        "= /web/" = { proxyPass = "http://${localIP}:8096/web/index.html"; };
        "/socket" = {
          proxyPass = "http://${localIP}:8096";
          proxyWebsockets = true;
        };
      };
    };
  };
}
