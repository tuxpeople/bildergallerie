# CLAUDE.md

Small Flask image gallery (`app.py`, `templates/gallery.html`), packaged as a distroless Chainguard image with gunicorn.

## Commands

```bash
pip install -r requirements.txt -r requirements-dev.txt
ruff check . && ruff format --check . && pytest
docker build -t bildergallerie:test .
```

## Rules

- **Security first:** all file access goes through `safe_join` / `send_from_directory` and stays inside `IMAGE_FOLDER`. Never enable Flask debug. `tests/test_app.py` has regression tests for both; keep them passing and extend them for new routes.
- **Ruff S rules** (flake8-bandit) are enabled on purpose; fix findings instead of ignoring them.
- **Image:** the venv lives in `/opt/venv` (readable by any UID); the root filesystem is read-only in Kubernetes, gunicorn uses `/dev/shm`.
- **Commits:** Conventional Commits; they drive release-please (`feat` → minor, `fix` → patch, `!` → major).
- **Actions** are pinned by commit SHA (`@<sha> # vX.Y.Z`); Renovate keeps them up to date.
