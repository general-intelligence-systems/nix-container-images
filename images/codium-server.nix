{ pkgs, lib, org, registry, inputs, system, ... }:
let
  nix4vscode = inputs.nix4vscode.overlays.default;

  pkgsWithOverlay = import inputs.nixpkgs {
    inherit system;
    config.allowUnfree = true;
    overlays = [ nix4vscode ];
  };

  extensions = pkgsWithOverlay.nix4vscode.forOpenVsx [
    "jnoortheen.nix-ide"
    "vscodevim.vim"
    "editorconfig.editorconfig"
  ];

  # Use vscodium.fhs — launches inside FHS compliant environment
  # so serve-web prereq checks find libstdc++.so and ldconfig,
  # and extension binaries with pre-compiled libs just work.
  codium-fhs = pkgs.vscodium.fhsWithPackages (ps: with ps; [
    # Dev tools available inside the FHS environment
    nix
    git
    curl
    wget
    openssh
    jq
    nodejs
    bashInteractive
    coreutils
    findutils
    gnugrep
    gnused
    gawk
    less
    which
    procps
    sudo
    gnutar
    gzip

    # Libraries for extensions
    zlib
    openssl
    icu
    libsecret
    xorg.libX11
    xorg.libxcb
  ]);

  codium-with-extensions = pkgs.vscode-with-extensions.override {
    vscode = codium-fhs;
    vscodeExtensions = extensions;
  };
in
{
  name = "${registry}/codium-server";
  tag = "latest";
  maxLayers = 120;

  contents = with pkgs; [
    # Editor (FHS-wrapped)
    codium-with-extensions

    dumb-init
    bashInteractive
    coreutils
    findutils
    gnugrep
    gnused
    gawk
    less
    which
    procps
    sudo
    git
    curl
    wget
    openssh
    jq
    nodejs
    cacert
    glibcLocales
  ];

  fakeRootCommands = ''
    mkdir -p ./etc
    echo 'root:x:0:0:root:/root:/bin/bash' > ./etc/passwd
    echo 'coder:x:1000:1000:coder:/home/coder:/bin/bash' >> ./etc/passwd
    echo 'root:x:0:' > ./etc/group
    echo 'coder:x:1000:' >> ./etc/group
    echo 'root:!:1::::::' > ./etc/shadow
    echo 'coder:!:1::::::' >> ./etc/shadow

    mkdir -p ./etc/sudoers.d
    echo 'coder ALL=(ALL) NOPASSWD:ALL' > ./etc/sudoers.d/coder
    chmod 440 ./etc/sudoers.d/coder

    mkdir -p ./home/coder
    chown 1000:1000 ./home/coder

    # Shell profile to include nix profile in PATH
    mkdir -p ./etc/profile.d
    echo 'export PATH="$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH"' > ./etc/profile.d/nix.sh

    mkdir -p ./tmp
    chmod 1777 ./tmp
    mkdir -p ./run

    # Nix config
    mkdir -p ./etc/nix
    echo 'experimental-features = nix-command flakes' > ./etc/nix/nix.conf
    echo 'sandbox = false' >> ./etc/nix/nix.conf

    echo 'hosts: files dns' > ./etc/nsswitch.conf
  '';

  config = {
    Cmd = [
      "${pkgs.dumb-init}/bin/dumb-init"
      "${codium-with-extensions}/bin/codium"
      "serve-web"
      "--host" "0.0.0.0"
      "--port" "8080"
      "--without-connection-token"
    ];
    ExposedPorts = { "8080/tcp" = {}; };
    User = "1000:1000";
    WorkingDir = "/home/coder";
    Env = [
      "HOME=/home/coder"
      "USER=coder"
      "LANG=en_US.UTF-8"
      "LOCALE_ARCHIVE=${pkgs.glibcLocales}/lib/locale/locale-archive"
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "NIX_SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "EDITOR=codium --wait"
      "PATH=/home/coder/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/bin:/usr/bin"
    ];
  };
}
