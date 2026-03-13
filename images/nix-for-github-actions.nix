{ pkgs, lib, org, registry, ... }:
{
  name = "${registry}/nix-for-github-actions";

  tag = "latest";

  contents = with pkgs; [
    bash
    coreutils
    gnugrep
    gawk
    findutils
    curl
    yq-go
    jq
    crane
    unixtools.xxd
    git
    cacert
    nodejs
    python3
    ruby
    glibc
    stdenv.cc.cc.lib
    nix
  ];

  extraCommands = ''
    mkdir -p usr/bin
    ln -s ../../bin/env usr/bin/env
  '';

  config = {
    Env = [
      "LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib"
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "NIX_CONFIG=experimental-features = nix-command flakes"
    ];
  };
}
