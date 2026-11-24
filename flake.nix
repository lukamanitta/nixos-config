{
  description = "My first NixOS flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    neovim-nightly-overlay.inputs.nixpkgs.follows = "nixpkgs";

    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    zen-browser.inputs.nixpkgs.follows = "nixpkgs";
    zen-browser.inputs.home-manager.follows = "home-manager";

    # OpenCode 2.x is not in nixpkgs yet; build its own pinned release. Keep
    # its nixpkgs pin so its fixed node_modules hash stays reproducible.
    opencode.url = "github:anomalyco/opencode/v2.4.1";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    colourme.url = "github:lukamanitta/colourme";
    colourme.inputs.nixpkgs.follows = "nixpkgs";

    # Affinity v3 packaged as a Wine prefix by a community flake. Keep its
    # own nixpkgs pin: Wine/prefix compatibility is sensitive to it.
    affinity-nix.url = "github:mrshmllow/affinity-nix";

    # CoolerControl 5.x + a seedable daemon config; nixpkgs is still on 4.x.
    coolercontrol.url = "github:Daaboulex/coolercontrol-nix";
    coolercontrol.inputs.nixpkgs.follows = "nixpkgs";
    coolercontrol.inputs.home-manager.follows = "home-manager";

    # Personal MSI development overlay (local checkout; path input keeps it
    # credential-free). Not needed on hosts without the work checkouts.
    msi-nix.url = "git+file:///home/luka/code/msi-nix";
  };

  outputs =
    { nixpkgs, home-manager, ... }@inputs:
    {
      nixosConfigurations = {
        luka-nixos-test = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };
          modules = [
            ./modules/hosts/luka-nixos-test
            home-manager.nixosModules.home-manager
          ];
        };

        luka-workstation = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };
          modules = [
            ./modules/hosts/luka-workstation
            home-manager.nixosModules.home-manager
          ];
        };
      };

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-rfc-style;
    };
}
