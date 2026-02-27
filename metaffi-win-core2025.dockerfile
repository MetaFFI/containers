FROM mcr.microsoft.com/windows/servercore:ltsc2025

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop';"]

COPY metaffi-installer-0.3.1-windows.exe C:\\temp\\metaffi-installer.exe
RUN C:\\temp\\metaffi-installer.exe -s; \
    Remove-Item 'C:\\temp\\metaffi-installer.exe'

# Set env vars that the installer writes to the registry (not visible to
# processes that read Docker-level environment, e.g. docker inspect).
ENV METAFFI_HOME="C:\\Users\\ContainerAdministrator\\MetaFFI"

# Install VC++ Redistributable (provides vcruntime140.dll, msvcp140.dll)
RUN Invoke-WebRequest -Uri 'https://aka.ms/vs/17/release/vc_redist.x64.exe' -OutFile 'C:\temp\vc_redist.x64.exe'; \
    Start-Process -FilePath 'C:\temp\vc_redist.x64.exe' -ArgumentList '/install','/quiet','/norestart' -Wait; \
    Remove-Item 'C:\temp\vc_redist.x64.exe'

# Verify installation
RUN metaffi --help
