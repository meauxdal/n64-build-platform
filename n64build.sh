#!/usr/bin/env bash
# =============================================================================
# n64build.sh — Local N64 build helper
#
# Wraps Docker so community members can build without installing anything
# beyond Docker itself. The image is pulled from GHCR if not present locally.
#
# Usage:
#   ./n64build.sh               — build the project in the current directory
#   ./n64build.sh make clean    — run any make target
#   ./n64build.sh shell         — drop into an interactive shell in the image
#   ./n64build.sh tiny3d        — build all Tiny3D examples (outputs to ./tiny3d-examples/)
#   ./n64build.sh build-image   — build the Docker image locally from the Dockerfile
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration — edit IMAGE to point at your published image if you have one,
# or leave as-is and run `./n64build.sh build-image` to build it locally.
# ---------------------------------------------------------------------------
IMAGE="${N64_DEV_IMAGE:-ghcr.io/YOUR_GITHUB_USERNAME/n64-dev:latest}"
LOCAL_IMAGE="n64-dev:local"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
need_docker() {
    if ! command -v docker &>/dev/null; then
        echo "Error: Docker is not installed or not on PATH." >&2
        echo "Install Docker Desktop: https://docs.docker.com/get-docker/" >&2
        exit 1
    fi
}

# Run a command inside the toolchain container, mounting the current directory.
docker_run() {
    local img="${1}"; shift
    docker run --rm \
        -v "$(pwd):/project" \
        -w /project \
        -e N64_INST=/n64_toolchain \
        "${img}" "$@"
}

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------
cmd="${1:-make}"

case "${cmd}" in

    build-image)
        # Build the image locally from the Dockerfile in this directory.
        echo "Building n64-dev image locally (this takes ~5-10 minutes the first time)..."
        docker build -t "${LOCAL_IMAGE}" .
        echo ""
        echo "Done. Use the local image with:"
        echo "  N64_DEV_IMAGE=${LOCAL_IMAGE} ./n64build.sh"
        ;;

    shell)
        need_docker
        echo "Opening shell in n64-dev container (project mounted at /project)..."
        docker_run "${IMAGE}" bash
        ;;

    tiny3d)
        # Build all Tiny3D examples and copy the .z64 files locally.
        need_docker
        echo "Building all Tiny3D examples..."
        docker run --rm \
            -v "$(pwd)/tiny3d-examples:/out" \
            -e N64_INST=/n64_toolchain \
            "${IMAGE}" bash -c '
                set -e
                git clone --depth 1 https://github.com/HailToDodongo/tiny3d.git /tmp/tiny3d
                cd /tmp/tiny3d
                N64_INST=/n64_toolchain ./build.sh
                find examples -name "*.z64" -exec cp {} /out/ \;
                echo "Copied $(find /out -name "*.z64" | wc -l) example ROMs to /out"
            '
        echo ""
        echo "Example ROMs saved to: $(pwd)/tiny3d-examples/"
        ls -lh tiny3d-examples/*.z64 2>/dev/null || true
        ;;

    make|*)
        # Default: run make (or any other command) in the project directory.
        need_docker
        docker_run "${IMAGE}" "${cmd}" "${@:2}"
        ;;

esac
