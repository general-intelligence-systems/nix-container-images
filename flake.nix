{
  description = "Container images built with Nix";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      system   = "x86_64-linux";
      pkgs     = nixpkgs.legacyPackages.${system};
      lib      = pkgs.lib;
      org      = "general-intelligence-systems";
      registry = "ghcr.io/${org}";

      importFile = filename: import (./images + "/${filename}") { inherit pkgs lib org; };

      imageDir       = builtins.readDir ./images;
      imageFilenames = builtins.attrNames imageDir;
      imageNames     = map (lib.removeSuffix ".nix") imageFilenames;
      imageFiles     = map importFile imageFilenames;

      imageConfigs = lib.listToAttrs (lib.zipListsWith lib.nameValuePair imageNames imageFiles);

      buildImage = _: config: pkgs.dockerTools.buildLayeredImage config;
    in
    {
      packages.${system} = lib.mapAttrs buildImage imageConfigs;

      devShells.${system}.default = pkgs.mkShell {
        packages = [];
        shellHook = "";
      };
    };
}
