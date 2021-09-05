let publicIP = "192.168.1.2";
in { config, lib, nodes, modulesPath, ... }: {
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  # Set deployment IP
  deployment.targetHost = publicIP;

  # Read and deploy secrets from sops yaml
  sops = {
    defaultSopsFile = ../secrets/opal-entrypoint.yaml;
    secrets.wg_client_privkey = { };
    secrets.nginx_dh_params = { owner = "nginx"; };
  };

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
    hostName = "entrypoint";

    # Use DHCP for internet interface
    interfaces.ens18.useDHCP = true;

    # Don't use the local resolver - we'll get it from DHCP anyway
    resolvconf.useLocalResolver = false;

    # Setup a Wireguard interface
    wg-quick.interfaces.wg0 = {
      # Address of wg0 on client
      address = [ "192.168.50.2" ];
      # Private key - file created by sops-nix
      privateKeyFile = "/run/secrets/wg_client_privkey";
      peers = [{
        # Public key of Wireguard server
        publicKey = "YDcqYFV64FH7NPYeJedFArEEYRwI2s0FzO/BhmvUt30=";
        # Endpoint of Wireguard server to connect to
        endpoint = let
          gateway = nodes.gateway.config;
          ip = gateway.deployment.targetHost;
          port = toString gateway.networking.wg-quick.interfaces.wg0.listenPort;
        in "${ip}:${port}";
        # IPs that the server is allowed to communicate with
        allowedIPs = [ "192.168.50.0/24" ];
        # Send keepalive to ensure connection stays open
        persistentKeepalive = 25;
      }];
    };

    firewall = {
      # Allow incoming traffic to both regular and PROXY protocol routes
      allowedTCPPorts = [ 80 443 800 4430 ];
      # Allow incoming DNS traffic
      allowedUDPPorts = [ 53 ];
    };
  };

  # Configures Nginx services
  # TODO: handle services where isHttp == false (plain tcp streams)
  services.nginx = let
    services = lib.mapAttrsToList (_: node: node.config.srxl.services) nodes;

    wireguardIP =
      builtins.head config.networking.wg-quick.interfaces.wg0.address;
  in {
    enable = true;
    enableReload = true;
    recommendedOptimisation = true;
    recommendedTlsSettings = true;
    recommendedGzipSettings = true;
    recommendedProxySettings = true;

    # Set Nginx Diffie-Hellman parameters from sops secrets
    sslDhparam = "/run/secrets/nginx_dh_params";

    # Allow reading real source addresses from both Wireguard IP addresses,
    # and read the real IP from PROXY protocol
    commonHttpConfig = let
      gatewayWireguardIP = builtins.head
        nodes.gateway.config.networking.wg-quick.interfaces.wg0.address;
    in ''
      set_real_ip_from ${wireguardIP};
      set_real_ip_from ${gatewayWireguardIP};
      real_ip_header proxy_protocol;
    '';

    # Define HTTP(S) servers
    # All services use PROXY protocol, so they can read the correct source IP
    # address into X-Forwarded-For, etc. The gateway machine will proxy
    # requests directly to these servers.
    virtualHosts = let
      httpServices = builtins.foldl' (acc: curr: acc // curr.http) { } services;
    in builtins.mapAttrs (name: service: {
      inherit (service) locations;
      serverName = "${name}.gemstonelabs.cloud";
      listen = [
        {
          addr = wireguardIP;
          port = 800;
          extraParameters = [ "proxy_protocol" ];
        }
        {
          addr = wireguardIP;
          port = 4430;
          ssl = true;
          extraParameters = [ "proxy_protocol" ];
        }
      ];
      forceSSL = true;
      enableACME = true;
    }) httpServices;

    # Define plain TCP stream servers
    # Used to accept regular HTTP(S) traffic from the local network, and wrap
    # it in PROXY protocol so they can be sent to the actual servers defined
    # above.
    streamConfig = let localIP = config.deployment.targetHost;
    in ''
      server {
        listen ${localIP}:80;
        proxy_protocol on;
        proxy_pass ${wireguardIP}:800;
      }
      server {
        listen ${localIP}:443;
        proxy_protocol on;
        proxy_pass ${wireguardIP}:4430;
      }
    '';
  };

  # Configure BIND for local DNS
  services.bind = {
    enable = true;
    # Only listen on the home network-local address
    listenOn = [ publicIP ];
    # Allow requests from home network only
    cacheNetworks = [
      "192.168.0.0/24" # Wider LAN
      "192.168.1.0/24" # Gemstone Labs LAN
    ];

    # Records for gemstonelabs.cloud
    # Not declarative, unfortunately - gets a bit tricky with the whole serial
    # thing in the SOA record. They're on these locations on the server - just
    # trust me bro.
    zones = {
      # Normal records
      "gemstonelabs.cloud" = {
        master = true;
        file = "/etc/bind/gemstonelabs.zone";
      };
      # Reverse lookup records
      "1.168.192.in-addr.arpa" = {
        master = true;
        file = "/etc/bind/gemstonelabs-reverse.zone";
      };
    };
  };

  system.stateVersion = "21.05";
}
