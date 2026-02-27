# CI-replica Ubuntu build environment for MetaFFI
# Mirrors the build-ubuntu job in manual-build-installers.yml exactly.
#
# Usage:
#   docker build -f ubuntu-build.dockerfile -t metaffi-ci-ubuntu .
#   docker run -it metaffi-ci-ubuntu
#
#   # Inside container:
#   ./run-ctests.sh                              # all CTests
#   ./run-ctests.sh -R "go_api_test"             # one test
#   ./run-ctests.sh valgrind -R "go_api_test"    # one test under valgrind

FROM ubuntu:24.04

ARG BUILD_TYPE=Debug
ARG METAFFI_REF=main
ARG GO_VERSION=1.26.0
ARG JAVA_VERSION=21

ENV DEBIAN_FRONTEND=noninteractive

# ---------- 1. System packages (matches CI "Install base dependencies" step) ----------
# Add Kitware APT repo for a recent CMake (Ubuntu 24.04 ships 3.28, project needs >=3.30)
RUN apt-get update && \
    apt-get install -y ca-certificates gnupg software-properties-common wget && \
    wget -qO - https://apt.kitware.com/keys/kitware-archive-latest.asc | \
        gpg --dearmor -o /usr/share/keyrings/kitware-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ noble main" \
        > /etc/apt/sources.list.d/kitware.list && \
    apt-get update && \
    apt-get install -y \
        build-essential ninja-build python3-dev \
        autoconf autoconf-archive automake libtool \
        valgrind cmake git curl \
        pkg-config zip unzip tar maven && \
    rm -rf /var/lib/apt/lists/*

# ---------- 2. Python 3.11 via deadsnakes PPA ----------
RUN add-apt-repository ppa:deadsnakes/ppa -y && \
    apt-get update && \
    apt-get install -y python3.11 python3.11-venv python3.11-dev python3.11-distutils && \
    rm -rf /var/lib/apt/lists/* && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 && \
    update-alternatives --install /usr/bin/python  python  /usr/bin/python3.11 1 && \
    curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11

# ---------- 3. Go ----------
RUN wget -q "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -O /tmp/go.tar.gz && \
    tar -C /usr/local -xzf /tmp/go.tar.gz && \
    rm /tmp/go.tar.gz
ENV PATH="/usr/local/go/bin:${PATH}"

# ---------- 4. Java (Temurin) via Adoptium API ----------
RUN mkdir -p /usr/lib/jvm && \
    wget -q "https://api.adoptium.net/v3/binary/latest/${JAVA_VERSION}/ga/linux/x64/jdk/hotspot/normal/eclipse" \
         -O /tmp/jdk.tar.gz && \
    tar -xzf /tmp/jdk.tar.gz -C /usr/lib/jvm && \
    rm /tmp/jdk.tar.gz && \
    mv /usr/lib/jvm/jdk-* /usr/lib/jvm/temurin-${JAVA_VERSION}
ENV JAVA_HOME=/usr/lib/jvm/temurin-21
ENV PATH="${JAVA_HOME}/bin:${PATH}"

# ---------- 5. vcpkg ----------
WORKDIR /work
RUN git clone https://github.com/microsoft/vcpkg.git /work/vcpkg && \
    /work/vcpkg/bootstrap-vcpkg.sh -disableMetrics
ENV VCPKG_ROOT=/work/vcpkg

RUN /work/vcpkg/vcpkg install \
        spdlog:x64-linux \
        doctest:x64-linux \
        nlohmann-json:x64-linux \
        boost-filesystem:x64-linux \
        boost-dll:x64-linux \
        boost-system:x64-linux \
        boost-thread:x64-linux \
        boost-program-options:x64-linux

# ---------- 6. Clone metaffi-root ----------
RUN git clone https://github.com/MetaFFI/metaffi-root.git /work/metaffi-root && \
    git -C /work/metaffi-root fetch --all --tags && \
    git -C /work/metaffi-root checkout "${METAFFI_REF}"

# ---------- 7. Environment variables (matching CI exactly) ----------
ENV METAFFI_SOURCE_ROOT=/work/metaffi-root
ENV METAFFI_HOME=/work/metaffi-root/output/ubuntu/x64/${BUILD_TYPE}
ENV GOFLAGS=-mod=mod
ENV PATH="${METAFFI_HOME}:${METAFFI_HOME}/sdk/api/cpp:${JAVA_HOME}/bin:${VCPKG_ROOT}/installed/x64-linux/bin:${VCPKG_ROOT}/installed/x64-linux/debug/bin:/usr/local/go/bin:${PATH}"
ENV LD_LIBRARY_PATH="${JAVA_HOME}/lib/server:${METAFFI_HOME}:${METAFFI_HOME}/sdk/api/cpp:${VCPKG_ROOT}/installed/x64-linux/lib:${VCPKG_ROOT}/installed/x64-linux/debug/lib"

# ---------- 8. CMake configure ----------
RUN cmake \
        -S /work/metaffi-root \
        -B /work/metaffi-root/cmake-build-${BUILD_TYPE} \
        -DCMAKE_BUILD_TYPE=${BUILD_TYPE} \
        -DCMAKE_TOOLCHAIN_FILE=${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake

# ---------- 9. Build MetaFFI ----------
RUN cmake --build /work/metaffi-root/cmake-build-${BUILD_TYPE} \
        --target MetaFFI --config ${BUILD_TYPE}

# ---------- 10. Build CTest prerequisite targets ----------
RUN for target in \
        jvm_host_test \
        jvm_idl_plugin_java_tests_classes \
        jvm_api_test_classes \
        jvm_host_compiler_test_classes \
        jvm_host_compiler_e2e_test_classes \
        go_api_test; do \
      echo "Building CTest prerequisite: ${target}" && \
      cmake --build /work/metaffi-root/cmake-build-${BUILD_TYPE} \
            --target "${target}" --config ${BUILD_TYPE}; \
    done

# ---------- 11. Helper script ----------
RUN cat > /work/metaffi-root/run-ctests.sh <<'SCRIPT'
#!/bin/bash
set -euo pipefail

# Usage: ./run-ctests.sh [valgrind] [ctest-args...]
# Examples:
#   ./run-ctests.sh                          # run all CTests
#   ./run-ctests.sh -R go_api_test           # run specific test
#   ./run-ctests.sh valgrind                 # all tests under valgrind
#   ./run-ctests.sh valgrind -R go_api_test  # specific test under valgrind

BUILD_TYPE="${BUILD_TYPE:-Debug}"
BUILD_DIR="/work/metaffi-root/cmake-build-${BUILD_TYPE}"

# Environment (mirrors CI "Run CTests" step)
export METAFFI_SOURCE_ROOT="/work/metaffi-root"
export METAFFI_HOME="/work/metaffi-root/output/ubuntu/x64/${BUILD_TYPE}"
export VCPKG_ROOT="/work/vcpkg"
export JAVA_HOME="/usr/lib/jvm/temurin-21"
export PATH="${METAFFI_HOME}:${METAFFI_HOME}/sdk/api/cpp:${JAVA_HOME}/bin:${VCPKG_ROOT}/installed/x64-linux/bin:${VCPKG_ROOT}/installed/x64-linux/debug/bin:/usr/local/go/bin:${PATH}"
export LD_LIBRARY_PATH="${JAVA_HOME}/lib/server:${METAFFI_HOME}:${METAFFI_HOME}/sdk/api/cpp:${VCPKG_ROOT}/installed/x64-linux/lib:${VCPKG_ROOT}/installed/x64-linux/debug/lib"
export CGO_CFLAGS="-I${METAFFI_HOME} -I${METAFFI_SOURCE_ROOT}/sdk"
export CGO_CPPFLAGS="-I${METAFFI_HOME} -I${METAFFI_SOURCE_ROOT}/sdk"
export GOFLAGS=""
export GOWORK=auto

# Parse arguments
USE_VALGRIND=false
CTEST_ARGS=()
for arg in "$@"; do
    if [ "$arg" = "valgrind" ]; then
        USE_VALGRIND=true
    else
        CTEST_ARGS+=("$arg")
    fi
done

if [ "$USE_VALGRIND" = true ]; then
    echo "=== Running CTests under Valgrind memcheck ==="
    ctest --test-dir "$BUILD_DIR" -C "$BUILD_TYPE" \
        --overwrite MemoryCheckCommand=/usr/bin/valgrind \
        --overwrite "MemoryCheckCommandOptions=--leak-check=full --track-origins=yes --show-leak-kinds=definite --errors-for-leak-kinds=definite --error-exitcode=0 --trace-children=yes --gen-suppressions=all" \
        -T memcheck --output-on-failure "${CTEST_ARGS[@]}"

    # Print valgrind log files
    echo ""
    echo "+++ Valgrind memcheck logs:"
    for f in "$BUILD_DIR/Testing/Temporary/MemoryChecker."*.log; do
        if [ -f "$f" ]; then
            echo "=== $f ==="
            cat "$f"
            echo ""
        fi
    done
else
    echo "=== Running CTests ==="
    # Build go guest artifacts first (dependency for go_host_compiler_e2e_test)
    ctest --test-dir "$BUILD_DIR" -C "$BUILD_TYPE" \
        -R "^go_host_test_build_guest$" --output-on-failure || true

    ctest --test-dir "$BUILD_DIR" -C "$BUILD_TYPE" \
        --output-on-failure "${CTEST_ARGS[@]}"
fi
SCRIPT

RUN sed -i 's/\r$//' /work/metaffi-root/run-ctests.sh && \
    chmod +x /work/metaffi-root/run-ctests.sh

# ---------- 12. Set BUILD_TYPE as runtime env for the helper script ----------
ENV BUILD_TYPE=${BUILD_TYPE}
ENV CGO_CFLAGS="-I${METAFFI_HOME} -I${METAFFI_SOURCE_ROOT}/sdk"
ENV CGO_CPPFLAGS="-I${METAFFI_HOME} -I${METAFFI_SOURCE_ROOT}/sdk"

WORKDIR /work/metaffi-root
CMD ["bash"]
