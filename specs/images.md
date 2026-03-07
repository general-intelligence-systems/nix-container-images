# Adding a New Container Image

This spec describes how to add a new container image to the repository.

## Overview

Each container image is defined by a single `.nix` file in the `images/` directory. The Nix flake auto-discovers every `.nix` file in that directory, builds it with `pkgs.dockerTools.buildLayeredImage`, and exposes it as a flake package. CI automatically builds and pushes changed images to GHCR on merge to `trench`.

No registration step is required — drop a file in `images/` and the rest is automatic.

## Step-by-step

### 1. Create the image definition

Create `images/<name>.nix` where `<name>` is the image name (lowercase, hyphens OK). The filename minus `.nix` becomes:

- The Nix package name (`nix build .#<name>`)
- The Docker image name (`ghcr.io/general-intelligence-systems/<name>`)

The file must be a Nix function with this signature:

```nix
{ pkgs, lib, org, registry, ... }:
{
  name = "${registry}/<name>";
  tag = "latest";
  contents = [
    # Nix packages to include in the image
  ];
}
```

The trailing `...` is required so the function accepts additional arguments passed by the flake (such as `inputs` and `system`). Explicitly bind any extras you need (see [Using external flake inputs](#using-external-flake-inputs) below).

#### Required attributes

| Attribute  | Type       | Description |
|------------|------------|-------------|
| `name`     | string     | Full registry path. Use `"${registry}/<name>"` to stay consistent. |
| `tag`      | string     | Image tag. Use `"latest"`. |
| `contents` | list       | Nix packages to include in the image filesystem. |

#### Function arguments

| Argument   | Value | Description |
|------------|-------|-------------|
| `pkgs`     | nixpkgs package set | Use to reference packages (e.g. `pkgs.curl`, `pkgs.python3`). |
| `lib`      | nixpkgs lib | Nix utility functions. |
| `org`      | `"general-intelligence-systems"` | GitHub org name. |
| `registry` | `"ghcr.io/general-intelligence-systems"` | Full registry prefix. |
| `inputs`   | flake inputs attrset | All flake inputs (e.g. `inputs.nixpkgs`, `inputs.claude-code`). Bind explicitly when needed. |
| `system`   | `"x86_64-linux"` | Current system platform. Useful with `inputs.<name>.packages.${system}`. |

### 2. Stage the file with git

```sh
git add images/<name>.nix
```

Nix flakes only see files tracked by git. If you skip this step, `nix build`, `nix flake check`, and `nix flake show` will silently ignore the new image.

### 3. Build locally

```sh
nix build .#<name>
```

This produces a `result` symlink pointing to a Docker-loadable tarball.

### 4. Test locally

```sh
docker load < result
docker run --rm ghcr.io/general-intelligence-systems/<name>:latest <command>
```

Verify the image contains the expected tools and behaves correctly.

### 5. Validate the flake

```sh
bin/test
```

This runs `nix flake check` to ensure the flake evaluates without errors. See [testing.md](./testing.md) for details.

### 6. Update the spec index

If you added or changed any specs, add a row to [specs/README.md](./README.md) so the index stays current.

### 7. Commit and push

Commit the new `images/<name>.nix` file and push to `trench`. CI will automatically build and push the image to GHCR.

If `flake.nix` or `flake.lock` were also modified, CI rebuilds all images (not just the new one).

## Example

Adding a `redis` image:

```nix
# images/redis.nix
{ pkgs, lib, org, registry, ... }:
{
  name = "${registry}/redis";
  tag = "latest";
  contents = [
    pkgs.redis
    pkgs.cacert
  ];
}
```

```sh
nix build .#redis
docker load < result
docker run --rm ghcr.io/general-intelligence-systems/redis:latest redis-server --version
```

## Using external flake inputs

If the image needs a package from an external flake (not in nixpkgs), follow these steps:

1. Add the flake input to `flake.nix` under `inputs`.
2. In the image file, bind `inputs` and `system` in the function arguments and use a `let..in` block to extract the package.

Example — an image using a package from the `claude-code-nix` flake:

```nix
# images/claude-code.nix
{ pkgs, lib, org, registry, inputs, system, ... }:
let
  claude-code = inputs.claude-code.packages.${system}.default;
in
{
  name = "${registry}/claude-code";
  tag = "latest";
  contents = [
    claude-code
    pkgs.cacert
    pkgs.git
  ];
}
```

After adding or changing a flake input, run `nix flake lock` to update `flake.lock`.

## Advanced options

The attribute set returned by the image function is passed directly to `pkgs.dockerTools.buildLayeredImage`. Any option it supports can be used. Common ones:

### `config`

Set the image's OCI config (entrypoint, env vars, working directory, exposed ports):

```nix
{ pkgs, lib, org, registry }:
{
  name = "${registry}/my-app";
  tag = "latest";
  contents = [ pkgs.my-app pkgs.cacert ];

  config = {
    Cmd = [ "/bin/my-app" "--flag" ];
    Env = [
      "APP_ENV=production"
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    ];
    WorkingDir = "/app";
    ExposedPorts = {
      "8080/tcp" = {};
    };
  };
}
```

### `extraCommands`

Run shell commands during the build to modify the image filesystem. Runs as the build user (not root) in a temp directory containing the image contents:

```nix
{ pkgs, lib, org, registry }:
{
  name = "${registry}/my-app";
  tag = "latest";
  contents = [ pkgs.busybox ];

  extraCommands = ''
    mkdir -p data
    echo "default config" > etc/app.conf
  '';
}
```

Note: paths are relative to the image root (no leading `/`).

### `fakeRootCommands`

Like `extraCommands` but runs inside a fakeroot environment, allowing operations that require root-like permissions (e.g. `chown`):

```nix
{ pkgs, lib, org, registry }:
{
  name = "${registry}/my-app";
  tag = "latest";
  contents = [ pkgs.busybox ];

  fakeRootCommands = ''
    mkdir -p ./data
    chown 1000:1000 ./data
  '';
}
```

### `maxLayers`

Control the maximum number of Docker layers (default 100). More layers improve cache reuse for incremental pulls:

```nix
{
  maxLayers = 120;
}
```

### `enableFakechroot`

Set to `true` to enable fakechroot inside `fakeRootCommands`, making absolute paths like `/etc` resolve correctly:

```nix
{
  enableFakechroot = true;
  fakeRootCommands = ''
    mkdir -p /etc/myapp
  '';
}
```

## Reference

- [`pkgs.dockerTools.buildLayeredImage`](https://nixos.org/manual/nixpkgs/stable/#ssec-pkgs-dockerTools-buildLayeredImage) — full list of supported attributes.
- Existing images in `images/` — working examples.
- `flake.nix` — auto-discovery and build logic.
