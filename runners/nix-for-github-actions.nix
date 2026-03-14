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

    # Symlink nix binaries to /usr/local/bin so they're on PATH even when
    # GitHub Actions overrides the container's PATH in non-login shells.
    docker exec "$container" bash -c 'ln -sf /nix/var/nix/profiles/default/bin/* /usr/local/bin/'

    docker commit "$container" "${imageName}:${imageTag}"
    echo "Built ${imageName}:${imageTag}"
  '';
}
