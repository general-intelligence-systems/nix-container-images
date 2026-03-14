# GitHub Actions Runners

Custom GitHub Actions container runners built in layers using `docker commit`.
These are **not** NixOS images. Each one starts from the native GitHub Actions
runner (`actions/runner-images` `ubuntu-slim`) and layers toolchains on top.
Because the base is the standard runner image, all regular GitHub Actions (like
`actions/checkout`) work as expected.

## Architecture

```
base-runner (Dockerfile build from actions/runner-images ubuntu-slim)
  └── nix-for-github-actions (docker commit: adds nix, ruby, xxd, crane)
        └── k3s-runner (docker commit: adds k3s via nix)
```

**base-runner** is the only image built from a Dockerfile. Every other runner
is created by starting a container from its parent image, installing packages
inside it, and committing the result. This avoids rebuilding from scratch and
makes it trivial to add new runners.

## Available Runners

### base-runner

The upstream `actions/runner-images` `ubuntu-slim` image, copied as-is. Includes
Node.js, Python, npm, pip, pipx, nvm, Git, Docker CLI, AWS/Azure/GCP CLIs, and
a full C/C++ build toolchain.

Build:

```sh
nix build .#base-runner
docker build -t ghcr.io/general-intelligence-systems/base-runner:latest result
```

### nix-for-github-actions

base-runner + Nix, Ruby, xxd, and crane. Installed via `docker commit`.

| Package | Source |
|---------|--------|
| **nix** | Official installer (`nixos.org/nix/install`), single-user mode |
| **ruby** | `apt` |
| **xxd** | `apt` |
| **crane** | `go-containerregistry` (latest release from GitHub) |

Build (requires `base-runner` image to exist):

```sh
nix run .#nix-for-github-actions
```

### k3s-runner

nix-for-github-actions + k3s. Installed via `nix profile install` inside the
container, then committed.

| Package | Source |
|---------|--------|
| **k3s** | `nixpkgs#k3s` (installed via nix) |

Build (requires `nix-for-github-actions` image to exist):

```sh
nix run .#k3s-runner
```

## Usage in a GitHub Action

Reference any runner as a container image in your workflow:

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/general-intelligence-systems/<runner-name>:latest
    steps:
      - uses: actions/checkout@v4
      - run: your-command-here
```

## Adding a New Runner

1. Create `runners/<name>-runner.nix`
2. Use `pkgs.writeShellApplication` to script the `docker run` / `docker exec` /
   `docker commit` workflow against the appropriate parent image
3. `git add` the file — the flake auto-discovers all `.nix` files in `runners/`
4. Build with `nix run .#<name>-runner`
