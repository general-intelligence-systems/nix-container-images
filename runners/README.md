# Nix for GitHub Actions

This is **not** a NixOS image. It is the native GitHub Actions runner
(`actions/runner-images` `ubuntu-slim`) with a few extra packages installed on
top, including Nix itself. This gives you a familiar Ubuntu-based CI
environment that can also run `nix build`, `nix flake check`, etc.

## Extra packages

The following packages are added to the base runner image:

| Package | Source |
|---------|--------|
| **nix** | Official installer (`nixos.org/nix/install`), single-user mode |
| **ruby** | `apt` |
| **xxd** | `apt` |
| **crane** | `go-containerregistry` (latest release from GitHub) |

## Usage in a GitHub Action

Reference the container image in your workflow job:

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/general-intelligence-systems/nix-for-github-actions:latest
    steps:
      - uses: actions/checkout@v4

      - name: Build with Nix
        run: nix build

      - name: Check flake
        run: nix flake check
```

Because the runner is still a standard Ubuntu environment, all regular GitHub
Actions (like `actions/checkout`) work as expected.
