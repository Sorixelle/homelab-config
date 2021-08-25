{ modulesPath, ... }:

{
  # Setup modules for QEMU
  imports = [ "${modulesPath}/profiles/qemu-guest.nix" ];

  # Enable QEMU guest agent
  services.qemuGuest.enable = true;

  services.openssh = {
    # Enable SSH
    enable = true;
    # Allow root login
    permitRootLogin = "yes";
  };

  # Set a default root password
  users.users.root.password = "deploy";
}
