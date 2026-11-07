# bildergallerie

Simple Flask image gallery for a mounted picture folder. Browses folders, shows thumbnails and a lightbox, sorts by name.

## Usage

```bash
docker run --rm -p 8080:8080 --read-only --tmpfs /dev/shm \
  -v /path/to/pictures:/pictures:ro \
  -e GALLERY_TITLE="My Gallery" \
  ghcr.io/tuxpeople/bildergallerie:latest
```

| Variable | Default | Description |
|---|---|---|
| `IMAGE_FOLDER` | `/pictures` | Folder with the pictures (mount it read-only) |
| `GALLERY_TITLE` | `Gallery` | Title shown in the page |

Only `.jpg`, `.jpeg`, `.png`, `.gif`, `.webp` and `.bmp` files are listed and served, and only from inside `IMAGE_FOLDER`.

### Kubernetes

The image works with a hardened pod spec:

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 65534          # any UID works, the app files are world-readable
  seccompProfile: { type: RuntimeDefault }
automountServiceAccountToken: false  # the app does not talk to the API
containers:
  - name: app
    image: ghcr.io/tuxpeople/bildergallerie:2
    securityContext:
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
      capabilities: { drop: ["ALL"] }
    volumeMounts:
      - { name: pictures, mountPath: /pictures, readOnly: true }
      - { name: shm, mountPath: /dev/shm }   # gunicorn worker heartbeat
volumes:
  - { name: shm, emptyDir: { medium: Memory } }
```

## Image

- Distroless Chainguard Python runtime, gunicorn, runs as non-root
- Multi-arch (`linux/amd64`, `linux/arm64`)
- Tags: `X.Y.Z`, `X.Y`, `X`, `latest`
- Signed with Cosign, signed SLSA provenance and SPDX SBOM as GitHub attestations

```bash
cosign verify \
  --certificate-identity-regexp '^https://github\.com/tuxpeople/shared/\.github/workflows/container-release\.yml@' \
  --certificate-github-workflow-repository tuxpeople/bildergallerie \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  ghcr.io/tuxpeople/bildergallerie:latest

gh attestation verify oci://ghcr.io/tuxpeople/bildergallerie:latest --owner tuxpeople
```

Images up to 2.0.0 were signed by the release workflow of this repository (`--certificate-identity "https://github.com/tuxpeople/bildergallerie/.github/workflows/release.yml@refs/heads/main"`).

## Development

```bash
python -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt -r requirements-dev.txt
ruff check . && ruff format --check . && pytest
IMAGE_FOLDER=/path/to/pictures python app.py   # http://127.0.0.1:8080
```

## Releases

[release-please](https://github.com/googleapis/release-please) maintains a release PR from the Conventional Commits on `main`. Merging it creates the tag and GitHub release and builds, signs and publishes the image.

## History

Until 2.0.0 the image was built in [tuxpeople/containers](https://github.com/tuxpeople/containers) (tags `1.0.x`, `d2025…`). Those versions are affected by a path traversal and an enabled Werkzeug debugger; use 2.0.0 or later.
