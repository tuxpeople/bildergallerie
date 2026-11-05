# Simple Flask image gallery for a mounted picture folder (/pictures)

# Build the virtualenv using Chainguard's Python dev image (pip, build tools)
# DL3007: Chainguard only publishes `latest` tags for free. The digest is
# pinned, so Renovate proposes base image updates as PRs that have to pass CI.
# hadolint ignore=DL3007
FROM cgr.dev/chainguard/python:latest-dev@sha256:29ab100be9f9be1ec5e31d7b7c384134171ee8f052e24e2285e697538c199aa6 AS build

# The venv lives in /opt/venv, not in /home/nonroot (mode 0700): Kubernetes
# may run the pod as a different UID (e.g. runAsUser: 65534), which must
# still be able to read it. A venv cannot be moved, so create it in place.
USER 0
RUN mkdir -p /opt/venv /pictures && chown nonroot:nonroot /opt/venv
USER nonroot

COPY requirements.txt /tmp/requirements.txt
RUN python -m venv /opt/venv && \
    /opt/venv/bin/pip install --disable-pip-version-check --no-cache-dir -r /tmp/requirements.txt && \
    # pip/setuptools are never used at runtime and would only add CVE findings
    /opt/venv/bin/pip uninstall --yes pip setuptools wheel

# Copy the virtualenv into the minimal distroless Chainguard Python runtime
# hadolint ignore=DL3007
FROM cgr.dev/chainguard/python:latest@sha256:31dd69d84fe5235fe18f8ceb5b76620e6f44a0ce1f9b0d3a46c491576f8b453b

# OCI Labels
LABEL org.opencontainers.image.title="bildergallerie"
LABEL org.opencontainers.image.description="Simple Flask image gallery for a mounted picture folder"
LABEL org.opencontainers.image.vendor="tuxpeople"
LABEL org.opencontainers.image.source="https://github.com/tuxpeople/bildergallerie"

COPY --from=build /opt/venv /opt/venv
# Empty mount point for the pictures (no mkdir in the distroless runtime)
COPY --from=build /pictures /pictures
# Application files stay owned by root: the app only reads them
COPY app.py /app/
COPY templates /app/templates

# PYTHONUNBUFFERED: log output straight to stdout/stderr
# PYTHONDONTWRITEBYTECODE: the root filesystem is read-only in Kubernetes
ENV PATH="/opt/venv/bin:$PATH" \
    VIRTUAL_ENV="/opt/venv" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    IMAGE_FOLDER=/pictures

# Chainguard's nonroot user
USER 65532
WORKDIR /app
EXPOSE 8080

# gunicorn instead of the Flask development server. With a read-only root
# filesystem the worker heartbeat goes to /dev/shm, and the control socket
# (not needed here) is disabled because it wants to write to $HOME.
ENTRYPOINT ["/opt/venv/bin/gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "--worker-tmp-dir", "/dev/shm", "--no-control-socket", "--access-logfile", "-", "app:app"]
