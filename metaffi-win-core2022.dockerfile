# Use the specified base image
FROM mcr.microsoft.com/windows/servercore:ltsc2022

# Copy MetaFFI Installers
COPY ./metaffi-installer/installers_output/metaffi-installer-0.3.0.exe .
COPY ./metaffi-installer/installers_output/metaffi-plugin-installer-0.3.0-python311.exe .
COPY ./metaffi-installer/installers_output/metaffi-plugin-installer-0.3.0-go.exe .
COPY ./metaffi-installer/installers_output/metaffi-plugin-installer-0.3.0-openjdk.exe .
COPY ./metaffi-installer/post_install_tests_template.py .

# Install Chocolatey
RUN C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command \
    Set-ExecutionPolicy Bypass -Scope Process -Force; \
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; \
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')); \
    choco feature disable --name showDownloadProgress

# Install core tools and dependencies
RUN C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command "& { \
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User'); \
    choco install -y git curl wget mingw \
}"
RUN C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command "& { \
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User'); \
    choco install -y python311 \
}"
RUN C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command "& { \
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User'); \
    choco install -y microsoft-openjdk --version=21.0.4 \
}"
RUN C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command "& { \
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User'); \
    choco install -y golang --version=1.23.1 \
}"

# Inspect environment variables after installations
RUN C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command "& { \
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User'); \
    Write-Host 'PATH: ' $env:Path; \
    Write-Host 'JAVA_HOME: ' $env:JAVA_HOME; \
    Write-Host 'GOROOT: ' $env:GOROOT; \
    Write-Host 'PYTHONPATH: ' $env:PYTHONPATH; \
    Write-Host 'All environment variables:'; \
    Get-ChildItem env: | Format-Table -AutoSize \
}"

# Set environment variables based on inspection
ENV METAFFI_HOME="C:\\Users\\ContainerAdministrator\\MetaFFI\\"
ENV CGO_ENABLED=1
ENV CGO_CFLAGS="-O2 -g -IC:\\Users\\ContainerAdministrator\\MetaFFI\\"
ENV JAVA_HOME="C:\\Program Files\\Microsoft\\jdk-21.0.4.7-hotspot"
ENV GOROOT="C:\\Program Files\\Go"
ENV GOPATH="C:\\Users\\ContainerAdministrator\\go"
ENV PATH="C:\\Windows\\System32;C:\\Windows;C:\\Windows\\System32\\WindowsPowerShell\\v1.0;C:\\Users\\ContainerAdministrator\\MetaFFI\\;C:\\Program Files\\Microsoft\\jdk-21.0.4.7-hotspot\\bin;C:\\Program Files\\Microsoft\\jdk-21.0.4.7-hotspot\\bin\\server;C:\\Program Files\\Go\\bin;C:\\Python311;C:\\Python311\\Scripts;C:\\ProgramData\\chocolatey\\bin;C:\\ProgramData\\mingw64\\mingw64\\bin"

# Verify installations
RUN C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command "& { \
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User'); \
    where.exe java; where.exe go; where.exe python \
}"

# upgrade pip
RUN C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command "& { \
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User'); \
    python -m pip install --upgrade pip \
}"

# Install Python packages
RUN C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command "& { \
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User'); \
    python -m pip install metaffi-api colorama \
}"

# Install MetaFFI and its plugins
RUN C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command "& { \
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User'); \
    .\metaffi-installer-0.3.0.exe -s \
}"
RUN C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command "& { \
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User'); \
    .\metaffi-plugin-installer-0.3.0-python311.exe \
}"
RUN C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command "& { \
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User'); \
    .\metaffi-plugin-installer-0.3.0-go.exe \
}"
RUN C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command "& { \
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User'); \
    .\metaffi-plugin-installer-0.3.0-openjdk.exe \
}"

# Clean up installers
RUN C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command "& { \
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User'); \
    Remove-Item metaffi-installer-0.3.0.exe, metaffi-plugin-installer-0.3.0-python311.exe, metaffi-plugin-installer-0.3.0-go.exe, metaffi-plugin-installer-0.3.0-openjdk.exe \
}"

# Run post-install tests
RUN C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command "& { \
    Get-ChildItem -Recurse -Force -Path $env:METAFFI_HOME; \
    python post_install_tests_template.py \
}"

