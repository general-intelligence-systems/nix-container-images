{ pkgs, inputs }:
let
  dockerfile = pkgs.writeText "Dockerfile" ''
    FROM ghcr.io/actions/actions-runner:latest
    USER root
    RUN mkdir -p /nix && chown runner:runner /nix
    USER runner
    RUN curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install | sh -s -- --no-daemon
    ENV PATH="/home/runner/.nix-profile/bin:''${PATH}"
    RUN . /home/runner/.nix-profile/etc/profile.d/nix.sh && nix profile install nixpkgs#ruby nixpkgs#xxd nixpkgs#crane
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
