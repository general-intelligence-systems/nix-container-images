{ pkgs, pkgs-stable, lib, org, registry, inputs, system, ... }:
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

  # Libraries that extension binaries need at runtime.
  # These are made available to codium via a scoped FHS wrapper so that
  # the FHS mount namespace only applies to the codium process — not to
  # the container-wide shell, direnv, or nix.  This prevents the FHS
  # env from placing read-only bind mounts inside /nix/store (on glibc's
  # etc/ dir) which block nix substitution and corrupt the store.
  fhsLibs = ps: with ps; [
    zlib
    openssl
    icu
    libsecret
    xorg.libX11
    xorg.libxcb
  ];

  # Scoped FHS wrapper: only the codium binary runs inside the FHS
  # namespace.  Everything else (bash, nix, direnv) stays outside it.
  codium-fhs = (pkgs.buildFHSEnv {
    name = "codium";
    targetPkgs = fhsLibs;
    runScript = "${pkgs.vscodium}/bin/codium";
  }).overrideAttrs (_: {
    # vscode-with-extensions expects these attributes on the vscode package
    inherit (pkgs.vscodium) pname version;
    passthru = (pkgs.vscodium.passthru or {}) // {
      inherit (pkgs.vscodium) executableName longName;
    };
  });

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
    # Editor (FHS-wrapped — only codium itself runs in the FHS namespace)
    codium-with-extensions

    # Container-wide tools — these run OUTSIDE the FHS namespace so
    # they never see read-only bind mounts on /nix/store paths.
    nix
    direnv

    # Init
    dumb-init

    # Shell essentials
    bashInteractive
    zsh
    coreutils
    findutils
    gnugrep
    gnused
    gawk
    less
    which
    procps
    sudo

    # Dev tools
    git
    curl
    wget
    openssh
    jq
    yq-go
    ripgrep
    repgrep
    gh
    kubectl
    tea
    vcluster
    pkgs-stable.opencode
    keychain
    zoxide
    fzf
    vim
    docker-compose

    # Languages
    ruby_3_4
    python3
    nodejs

    # TLS certs
    cacert

    # Locale
    glibcLocales
    gnutar
    gzip
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
    # Note: buildFHSEnv already creates etc/profile.d/nix.sh (read-only),
    # so we use a different filename to avoid "Permission denied".
    mkdir -p ./etc/profile.d
    echo 'export PATH="$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH"' > ./etc/profile.d/nix-path.sh

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
