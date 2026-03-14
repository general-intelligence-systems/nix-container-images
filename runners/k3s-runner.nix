{ pkgs, inputs }:
let
  registry = "ghcr.io/general-intelligence-systems";
  baseImage = "${registry}/nix-for-github-actions:latest";
  imageName = "${registry}/k3s-runner";
  imageTag = "latest";
in
pkgs.writeShellApplication {
  name = "build-k3s-runner";
  runtimeInputs = [ pkgs.docker ];
  text = ''
    container=$(docker run -d "${baseImage}" sleep infinity)
    trap 'docker rm -f "$container" > /dev/null' EXIT

    docker exec "$container" bash -lc 'nix profile install nixpkgs#k3s'

    docker commit "$container" "${imageName}:${imageTag}"
    echo "Built ${imageName}:${imageTag}"
  '';
}
