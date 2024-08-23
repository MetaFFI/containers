# Use the specified base image
FROM mcr.microsoft.com/windows/nanoserver:ltsc2022

# install choco
RUN powershell.exe -Command Write-Host 'Updating system'; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')); choco feature disable --name showDownloadProgress;

# Install Python 3.11
RUN powershell.exe -Command Write-Host 'Installing Python3'; choco install -y python --version=3.11.0;
RUN py -m pip install distro beautifulsoup4 requests pandas numpy colorama

# Download MetaFFI Installer
RUN wget https://github.com/MetaFFI/metaffi-core/releases/download/v0.1.2/metaffi_installer.py

# Install MetaFFI
RUN py metaffi_installer.py -s
RUN del metaffi_installer.py

