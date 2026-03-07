# Testing

## `bin/test`

Runs `nix flake check`, which evaluates every package and devShell defined by the flake and verifies they produce valid derivations. This catches syntax errors, missing attributes, and broken references without performing a full build.

```sh
bin/test
```

## git add before testing

Nix flakes only evaluate files tracked by git. If you create a new image file and forget to `git add` it, the flake will silently ignore it — `bin/test`, `nix build`, and `nix flake show` will all act as if the file does not exist.

Always stage new files before running any Nix command:

```sh
git add images/<name>.nix
bin/test
```
