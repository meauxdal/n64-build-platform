# ============================================================================
# N64 Development Toolchain Image
# Base: libdragon toolchain (MIPS GCC) from DragonMinded
# Layer 1: libdragon C library — preview branch (required by Tiny3D)
# Layer 2: Tiny3D library + tools
#
# Build:
#   docker build -t n64-dev .
#
# Use (build a project in the current directory):
#   docker run --rm -v "$(pwd):/project" -w /project n64-dev make
#
# Or interactively:
#   docker run --rm -it -v "$(pwd):/project" -w /project n64-dev bash
# ============================================================================

# The toolchain image contains the MIPS GCC compiler at /n64_toolchain.
# It does NOT contain the libdragon C library — that must be built separately.
# We use the preview-tagged image which targets the preview branch of libdragon.
FROM ghcr.io/dragonminded/libdragon:preview

ENV N64_INST=/n64_toolchain
ENV PATH="${N64_INST}/bin:${PATH}"

# ---------------------------------------------------------------------------
# 1. Build and install libdragon (preview branch)
#    The toolchain image ships the compiler. This step builds the C library
#    (rdpq, audio, etc.) and installs headers/libs into N64_INST.
# ---------------------------------------------------------------------------
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        git ca-certificates make python3 && \
    rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch preview \
        https://github.com/DragonMinded/libdragon.git /tmp/libdragon && \
    cd /tmp/libdragon && \
    ./build.sh "${N64_INST}" && \
    rm -rf /tmp/libdragon

# ---------------------------------------------------------------------------
# 2. Build and install Tiny3D
#    tiny3d's build.sh compiles the RSP microcode, C library, and tools,
#    then installs into N64_INST alongside libdragon.
#    Tiny3D requires Python 3 and the libdragon toolchain to already be built.
# ---------------------------------------------------------------------------
RUN git clone --depth 1 \
        https://github.com/HailToDodongo/tiny3d.git /tmp/tiny3d && \
    cd /tmp/tiny3d && \
    N64_INST="${N64_INST}" ./build.sh && \
    rm -rf /tmp/tiny3d

# ---------------------------------------------------------------------------
# Default working directory — callers should mount their project here.
# ---------------------------------------------------------------------------
WORKDIR /project
