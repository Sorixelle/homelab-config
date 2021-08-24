{
  description = "My homelab's configuration, managed with Nixops";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self, flake-utils, nixpkgs, pre-commit-hooks, sops-nix, ... }@inputs:
    let genSystems = nixpkgs.lib.genAttrs flake-utils.lib.defaultSystems;
    in {
      nixopsConfigurations.default = import ./nixops.nix { inherit inputs; };

      devShell = genSystems (s:
        let pkgs = nixpkgs.legacyPackages.${s};
        in pkgs.mkShell {
          name = "homelab-dotfiles";

          sopsPGPKeyDirs = [ "./secrets/keys" ];

          nativeBuildInputs = with pkgs; [
            (callPackage sops-nix { }).sops-import-keys-hook
            nix-linter
            nixfmt
            nixopsUnstable
            (nixos-generators.override { nix = nixUnstable; })
            rnix-lsp
            ssh-to-pgp
            vim
          ];

          EDITOR = pkgs.vim;
          shellHook = ''
            ${self.checks.${s}.pre-commit-check.shellHook}
          '';
        });

      checks = genSystems (s: {
        pre-commit-check = pre-commit-hooks.lib.${s}.run {
          src = builtins.path {
            path = ./.;
            name = "homelab-dotfiles";
          };
          hooks = {
            nixfmt.enable = true;
            nix-linter.enable = true;
          };
        };
      });
    };
}
