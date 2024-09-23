# Use the specified base image
FROM ubuntu:22.04
ARG METAFFI_INSTALLER
ARG METAFFI_PYTHON311_INSTALLER
ARG METAFFI_GO_INSTALLER
ARG METAFFI_OPENJDK_INSTALLER
ARG PIP_REQUIREMENTS

# Copy MetaFFI Installers
COPY ${METAFFI_INSTALLER} .
COPY ${METAFFI_PYTHON311_INSTALLER} .
COPY ${METAFFI_GO_INSTALLER} .
COPY ${METAFFI_OPENJDK_INSTALLER} .
COPY ${PIP_REQUIREMENTS} .

RUN apt-get update && apt-get upgrade -y && DEBIAN_FRONTEND=noninteractive apt-get install -y apt-utils gcc g++ gdb make build-essential vim wget curl git unzip tar software-properties-common tzdata python3-dev

# install paackages required for installation (NOT NEEDED ANYMORE?)
# RUN pip3 install distro beautifulsoup4 requests pandas numpy colorama

# install Python 3.11 and pip (metaffi requires at least python3.11)
RUN curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
RUN apt-get install -y python3.11 python3.11-dev
RUN python3.11 get-pip.py
RUN python3.11 -m pip install pip --upgrade
RUN python3.11 -m pip install setuptools wheel distro --upgrade



# Install MetaFFI
RUN python3.11 -m pip install -r requirements.txt
RUN python3.11 metaffi_installer.py -s


# install Go plugin prerequisites
RUN curl -fsSL https://go.dev/dl/go1.22.7.linux-amd64.tar.gz | tar -C /usr/local -xz
ENV PATH="${PATH}:/usr/local/go/bin"

# install Go plugin
RUN python3.11 metaffi_plugin_go_installer.py

# install OpenJDK plugin prerequisites
RUN apt-get install -y openjdk-21-jdk

# install OpenJDK plugin
RUN python3.11 metaffi_plugin_openjdk_installer.py

# install Python 3.11 plugin
# installs metaffi-api package which requires python3.11 and above
RUN python3.11 metaffi_plugin_python311_installer.py


# cleanup
RUN rm metaffi_installer.py
RUN rm metaffi_plugin_go_installer.py
RUN rm metaffi_plugin_openjdk_installer.py
RUN rm metaffi_plugin_python311_installer.py

# reload environment variables
ENV METAFFI_HOME=/usr/local/metaffi
ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64/

# to make sure libjvm.so is found
ENV LD_LIBRARY_PATH="/usr/lib/jvm/java-21-openjdk-amd64/lib:/usr/lib/jvm/java-21-openjdk-amd64/lib/server"

# export CGO_CFLAGS (for some reason I can't make docker reload ~/.bashrc correctly)
# this environment variable is written by the metaffi_plugin_go_installer.py
ENV CGO_CFLAGS=-I/usr/local/metaffi

# run tests
RUN cd /usr/local/metaffi && python3.11 run_api_tests.py


# # Set environment variables for Go and CGO
# ENV PATH=$PATH:/usr/local/go/bin:/home/vscode/go/bin \
#     GOPATH=/home/vscode/go \
#     GOBIN=/home/vscode/go/bin \
#     CGO_ENABLED=1 \
#     CGO_CFLAGS=-I/usr/local/metaffi \
#     METAFFI_HOME=/usr/local/metaffi \
#     JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64 \
#     PYTHONHOME=/usr