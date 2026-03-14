{ pkgs, inputs }:
let
  registry = "ghcr.io/general-intelligence-systems";
  baseImage = "${registry}/base-runner:latest";
  imageName = "${registry}/nix-for-github-actions";
  imageTag = "latest";
in
pkgs.writeShellApplication {
  name = "build-nix-for-github-actions";
  runtimeInputs = [ pkgs.docker ];
  text = ''
    container=$(docker run -d "${baseImage}" sleep infinity)
    trap 'docker rm -f "$container" > /dev/null' EXIT

    docker exec "$container" bash -c 'apt-get update && apt-get install -y --no-install-recommends ruby xxd && rm -rf /var/lib/apt/lists/*'
    docker exec "$container" bash -c 'curl --proto "=https" --tlsv1.2 -L https://nixos.org/nix/install | sh -s -- --daemon'
    docker exec "$container" bash -c 'mkdir -p /etc/nix && echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf'
    docker exec "$container" bash -c 'curl -sL "https://github.com/google/go-containerregistry/releases/latest/download/go-containerregistry_Linux_x86_64.tar.gz" | tar xz -C /usr/local/bin crane'

    docker commit "$container" "${imageName}:${imageTag}"
    echo "Built ${imageName}:${imageTag}"
  '';
}
