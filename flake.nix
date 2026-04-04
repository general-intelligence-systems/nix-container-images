{
  description = "Container images built with Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11";
    claude-code.url = "github:general-intelligence-systems/claude-code-nix";
    opencode.url = "github:general-intelligence-systems/opencode-flake";
    nix4vscode = {
      url = "github:nix-community/nix4vscode";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    runner-images = {
      url = "github:actions/runner-images";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, nixpkgs-stable, ... }@inputs:
    let
      system   = "x86_64-linux";
      pkgs     = nixpkgs.legacyPackages.${system};
      lib      = pkgs.lib;
      org      = "general-intelligence-systems";
      registry = "ghcr.io/${org}";

      pkgs-stable = nixpkgs-stable.legacyPackages.${system};

      importFile = filename: import (./images + "/${filename}") {
        inherit pkgs pkgs-stable lib org registry inputs system;
      };

      imageDir       = builtins.readDir ./images;
      imageFilenames = builtins.attrNames imageDir;
      imageNames     = map (lib.removeSuffix ".nix") imageFilenames;
      imageFiles     = map importFile imageFilenames;

      imageConfigs = lib.listToAttrs (lib.zipListsWith lib.nameValuePair imageNames imageFiles);

      buildImage = _: config: pkgs.dockerTools.buildLayeredImage config;

      importRunner = filename: import (./runners + "/${filename}") {
        inherit pkgs inputs;
      };

      runnerDir       = builtins.readDir ./runners;
      runnerFilenames = builtins.filter (f: lib.hasSuffix ".nix" f) (builtins.attrNames runnerDir);
      runnerNames     = map (lib.removeSuffix ".nix") runnerFilenames;
      runnerPkgs      = map importRunner runnerFilenames;

      runners = lib.listToAttrs (lib.zipListsWith lib.nameValuePair runnerNames runnerPkgs);
    in
    {
      packages.${system} = lib.mapAttrs buildImage imageConfigs // runners;

      devShells.${system}.default = pkgs.mkShell {
        packages = [];
        shellHook = "";
      };
    };
}
