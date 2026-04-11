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

  # All container-wide CLI tools collected into a single derivation so
  # that we get one stable bin/ directory to put on PATH.  This avoids
  # relying on the /bin symlinks that buildLayeredImage creates (which
  # are invisible inside the FHS mount namespace that codium uses) and
  # the non-existent Nix profile directories.
  containerTools = pkgs.buildEnv {
    name = "container-tools";
    paths = with pkgs; [
      nix
      direnv
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
      docker-client

      # Languages
      ruby_3_4
      python3
      nodejs

      # TLS certs
      cacert

      # Locale & timezone
      tzdata
      glibcLocales
      gnutar
      gzip
    ];
    pathsToLink = [ "/bin" ];
  };

  # Terminal wrapper that undoes bubblewrap's glibc overlay.
  # buildFHSEnv/bubblewrap mounts a read-only tmpfs on glibc's etc/
  # (for ld.so.cache indirection), which prevents nix from substituting
  # packages that depend on that glibc path.  We create a new mount
  # namespace (via unshare, using the existing CAP_SYS_ADMIN) and
  # unmount the overlay so nix sees the real store.
  terminal-shell = pkgs.writeShellScriptBin "terminal-shell" ''
    exec ${pkgs.util-linux}/bin/unshare --mount ${pkgs.bash}/bin/bash -c '
      ${pkgs.util-linux}/bin/umount ${pkgs.glibc}/etc 2>/dev/null || true
      exec ${pkgs.zsh}/bin/zsh -l "$@"
    ' -- "$@"
  '';

  # Self-contained FHS-wrapped vscodium using the nixpkgs API.
  # fhsWithPackages bakes all dependencies into the derivation itself
  # so bubblewrap doesn't need to overlay on top of existing store paths.
  codium-fhs = pkgs.vscodium.fhsWithPackages (ps: with ps; [
    zlib
    openssl
    icu
    libsecret
    xorg.libX11
    xorg.libxcb
    containerTools
    tzdata
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

  contents = [
    # Editor (FHS-wrapped — only codium itself runs in the FHS namespace)
    codium-with-extensions

    # All CLI tools merged into a single derivation (containerTools) so
    # its bin/ directory can be placed on PATH and works both inside and
    # outside the FHS mount namespace.
    containerTools

    # Shell wrapper for the integrated terminal
    terminal-shell
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

    # Shell profile to ensure containerTools bin is on PATH for login shells
    # Note: buildFHSEnv already creates etc/profile.d/nix.sh (read-only),
    # so we use a different filename to avoid "Permission denied".
    mkdir -p ./etc/profile.d
    echo 'export PATH="${containerTools}/bin:$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH"' > ./etc/profile.d/nix-path.sh

    # Zoneinfo for processes outside the FHS namespace (e.g. Ruby tzinfo gem)
    mkdir -p ./usr/share
    ln -s ${pkgs.tzdata}/share/zoneinfo ./usr/share/zoneinfo

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
      "--server-data-dir" "/home/coder/.vscodium-server/user-data"
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
      "TZDIR=${pkgs.tzdata}/share/zoneinfo"
      "SHELL=${terminal-shell}/bin/terminal-shell"
      "EDITOR=codium --wait"
      "PATH=${containerTools}/bin:/home/coder/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/bin:/usr/bin"
    ];
  };
}
