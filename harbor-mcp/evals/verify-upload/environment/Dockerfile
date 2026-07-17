# Agent container for the verify-upload eval.
#
# python:3.12-slim satisfies harbor-mcp's Python >= 3.12 requirement and pip
# installs into the image without an externally-managed-environment block.
# curl and ca-certificates are needed by harbor's agent installers (e.g. the
# claude-code setup script); git is needed for the pip git+https install.
FROM python:3.12-slim-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install harbor-mcp so the stdio command declared in task.toml
# ([[environment.mcp_servers]] command = "harbor-mcp") resolves on PATH.
#
# Secrets are NOT baked into this image: HARBOR_API_KEY and
# HARBOR_MCP_ENABLE_WRITES arrive at runtime via `harbor run --ae`.
#
# Local-development alternative (build against your working copy instead of
# the GitHub default branch):
#   COPY . /opt/harbor-mcp
#   RUN pip install --no-cache-dir /opt/harbor-mcp
RUN pip install --no-cache-dir "harbor-mcp @ git+https://github.com/walkerhughes/harbor-mcp.git"

WORKDIR /app
