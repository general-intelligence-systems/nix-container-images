{ pkgs, inputs }:
let
  dockerfile = pkgs.writeText "Dockerfile" ''
    FROM ghcr.io/actions/actions-runner:latest
    USER root
    RUN apt-get update && apt-get install -y --no-install-recommends xz-utils && rm -rf /var/lib/apt/lists/*
    RUN mkdir -p /nix && chown runner:runner /nix
    USER runner
    RUN curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install | sh -s -- --no-daemon
    ENV PATH="/home/runner/.nix-profile/bin:''${PATH}"
    RUN mkdir -p /home/runner/.config/nix && echo "experimental-features = nix-command flakes" > /home/runner/.config/nix/nix.conf
    RUN nix profile install nixpkgs#ruby nixpkgs#xxd nixpkgs#crane
  '';
in
pkgs.stdenv.mkDerivation {
  name = "nix-for-github-actions";
  dontUnpack = true;

  installPhase = ''
    mkdir -p $out
    cp ${dockerfile} $out/Dockerfile
  '';
}
