# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ modulesPath, ... }:

{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot.initrd.availableKernelModules =
    [ "ata_piix" "uhci_hcd" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/807ed228-ddf4-4a78-936b-4748c884af0c";
    fsType = "ext4";
  };

  fileSystems."/media" = {
    device = "/dev/disk/by-uuid/33305cfc-cc29-43a1-bf7a-3504211aea39";
    fsType = "ext4";
  };

  swapDevices =
    [{ device = "/dev/disk/by-uuid/475767b2-bf14-46f6-ae8d-be5683b39b6f"; }];

}
