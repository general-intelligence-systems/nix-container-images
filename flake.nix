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

    in
    {
      packages.${system} = lib.mapAttrs buildImage imageConfigs // {
        runner-images-ubuntu-slim = pkgs.stdenv.mkDerivation {
          name = "runner-images-ubuntu-slim";
          src = inputs.runner-images;

          phases = [ "unpackPhase" "installPhase" ];

          installPhase = let
            additions = pkgs.writeText "dockerfile-additions" ''
              RUN apt-get update && apt-get install -y --no-install-recommends ruby xxd && rm -rf /var/lib/apt/lists/*
              RUN sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --daemon
              RUN curl -sL "https://github.com/google/go-containerregistry/releases/latest/download/go-containerregistry_Linux_x86_64.tar.gz" | tar xz -C /usr/local/bin crane
            '';
          in ''
            mkdir -p $out
            cp -r images/ubuntu-slim/* $out/
            sed -i "/^ENTRYPOINT/e cat ${additions}" $out/Dockerfile
          '';
        };
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = [];
        shellHook = "";
      };
    };
}
