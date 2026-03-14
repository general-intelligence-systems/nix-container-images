{ pkgs, inputs }:
pkgs.stdenv.mkDerivation {
  name = "base-runner";
  src = inputs.runner-images;

  phases = [ "unpackPhase" "installPhase" ];

  installPhase = ''
    mkdir -p $out
    cp -r images/ubuntu-slim/* $out/
  '';
}
