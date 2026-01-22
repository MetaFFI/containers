# Use Ubuntu 22.04 to match WSL environment
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install core tools and dependencies
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y software-properties-common && \
    add-apt-repository ppa:deadsnakes/ppa -y && \
    apt-get update && \
    apt-get install -y \
    python3.11 python3.11-venv python3.11-dev python3.11-distutils \
    python3-pip \
    gcc g++ gdb make build-essential \
    vim wget curl git unzip tar \
    apt-utils tzdata ca-certificates gnupg

RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.11 1

RUN curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11


# Install Go 1.23.1
RUN wget https://golang.org/dl/go1.23.1.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go1.23.1.linux-amd64.tar.gz && \
    rm go1.23.1.linux-amd64.tar.gz
ENV PATH="${PATH}:/usr/local/go/bin"

# Download and extract OpenJDK 21.0.4
RUN wget -O openjdk.tar.gz https://download.oracle.com/java/21/archive/jdk-21.0.4_linux-x64_bin.tar.gz && \
    mkdir -p /usr/lib/jvm && \
    tar -xzf openjdk.tar.gz -C /usr/lib/jvm && \
    rm openjdk.tar.gz

# Set JAVA_HOME
ENV JAVA_HOME=/usr/lib/jvm/jdk-21.0.4
ENV PATH="${JAVA_HOME}/bin:${PATH}"

# Copy MetaFFI Installers
COPY ./metaffi-installer/installers_output/metaffi-installer-0.3.0 .
COPY ./metaffi-installer/installers_output/metaffi-plugin-installer-0.3.0-python311 .
COPY ./metaffi-installer/installers_output/metaffi-plugin-installer-0.3.0-go .
COPY ./metaffi-installer/installers_output/metaffi-plugin-installer-0.3.0-openjdk .
COPY ./metaffi-installer/post_install_tests_template.py .


ENV METAFFI_HOME=/usr/local/metaffi
ENV CGO_ENABLED=1
ENV CGO_CFLAGS='-O2 -g -I/usr/local/metaffi/'

# add to openjdk installer
ENV LD_LIBRARY_PATH="${JAVA_HOME}/lib/server"

# TODO: xllr.python311.so doesn't have $ORIGIN?!


# Install MetaFFI and its plugins
RUN ./metaffi-installer-0.3.0 -s && \
    ./metaffi-plugin-installer-0.3.0-python311 && \
    ./metaffi-plugin-installer-0.3.0-go && \
    ./metaffi-plugin-installer-0.3.0-openjdk


# Install Python packages
RUN python3 -m pip install metaffi-api colorama

# Sanity check
RUN test -f /usr/local/metaffi/openjdk/xllr.openjdk.bridge.jar || (echo "File not found!" && exit 1)

# Clean up
RUN rm -f metaffi-installer-0.3.0 \
          metaffi-plugin-installer-0.3.0-go \
          metaffi-plugin-installer-0.3.0-python3 \
          metaffi-plugin-installer-0.3.0-openjdk

# Run post-install tests
RUN python3 post_install_tests_template.py
