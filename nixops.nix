{ inputs }:

{
  # Flake nixops requires nixpkgs input
  inherit (inputs) nixpkgs;

  network = {
    description = "My personal homelab + VPN gateway";
    # Allow rolling back machines in network
    enableRollback = true;
  };

  defaults = { config, pkgs, ... }: {
    # Add sops-nix module
    imports = [ inputs.sops-nix.nixosModule ./modules/services.nix ];

    # Pass nixpkgs flake as argument to modules
    _module.args.nixpkgs = inputs.nixpkgs;

    # I'm the owner :)
    deployment.owners = [ "ruby@srxl.me" ];

    # Use a flake-enabled Nix
    nix = {
      package = pkgs.nixUnstable;
      extraOptions = ''
        experimental-features = nix-command flakes
      '';
    };

    # Set of useful packages for all machines
    environment.systemPackages = with pkgs; [
      bat
      file
      htop
      kitty.terminfo
      ncdu
      psmisc
      ripgrep
      vim
      wget
    ];

    # Use Fish as the shell
    programs.fish.enable = true;
    users.defaultUserShell = pkgs.fish;

    # Clean /tmp on boot
    boot.cleanTmpDir = true;

    # Enable SSH
    services.sshd.enable = true;

    # Accept Let's Encrypt ToS and set email
    security.acme = {
      acceptTerms = true;
      email = builtins.head config.deployment.owners;
    };
  };

  # gateway - VPN gateway for accessing homelab from the *spooky outside world oooooo*
  gateway = import ./machines/gateway.nix;
  # opal-entrypoint - Wireguard client + reverse proxy entry to the homeland
  opal-entrypoint = import ./machines/opal-entrypoint.nix;
  # opal-media-server - Media server running Jellyfin
  opal-media-server = import ./machines/opal-media-server.nix;
  # topaz - An old laptop of mine, but it has a GPU which is nice
  topaz = import ./machines/topaz.nix;
}
