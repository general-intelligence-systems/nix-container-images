{ pkgs, lib, org, registry, ... }:
{
  name = "${registry}/runs-on-github";
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

    # Node.js (needed by Forgejo/GitHub checkout action)
    nodejs
  ];

  fakeRootCommands = ''
    mkdir -p ./etc
    echo 'root:x:0:0:root:/root:/bin/bash' > ./etc/passwd
    echo 'runner:x:1001:1001:runner:/home/runner:/bin/bash' >> ./etc/passwd
    echo 'nobody:x:65534:65534:nobody:/nonexistent:/bin/false' >> ./etc/passwd
    echo 'root:x:0:' > ./etc/group
    echo 'runner:x:1001:' >> ./etc/group
    echo 'nobody:x:65534:' >> ./etc/group
    echo 'root:!:1::::::' > ./etc/shadow
    echo 'runner:!:1::::::' >> ./etc/shadow

    mkdir -p ./root
    mkdir -p ./home/runner
    chown 1001:1001 ./home/runner
    mkdir -p ./tmp
    chmod 1777 ./tmp
    mkdir -p ./run

    mkdir -p ./etc/nix
    echo 'build-users-group =' > ./etc/nix/nix.conf
    echo 'experimental-features = nix-command flakes' >> ./etc/nix/nix.conf
    echo 'sandbox = false' >> ./etc/nix/nix.conf
    echo 'filter-syscalls = false' >> ./etc/nix/nix.conf

    echo 'hosts: files dns' > ./etc/nsswitch.conf

    # FHS compat: dynamic linker symlink
    mkdir -p ./lib64
    ln -sf ${pkgs.glibc}/lib/ld-linux-x86-64.so.2 ./lib64/ld-linux-x86-64.so.2

    # FHS compat: library symlinks for GitHub Actions injected binaries
    mkdir -p ./lib/x86_64-linux-gnu
    for f in ${pkgs.glibc}/lib/*.so*; do
      [ -f "$f" ] && ln -sf "$f" ./lib/x86_64-linux-gnu/$(basename "$f") || true
    done
    for f in ${pkgs.stdenv.cc.cc.lib}/lib/*.so*; do
      [ -f "$f" ] && ln -sf "$f" ./lib/x86_64-linux-gnu/$(basename "$f") || true
    done
  '';

  config = {
    Env = [
      "HOME=/root"
      "USER=root"
      "LD_LIBRARY_PATH=/lib/x86_64-linux-gnu"
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "NIX_SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "GIT_SSL_CAINFO=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    ];
    WorkingDir = "/root";
  };
}
