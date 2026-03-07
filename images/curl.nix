{ pkgs, lib, org }:
{
  name = "${org}/curl";

  tag = "latest";

  contents = [
    pkgs.curl
    pkgs.jq
    pkgs.cacert
  ];
}
