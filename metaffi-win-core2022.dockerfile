# Use the specified base image
FROM mcr.microsoft.com/windows/servercore:ltsc2022
ARG METAFFI_INSTALLER

# Copy MetaFFI Installer
COPY ${METAFFI_INSTALLER} .


# install choco
RUN powershell.exe -Command Write-Host 'Updating system'; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')); choco feature disable --name showDownloadProgress;

# Install Python 3.11, Go, mingw, Microsoft OpenJDK 21
RUN powershell.exe -Command Write-Host 'Installing python 3.11.0'; choco install -y python311; 
RUN powershell.exe -Command Write-Host 'Installing mingw'; choco install -y mingw;
RUN powershell.exe -Command Write-Host 'Installing Microsoft OpenJDK 21.0.4'; choco install -y microsoft-openjdk --version=21.0.4;
RUN powershell.exe -Command Write-Host 'Installing Go 1.22.6'; choco install -y golang --version=1.22.6;

# Install python packages for the unit tests
RUN py -m pip install --upgrade pip
RUN py -m pip install distro beautifulsoup4 requests pandas numpy colorama

#TESTS
RUN refreshenv

# Install MetaFFI   
RUN py metaffi_installer.py -s
RUN del metaffi_installer.py

