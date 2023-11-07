# Use the specified base image
FROM mcr.microsoft.com/devcontainers/base:ubuntu22.04

# Install Go
RUN wget https://golang.org/dl/go1.21.3.linux-amd64.tar.gz -O go.tar.gz && \
    tar -C /usr/local -xzf go.tar.gz && \
    rm go.tar.gz

# Install Java OpenJDK 11 and JNI
# Install Python 3.11 and PIP
# Install GCC
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get clean

RUN apt-get update && \
    apt-get install -y openjdk-11-jdk && \
    apt-get clean

RUN apt-get update && \
    apt install -y openjdk-11-jdk-headless && \
    apt-get clean

RUN apt-get update && \
    apt-get install -y libopenjfx-jni && \
    apt-get clean

RUN apt-get update && \
    apt-get install -y python3.11 && \
    apt-get clean

RUN apt-get update && \
    apt-get install -y python3-pip && \
    apt-get clean

RUN apt-get update && \
    apt-get install -y gcc && \
    apt-get clean

RUN apt-get update && \
    apt-get install -y pkg-config && \
    apt-get clean


# Set environment variables for Go and CGO
ENV PATH=$PATH:/usr/local/go/bin:/home/vscode/go/bin \
    GOPATH=/home/vscode/go \
    GOBIN=/home/vscode/go/bin \
    CGO_ENABLED=1 \
    CGO_CFLAGS=-I/usr/local/metaffi \
    METAFFI_HOME=/usr/local/metaffi \
    JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64 \
    PYTHONHOME=/usr

# Create the Go workspace directory
RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"

# Install MetaFFI
COPY . /usr/local/metaffi
RUN chmod u+x /usr/local/metaffi/metaffi
RUN ln -s /usr/local/metaffi/metaffi /usr/bin/metaffi
RUN ln -s -f /usr/local/metaffi/lib/libexpat.so.1.8.7 /usr/local/metaffi/lib/libexpat.so.1
RUN ln -s -f /usr/local/metaffi/lib/libstdc++.so.6.0.30 /usr/local/metaffi/lib/libstdc++.so.6
RUN ln -s -f /usr/local/metaffi/lib/libz.so.1.2.11 /usr/local/metaffi/lib/libz.so.1
RUN ln -s -f /usr/lib/jvm/java-11-openjdk-amd64/lib/server/libjvm.so /usr/local/metaffi/lib/libjvm.so

# Install Python Packages
RUN python3 -m pip install beautifulsoup4 requests 

