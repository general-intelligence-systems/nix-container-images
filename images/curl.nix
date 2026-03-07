{ pkgs, lib, org, registry }:
{
  name = "${registry}/curl";

  tag = "latest";


  contents = [
    pkgs.curl
    pkgs.jq
    pkgs.cacert
  ];
}
