# docker build -t pollenm/docker_worker_phoenix_windows .
# docker run --dns=8.8.8.8 -it pollenm/docker_worker_phoenix_windows
# push to github
# push to docker-hub => docker push pollenm/docker_worker_phoenix_windows

# CONTENT FOR BUILD
#----------------------------------------------------------------------------------------------------------------------#
#                                              Pollen Metrology CONFIDENTIAL                                           #
#----------------------------------------------------------------------------------------------------------------------#
# [2014-2020] Pollen Metrology
# All Rights Reserved.
#
# NOTICE:  All information contained herein is, and remains the property of Pollen Metrology.
# The intellectual and technical concepts contained herein are  proprietary to Pollen Metrology and  may be covered by
# French, European and/or Foreign Patents, patents in process, and are protected by trade secret or copyright law.
# Dissemination of this information or reproduction of this material is strictly forbidden unless prior written
# permission is obtained from Pollen Metrology.
#----------------------------------------------------------------------------------------------------------------------#

# --------------------------------------------- OS ---------------------------------------------------- #
FROM mcr.microsoft.com/windows/servercore:ltsc2019 as pollen_step_os

LABEL vendor="Pollen Metrology"
LABEL maintainer="emmanuel.richard@pollen-metrology.com"
# ----------------------------------------------------------------------------------------------------- #

# --------------------------------------------- SCOOP AND UPDATE -------------------------------------- #
FROM pollen_step_os as pollen_step_scoop
RUN powershell -Command \
    Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh'); \
	scoop install git; \
	scoop update;
# ----------------------------------------------------------------------------------------------------- #    

# --------------------------------------------- PYTHON ------------------------------------------------ #
FROM pollen_step_scoop as pollen_step_python
RUN powershell -Command \
	scoop install python@3.6.10; \
	scoop install python@3.7.6; \
	scoop install python@3.8.2;
# ----------------------------------------------------------------------------------------------------- # 

# --------------------------------------------- DOXYGEN ----------------------------------------------- #
FROM pollen_step_python as pollen_step_doxygen
RUN powershell -Command scoop install doxygen;
# ----------------------------------------------------------------------------------------------------- # 

# --------------------------------------------- GRAPHVIZ ---------------------------------------------- #
FROM pollen_step_doxygen as pollen_step_graphiz
RUN powershell -Command scoop install graphviz;
# ----------------------------------------------------------------------------------------------------- # 

# --------------------------------------------- CMAKE ------------------------------------------------- #
FROM pollen_step_graphiz as pollen_step_cmake
RUN powershell -Command scoop install cmake@3.16.4;
# ----------------------------------------------------------------------------------------------------- # 

# --------------------------------------------- VS2019 ------------------------------------------------ #
FROM pollen_step_cmake as pollen_step_vs2019
RUN \
    # Install VS Build Tools
    curl -fSLo vs_BuildTools.exe https://download.visualstudio.microsoft.com/download/pr/378e5eb4-c1d7-4c05-8f5f-55678a94e7f4/a022deec9454c36f75dafe780b797988b6111cfc06431eb2e842c1811151c40b/vs_BuildTools.exe \
    # Installer won't detect DOTNET_SKIP_FIRST_TIME_EXPERIENCE if ENV is used, must use setx /M
    && setx /M DOTNET_SKIP_FIRST_TIME_EXPERIENCE 1 \
    && start /w vs_BuildTools.exe \
    --add Microsoft.VisualStudio.Workload.VCTools \
    --add Microsoft.VisualStudio.Workload.MSBuildTools \
    --add Microsoft.VisualStudio.Component.VC.CoreBuildTools \
    --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 \
    --add Microsoft.VisualStudio.Component.Windows10SDK.18362 \
    --add Microsoft.VisualStudio.Component.VC.ATLMFC \
    --quiet --norestart --nocache --wait \
    && powershell -Command "if ($err = dir $Env:TEMP -Filter dd_setup_*_errors.log | where Length -gt 0 | Get-Content) { throw $err }" \
    && del vs_BuildTools.exe
# ----------------------------------------------------------------------------------------------------- # 

# --------------------------------------------- CLEANUP ----------------------------------------------- #
FROM pollen_step_vs2019 as pollen_step_cleanup
RUN \
    # Cleanup
    powershell Remove-Item -Force -Recurse "%TEMP%\*" \
    && rmdir /S /Q "%ProgramData%\Package Cache"
# ----------------------------------------------------------------------------------------------------- #     

# --------------------------------------------- VCPKG ------------------------------------------------- #
FROM pollen_step_cleanup as pollen_step_vcpkg
COPY extra-vcpkg-ports /extra-vcpkg-ports
# Install VCPKG
RUN powershell -Command \
	git clone --recurse-submodules --branch master https://github.com/Microsoft/vcpkg.git; \
	cd vcpkg; \
	git checkout 411b4cc; \
	.\bootstrap-vcpkg.bat -disableMetrics;
### Install Phoenix dependencies via vcpkg
RUN powershell -Command \
	.\vcpkg\vcpkg.exe install --overlay-ports=C:\extra-vcpkg-ports\ --triplet x64-windows-static --clean-after-build boost-core boost-math boost-crc boost-random boost-format boost-stacktrace cereal vxl opencv3[core,contrib,tiff,png,jpeg] eigen3 gtest
# ----------------------------------------------------------------------------------------------------- #


# --------------------------------------------- GITLAB-RUNNER ----------------------------------------- #
FROM pollen_step_vcpkg as pollen_step_gitlab-runner
RUN powershell -Command New-Item -Path "c:\\" -Name "GitLab-Runner" -ItemType "directory"

RUN powershell -Command Invoke-WebRequest -Uri "https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-windows-amd64.exe" -UseBasicParsing -OutFile "c:\\GitLab-Runner\\gitlab-runner.exe"

RUN powershell -Command c:\GitLab-Runner\.\gitlab-runner.exe install

# --------------------------------------------- END GITLAB-RUNNER ------------------------------------------#


# --------------------------------------------- ENTRYPOINT ------------------------------------------------ #
FROM pollen_step_gitlab-runner as pollen_step_entrypoint
COPY run.ps1 c:

#CMD ["cmd"]
#CMD ["powershell"]

ENTRYPOINT [ "powershell.exe", "C:\\.\\run.ps1" ]
# --------------------------------------------------------------------------------------------------------- #