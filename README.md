# Nix Container Images

Minimal, reproducible container images built with Nix and published to GitHub Container Registry.

## Images

| Image | Path | Contents |
|-------|------|----------|
| curl | `ghcr.io/general-intelligence-systems/curl:latest` | curl, jq, cacert |

## Usage

```sh
docker pull ghcr.io/general-intelligence-systems/curl:latest
```

```sh
docker run --rm ghcr.io/general-intelligence-systems/curl:latest curl -s https://example.com
```

## License

[Apache License 2.0](LICENSE)
