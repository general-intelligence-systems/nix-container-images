{
  description = "Container images built with Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    claude-code.url = "github:general-intelligence-systems/claude-code-nix";
    opencode.url = "github:general-intelligence-systems/opencode-flake";
    runner-images = {
      url = "github:actions/runner-images";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      system   = "x86_64-linux";
      pkgs     = nixpkgs.legacyPackages.${system};
      lib      = pkgs.lib;
      org      = "general-intelligence-systems";
      registry = "ghcr.io/${org}";

      importFile = filename: import (./images + "/${filename}") {
        inherit pkgs lib org registry inputs system;
      };

      imageDir       = builtins.readDir ./images;
      imageFilenames = builtins.attrNames imageDir;
      imageNames     = map (lib.removeSuffix ".nix") imageFilenames;
      imageFiles     = map importFile imageFilenames;

      imageConfigs = lib.listToAttrs (lib.zipListsWith lib.nameValuePair imageNames imageFiles);

      buildImage = _: config: pkgs.dockerTools.buildLayeredImage config;

      nix-for-github-actions = import ./runners/nix-for-github-actions.nix { inherit pkgs inputs; };
    in
    {
      packages.${system} = lib.mapAttrs buildImage imageConfigs // {
        inherit nix-for-github-actions;
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = [];
        shellHook = "";
      };
    };
}
