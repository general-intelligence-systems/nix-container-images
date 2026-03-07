{ pkgs, lib, org, registry, inputs, system, ... }:
let
  claude-code = inputs.claude-code.packages.${system}.default;
in
{
  name = "${registry}/claude-code";

  tag = "latest";

  contents = [
    claude-code
    pkgs.cacert
    pkgs.git
  ];
}
