# Use the specified base image
FROM ubuntu:22.04

RUN apt-get update && apt-get upgrade -y && DEBIAN_FRONTEND=noninteractive apt-get install -y apt-utils gcc g++ gdb cmake make build-essential vim wget curl git unzip tar software-properties-common tzdata

# Download MetaFFI Installer
RUN wget https://github.com/MetaFFI/metaffi-core/releases/download/v0.1.2/metaffi_installer.py

# Install Python to run the installer
RUN apt-get install -y python3 python3-pip
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