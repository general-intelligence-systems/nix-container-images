{ pkgs, inputs }:
let
  additions = pkgs.writeText "dockerfile-additions" ''
    RUN apt-get update && apt-get install -y --no-install-recommends ruby xxd && rm -rf /var/lib/apt/lists/*
    RUN sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --no-daemon
    RUN curl -sL "https://github.com/google/go-containerregistry/releases/latest/download/go-containerregistry_Linux_x86_64.tar.gz" | tar xz -C /usr/local/bin crane
  '';
in
pkgs.stdenv.mkDerivation {
  name = "nix-for-github-actions";
  src = inputs.runner-images;

  phases = [ "unpackPhase" "installPhase" ];

  installPhase = ''
    mkdir -p $out
    cp -r images/ubuntu-slim/* $out/
    sed -i "/^ENTRYPOINT/e cat ${additions}" $out/Dockerfile
  '';
}
