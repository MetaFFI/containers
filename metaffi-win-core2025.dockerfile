FROM mcr.microsoft.com/windows/servercore:ltsc2025

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop';"]

# Create temp directory for downloads
RUN New-Item -ItemType Directory -Path 'C:\temp' -Force | Out-Null

# ---- Install VC++ Redistributable (provides vcruntime140.dll, msvcp140.dll) ----
RUN Invoke-WebRequest -Uri 'https://aka.ms/vs/17/release/vc_redist.x64.exe' -OutFile 'C:\temp\vc_redist.x64.exe'; \
    Start-Process -FilePath 'C:\temp\vc_redist.x64.exe' -ArgumentList '/install','/quiet','/norestart' -Wait; \
    Remove-Item 'C:\temp\vc_redist.x64.exe'

# ---- Install MetaFFI core ----
COPY containers/metaffi-installer-0.3.1-windows.exe C:\\temp\\metaffi-installer.exe
RUN C:\\temp\\metaffi-installer.exe -s; \
    Remove-Item 'C:\\temp\\metaffi-installer.exe'

# The installer writes METAFFI_HOME to the registry and adds it to PATH.
# Docker ENV makes it visible to docker inspect and subsequent layers.
ENV METAFFI_HOME="C:\\Users\\ContainerAdministrator\\MetaFFI"
ENV CGO_CFLAGS="-O2 -g -IC:/Users/ContainerAdministrator/MetaFFI -IC:/Users/ContainerAdministrator/MetaFFI/include -IC:/metaffi-tests/sdk"

# Prepend METAFFI_HOME to the container PATH
RUN $old = [Environment]::GetEnvironmentVariable('PATH','Machine'); \
    [Environment]::SetEnvironmentVariable('PATH', $env:METAFFI_HOME + ';' + $old, 'Machine')

# Overwrite metaffi.exe with the newly built version (supports zip plugin install)
COPY containers/metaffi.exe C:\\Users\\ContainerAdministrator\\MetaFFI\\metaffi.exe

# Verify core installation
RUN metaffi --help

# ---- Install Python 3.12 ----
RUN Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.12.9/python-3.12.9-amd64.exe' -OutFile 'C:\temp\python-installer.exe'; \
    Start-Process -FilePath 'C:\temp\python-installer.exe' -ArgumentList '/quiet','InstallAllUsers=1','PrependPath=1','Include_test=0' -Wait; \
    Remove-Item 'C:\temp\python-installer.exe'

# Python installer writes to Machine PATH via registry; refresh for subsequent RUN layers
RUN $old = [Environment]::GetEnvironmentVariable('PATH','Machine'); \
    [Environment]::SetEnvironmentVariable('PATH', $old, 'Machine')

# Install pycrosskit (needed by Go/JVM plugin hooks), metaffi-api, and test dependencies
RUN python -m pip install --no-cache-dir pycrosskit metaffi-api pytest pyyaml

# ---- Install Go 1.23 ----
RUN Invoke-WebRequest -Uri 'https://go.dev/dl/go1.23.6.windows-amd64.zip' -OutFile 'C:\temp\go.zip'; \
    Expand-Archive -Path 'C:\temp\go.zip' -DestinationPath 'C:\' -Force; \
    Remove-Item 'C:\temp\go.zip'

ENV GOROOT="C:\\go"
RUN $old = [Environment]::GetEnvironmentVariable('PATH','Machine'); \
    [Environment]::SetEnvironmentVariable('PATH', 'C:\go\bin;' + $old, 'Machine')

# Prevent Go 1.23.6 from trying to auto-download toolchain go1.24.4 referenced in go.mod files
ENV GOTOOLCHAIN="local"

# ---- Install MinGW-w64 GCC 15.2 (required by Go cgo tests) ----
RUN Invoke-WebRequest -Uri 'https://github.com/brechtsanders/winlibs_mingw/releases/download/15.2.0posix-13.0.0-ucrt-r6/winlibs-x86_64-posix-seh-gcc-15.2.0-mingw-w64ucrt-13.0.0-r6.zip' \
        -OutFile 'C:\temp\mingw.zip'; \
    Expand-Archive -Path 'C:\temp\mingw.zip' -DestinationPath 'C:\' -Force; \
    Remove-Item 'C:\temp\mingw.zip'
RUN $old = [Environment]::GetEnvironmentVariable('PATH','Machine'); \
    [Environment]::SetEnvironmentVariable('PATH', 'C:\mingw64\bin;' + $old, 'Machine')
RUN gcc --version

# ---- Install JDK 21 (Eclipse Temurin) ----
RUN Invoke-WebRequest -Uri 'https://api.adoptium.net/v3/binary/latest/21/ga/windows/x64/jdk/hotspot/normal/eclipse?project=jdk' -OutFile 'C:\temp\jdk.zip'; \
    Expand-Archive -Path 'C:\temp\jdk.zip' -DestinationPath 'C:\temp\jdk-extract' -Force; \
    $jdkDir = (Get-ChildItem 'C:\temp\jdk-extract' -Directory | Select-Object -First 1).FullName; \
    Move-Item $jdkDir 'C:\jdk21'; \
    Remove-Item -Recurse -Force 'C:\temp\jdk-extract'; \
    Remove-Item 'C:\temp\jdk.zip'

ENV JAVA_HOME="C:\\jdk21"
RUN $old = [Environment]::GetEnvironmentVariable('PATH','Machine'); \
    [Environment]::SetEnvironmentVariable('PATH', 'C:\jdk21\bin;C:\jdk21\bin\server;' + $old, 'Machine')

# ---- Install Apache Maven 3.9.9 (needed for Java host correctness tests) ----
RUN Invoke-WebRequest -Uri 'https://archive.apache.org/dist/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.zip' \
        -OutFile 'C:\temp\maven.zip'; \
    Expand-Archive -Path 'C:\temp\maven.zip' -DestinationPath 'C:\' -Force; \
    Rename-Item 'C:\apache-maven-3.9.9' 'C:\maven'; \
    Remove-Item 'C:\temp\maven.zip'
ENV MAVEN_HOME="C:\\maven"
RUN $old = [Environment]::GetEnvironmentVariable('PATH','Machine'); \
    [Environment]::SetEnvironmentVariable('PATH', 'C:\maven\bin;' + $old, 'Machine')
RUN mvn --version

# ---- Install plugins via metaffi CLI ----
COPY containers/metaffi-plugin-python3-0.3.1-windows.zip C:\\temp\\metaffi-plugin-python3.zip
COPY containers/metaffi-plugin-go-0.3.1-windows.zip C:\\temp\\metaffi-plugin-go.zip
COPY containers/metaffi-plugin-jvm-0.3.1-windows.zip C:\\temp\\metaffi-plugin-jvm.zip

RUN metaffi --plugin --install C:\\temp\\metaffi-plugin-python3.zip; \
    Remove-Item 'C:\\temp\\metaffi-plugin-python3.zip'

RUN metaffi --plugin --install C:\\temp\\metaffi-plugin-go.zip; \
    Remove-Item 'C:\\temp\\metaffi-plugin-go.zip'

RUN metaffi --plugin --install C:\\temp\\metaffi-plugin-jvm.zip; \
    Remove-Item 'C:\\temp\\metaffi-plugin-jvm.zip'

# The JVM runtime looks for metaffi.api.jar at $METAFFI_HOME/jvm/metaffi.api.jar,
# but the installer places it in $METAFFI_HOME/jvm/api/metaffi.api.jar.
RUN Copy-Item 'C:\Users\ContainerAdministrator\MetaFFI\jvm\api\metaffi.api.jar' \
              'C:\Users\ContainerAdministrator\MetaFFI\jvm\metaffi.api.jar'

# Java host tests (pom.xml) reference metaffi.api.jar via the CMake build convention:
#   $METAFFI_HOME/sdk/api/jvm/metaffi.api.jar
# Mirror the jar there so Maven can resolve the system-scope dependency.
RUN New-Item -ItemType Directory -Path 'C:\Users\ContainerAdministrator\MetaFFI\sdk\api\jvm' -Force | Out-Null; \
    Copy-Item 'C:\Users\ContainerAdministrator\MetaFFI\jvm\api\metaffi.api.jar' \
              'C:\Users\ContainerAdministrator\MetaFFI\sdk\api\jvm\metaffi.api.jar'

# Verify plugins are installed
RUN metaffi --plugin --list

# ---- Copy test sources ----
# sdk/ contains Go/Python/Java API modules + pre-compiled guest binaries
# tests/ contains correctness test sources and runner configs
COPY sdk/ C:\\metaffi-tests\\sdk\\
COPY tests/ C:\\metaffi-tests\\tests\\
ENV METAFFI_SOURCE_ROOT="C:\\metaffi-tests"

# ---- Run correctness tests ----
# fail_fast=true in config: any test failure → non-zero exit → docker build fails
WORKDIR C:\\metaffi-tests
RUN python tests\run_all_tests.py --config tests\configs\only_correctness_config.yml

