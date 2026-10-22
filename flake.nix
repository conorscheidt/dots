{
  description = "Conor's macOS environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    determinate = {
      url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Keep SpotX's tested Spotify/patcher pair together across updates.
    spotx-nix.url = "github:SpotX-Official/SpotX-Nix";
  };

  outputs = inputs @ {
    nixpkgs,
    nix-darwin,
    ...
  }: let
    system = "aarch64-darwin";
    pkgs = nixpkgs.legacyPackages.${system};
    viator = nix-darwin.lib.darwinSystem {
      specialArgs = {inherit inputs;};
      modules = [./hosts/viator];
    };
    nvim = viator.config.home-manager.users.${viator.config.system.primaryUser}.programs.nixvim.build;
  in {
    darwinConfigurations.viator = viator;

    packages.${system} = {
      default = viator.system;
      nvim = nvim.package;
      serato-dj-lite = viator.pkgs.callPackage ./pkgs/serato-dj-lite {};
    };

    checks.${system} = {
      nvim = nvim.test;
      source =
        pkgs.runCommand "source-checks" {
          src = ./.;
          nativeBuildInputs = with pkgs; [alejandra deadnix statix];
        } ''
          cd "$src"
          alejandra --check flake.nix hosts modules pkgs
          deadnix --fail .
          statix check .
          touch "$out"
        '';
    };

    formatter.${system} = pkgs.alejandra;

    devShells.${system}.default = pkgs.mkShellNoCC {
      packages = with pkgs; [alejandra deadnix statix nixd];
    };
  };
}
