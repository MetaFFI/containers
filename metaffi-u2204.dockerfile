# Use the specified base image
FROM ubuntu:22.04
ARG METAFFI_INSTALLER

RUN apt-get update && apt-get upgrade -y && DEBIAN_FRONTEND=noninteractive apt-get install -y apt-utils gcc g++ gdb cmake make build-essential vim wget curl git unzip tar software-properties-common tzdata

# Download MetaFFI Installer
COPY ${METAFFI_INSTALLER} .

# Install Python to run the installer
RUN apt-get install -y python3 python3-pip python3.11 python3.11-dev
RUN pip3 install distro beautifulsoup4 requests pandas numpy colorama

# Install MetaFFI
RUN python3 metaffi_installer.py -s
RUN rm metaffi_installer.py

# Set environment variables for Go and CGO
ENV PATH=$PATH:/usr/local/go/bin:/home/vscode/go/bin \
    GOPATH=/home/vscode/go \
    GOBIN=/home/vscode/go/bin \
    CGO_ENABLED=1 \
    CGO_CFLAGS=-I/usr/local/metaffi \
    METAFFI_HOME=/usr/local/metaffi \
    JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64 \
    PYTHONHOME=/usr