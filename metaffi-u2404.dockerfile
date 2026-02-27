FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

COPY metaffi-installer-0.3.1-ubuntu-2404 /tmp/metaffi-installer
RUN chmod +x /tmp/metaffi-installer && \
    /tmp/metaffi-installer -s && \
    rm /tmp/metaffi-installer

# Set env vars that the installer writes to ~/.profile (not sourced in Docker RUN layers)
ENV METAFFI_HOME=/usr/local/metaffi
ENV LD_LIBRARY_PATH=/usr/local/metaffi

# Verify installation
RUN metaffi --help
