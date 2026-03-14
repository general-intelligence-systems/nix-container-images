{ pkgs, inputs }:
let
  registry = "ghcr.io/general-intelligence-systems";
  baseImage = "nixos/nix:latest";
  imageName = "${registry}/nix-for-github-actions";
  imageTag = "latest";
in
pkgs.writeShellApplication {
  name = "build-nix-for-github-actions";
  runtimeInputs = [ pkgs.docker ];
  text = ''
    container=$(docker run -d "${baseImage}" sleep infinity)
    trap 'docker rm -f "$container" > /dev/null' EXIT

    docker exec "$container" nix profile install nixpkgs#ruby nixpkgs#xxd nixpkgs#crane

    docker commit "$container" "${imageName}:${imageTag}"
    echo "Built ${imageName}:${imageTag}"
  '';
}
