FROM mcr.microsoft.com/windows:ltsc2019

# Set progress preference for all operations
RUN powershell -Command "$progressPreference = 'silentlyContinue'"

# Download and install Python
ADD https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe c:\\python-installer.exe
RUN python-installer.exe /quiet InstallAllUsers=1 PrependPath=1
RUN del python-installer.exe


# Upgrade pip
RUN python -m pip install --upgrade pip

# Download and install Microsoft OpenJDK 21
ADD https://aka.ms/download-jdk/microsoft-jdk-21.0.3-windows-x64.msi c:\\openjdk.msi
RUN msiexec.exe /i openjdk.msi /quiet /norestart
RUN del openjdk.msi


# Download and install Go
ADD https://go.dev/dl/go1.22.4.windows-amd64.msi c:\\go-installer.msi
RUN msiexec.exe /i go-installer.msi /quiet /norestart
RUN del go-installer.msi

# Download and extract MinGW prebuilt binaries
ADD https://github.com/brechtsanders/winlibs_mingw/releases/download/14.1.0posix-18.1.5-11.0.1-ucrt-r1/winlibs-x86_64-posix-seh-gcc-14.1.0-llvm-18.1.5-mingw-w64ucrt-11.0.1-r1.zip c:\\winlibs.zip
RUN powershell -Command "Expand-Archive -Path c:\\winlibs.zip -DestinationPath c:\\MinGW; Remove-Item -Path c:\\winlibs.zip"

# Update PATH environment variable
RUN setx PATH "C:\\MinGW\\bin;C:\\MinGW\\mingw64\\bin;c:\\MetaFFI\\;%PATH%"

# Java Home
ENV JAVA_HOME="C:\\Program Files\\Microsoft\\jdk-21.0.3.9-hotspot\\"
RUN setx PATH "C:\\Program Files\\Microsoft\\jdk-21.0.3.9-hotspot\\bin\\;C:\\Program Files\\Microsoft\\jdk-21.0.3.9-hotspot\\bin\\server\\;%PATH%"

# MetaFFI Home
ENV MetaFFI_HOME="c:\\MetaFFI\\"

# Copy "metaffi_installer.py" to "C:/metaffi_installer.py"
COPY "metaffi_installer.py" "C:/metaffi_installer.py"

# Install metaffi
RUN py C:/metaffi_installer.py --include-extended-tests -s
