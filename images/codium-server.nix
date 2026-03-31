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

  codium-with-extensions = pkgs.vscode-with-extensions.override {
    vscode = pkgs.vscodium;
    vscodeExtensions = extensions;
  };

  # Libraries that unpatched binaries (extensions, serve-web prereqs) need
  nixLdLibraryPath = lib.makeLibraryPath (with pkgs; [
    stdenv.cc.cc.lib
    zlib
    openssl
    icu
    libsecret
    xorg.libX11
    xorg.libxcb
  ]);
in
{
  name = "${registry}/codium-server";
  tag = "latest";
  maxLayers = 120;

  contents = with pkgs; [
    codium-with-extensions

    # nix-ld — shim for unpatched dynamic binaries
    nix-ld

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

    mkdir -p ./tmp
    chmod 1777 ./tmp
    mkdir -p ./run

    # nix-ld: symlink the shim as the dynamic linker
    mkdir -p ./lib64
    ln -sf ${pkgs.nix-ld}/libexec/nix-ld/ld-linux-x86-64.so.2 ./lib64/ld-linux-x86-64.so.2

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
      "NIX_LD=${pkgs.stdenv.cc.libc}/lib/ld-linux-x86-64.so.2"
      "NIX_LD_LIBRARY_PATH=${nixLdLibraryPath}"
    ];
  };
}
