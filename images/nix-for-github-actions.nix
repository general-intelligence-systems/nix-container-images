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
  ];

  config = {
    Env = [
      "LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib"
    ];
  };
}
