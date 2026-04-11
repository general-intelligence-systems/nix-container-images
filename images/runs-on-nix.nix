{ pkgs, lib, org, registry, ... }:
{
  name = "${registry}/runs-on-nix";
  tag = "latest";
  maxLayers = 80;

  contents = with pkgs; [
    # Nix
    nix

    # Shell
    bashInteractive
    coreutils
    findutils
    gnugrep
    gnused
    gawk
    less
    which
    procps

    # Git
    git

    # Networking
    curl
    wget
    cacert

    # Docker CLI
    docker-client

    # Build tools
    gnutar
    gzip
    xz
    gnumake
    jq

    # Node.js
    nodejs
  ];

  fakeRootCommands = ''
    mkdir -p ./etc
    echo 'root:x:0:0:root:/root:/bin/bash' > ./etc/passwd
    echo 'nobody:x:65534:65534:nobody:/nonexistent:/bin/false' >> ./etc/passwd
    echo 'root:x:0:' > ./etc/group
    echo 'nobody:x:65534:' >> ./etc/group
    echo 'root:!:1::::::' > ./etc/shadow

    mkdir -p ./root
    mkdir -p ./tmp
    chmod 1777 ./tmp
    mkdir -p ./run

    mkdir -p ./etc/nix
    echo 'build-users-group =' > ./etc/nix/nix.conf
    echo 'experimental-features = nix-command flakes' >> ./etc/nix/nix.conf
    echo 'sandbox = false' >> ./etc/nix/nix.conf
    echo 'filter-syscalls = false' >> ./etc/nix/nix.conf
    echo 'system-features = kvm' >> ./etc/nix/nix.conf

    echo 'hosts: files dns' > ./etc/nsswitch.conf
  '';

  config = {
    Env = [
      "HOME=/root"
      "USER=root"
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "NIX_SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "GIT_SSL_CAINFO=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    ];
    WorkingDir = "/root";
  };
}
