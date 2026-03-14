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
