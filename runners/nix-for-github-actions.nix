{ pkgs, inputs }:
let
  dockerfile = pkgs.writeText "Dockerfile" ''
    FROM ghcr.io/actions/actions-runner:latest
    USER root
    RUN curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install linux --init none --no-confirm
    ENV PATH="/nix/var/nix/profiles/default/bin:''${PATH}"
    RUN nix-daemon & sleep 1 && nix profile install nixpkgs#ruby nixpkgs#xxd nixpkgs#crane
    USER runner
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
