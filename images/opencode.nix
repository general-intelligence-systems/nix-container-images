{ pkgs, lib, org, registry, inputs, system, ... }:
let
  opencode = inputs.opencode.packages.${system}.default;
in
{
  name = "${registry}/opencode";

  tag = "latest";

  contents = with pkgs; [
    opencode
    cacert
    git
  ];
}
