{ pkgs, lib, org, registry, ... }:
{
  name = "${registry}/curl";

  tag = "latest";

  contents = with pkgs; [
    curl
    jq
    cacert
  ];
}
