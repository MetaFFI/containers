FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-c"]

# ---- System packages + Python 3.11 ----
# Ubuntu 24.04 ships 3.12 by default; the pre-built xllr.python3.so was
# compiled against 3.11, so install 3.11 via the deadsnakes PPA.
RUN apt-get update && apt-get install -y --no-install-recommends \
        software-properties-common curl unzip zip ca-certificates \
        build-essential && \
    add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && apt-get install -y --no-install-recommends \
        python3.11 python3.11-dev python3.11-distutils \
        libpython3.11 python3-pip && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 && \
    rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install --no-cache-dir --break-system-packages \
        pycrosskit metaffi-api pytest pyyaml

# ---- Go 1.23.6 ----
RUN curl -fsSL https://go.dev/dl/go1.23.6.linux-amd64.tar.gz | tar -C /usr/local -xz

ENV GOROOT=/usr/local/go
ENV PATH=/usr/local/go/bin:$PATH
# Prevent Go from auto-downloading toolchain go1.24.4 referenced in go.mod files
ENV GOTOOLCHAIN=local

# ---- JDK 21 (Eclipse Temurin) ----
RUN curl -fsSL \
    "https://api.adoptium.net/v3/binary/latest/21/ga/linux/x64/jdk/hotspot/normal/eclipse?project=jdk" \
    -o /tmp/jdk.tar.gz && \
    mkdir -p /usr/lib/jvm && \
    tar -C /usr/lib/jvm -xzf /tmp/jdk.tar.gz && \
    mv /usr/lib/jvm/jdk-21* /usr/lib/jvm/temurin-21 && \
    rm /tmp/jdk.tar.gz

ENV JAVA_HOME=/usr/lib/jvm/temurin-21
ENV PATH=$JAVA_HOME/bin:$PATH

# ---- Apache Maven 3.9.9 ----
RUN curl -fsSL \
    https://archive.apache.org/dist/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.tar.gz \
    | tar -C /opt -xz && \
    mv /opt/apache-maven-3.9.9 /opt/maven

ENV MAVEN_HOME=/opt/maven
ENV PATH=$MAVEN_HOME/bin:$PATH
RUN mvn --version

# ---- MetaFFI core installer ----
# Installs to /usr/local/metaffi and configures /etc/profile.d/ (not sourced in
# Docker RUN layers), so we set METAFFI_HOME and PATH explicitly via ENV.
COPY containers/metaffi-installer-0.3.1-ubuntu-2404 /tmp/metaffi-installer
RUN chmod +x /tmp/metaffi-installer && /tmp/metaffi-installer -s && rm /tmp/metaffi-installer

ENV METAFFI_HOME=/usr/local/metaffi
ENV PATH=$METAFFI_HOME:$PATH
# Include METAFFI_HOME, JVM plugin dir, and JVM server dir (for libjvm.so)
ENV LD_LIBRARY_PATH=/usr/local/metaffi:/usr/local/metaffi/jvm:/usr/lib/jvm/temurin-21/lib/server

RUN metaffi --help

# ---- Install plugins (manual extraction) ----
# The Ubuntu metaffi binary does not support `--plugin --install <zip>`,
# so we extract each zip manually into $METAFFI_HOME/<plugin-name>/.
COPY containers/metaffi-plugin-python3-0.3.1-ubuntu.zip /tmp/metaffi-plugin-python3.zip
COPY containers/metaffi-plugin-go-0.3.1-ubuntu.zip      /tmp/metaffi-plugin-go.zip
COPY containers/metaffi-plugin-jvm-0.3.1-ubuntu.zip     /tmp/metaffi-plugin-jvm.zip

RUN for ZIP in \
        /tmp/metaffi-plugin-python3.zip \
        /tmp/metaffi-plugin-go.zip \
        /tmp/metaffi-plugin-jvm.zip; do \
    TMPDIR=$(mktemp -d); \
    unzip -q "$ZIP" -d "$TMPDIR"; \
    PLUGIN=$(python3 -c "import json; print(json.load(open('$TMPDIR/plugin_manifest.json'))['name'])"); \
    mkdir -p "$METAFFI_HOME/$PLUGIN"; \
    cp -r "$TMPDIR"/. "$METAFFI_HOME/$PLUGIN/"; \
    python3 "$TMPDIR/plugin_hooks.py" --check-prerequisites; \
    python3 "$METAFFI_HOME/$PLUGIN/plugin_hooks.py" --setup-environment; \
    rm -rf "$TMPDIR" "$ZIP"; \
done

RUN metaffi --plugin --list

# ---- JAR workarounds ----
# xllr.jvm.so (pre-built) looks for metaffi.api.jar at $METAFFI_HOME/jvm/metaffi.api.jar,
# but the plugin installs it under jvm/api/.
RUN cp $METAFFI_HOME/jvm/api/metaffi.api.jar $METAFFI_HOME/jvm/metaffi.api.jar

# Java host tests (pom.xml) reference $METAFFI_HOME/sdk/api/jvm/metaffi.api.jar
# via the CMake build convention. Mirror the jar there so Maven resolves it.
RUN mkdir -p $METAFFI_HOME/sdk/api/jvm && \
    cp $METAFFI_HOME/jvm/api/metaffi.api.jar $METAFFI_HOME/sdk/api/jvm/metaffi.api.jar

# ---- Copy test sources ----
# sdk/ contains Go/Python/Java API modules + pre-compiled guest binaries
# tests/ contains correctness test sources and runner configs
COPY sdk/   /metaffi-tests/sdk/
COPY tests/ /metaffi-tests/tests/

ENV METAFFI_SOURCE_ROOT=/metaffi-tests
ENV CGO_CFLAGS="-O2 -g -I/usr/local/metaffi -I/usr/local/metaffi/include -I/metaffi-tests/sdk"

# ---- Run correctness tests ----
# fail_fast=true in config: any test failure → non-zero exit → docker build fails
WORKDIR /metaffi-tests
RUN python3 tests/run_all_tests.py --config tests/configs/only_correctness_config.yml
