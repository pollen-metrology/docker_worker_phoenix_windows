# docker build -t pollenm/docker_worker_phoenix_windows_test .
# docker run --dns=8.8.8.8 -it pollenm/docker_worker_phoenix_windows_test
# docker run --user "NT AUTHORITY\SYSTEM" -it pollenm/docker_worker_phoenix_windows_test
# push to github
# push to docker-hub => docker push pollenm/docker_worker_phoenix_windows_test

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
#FROM mcr.microsoft.com/windows/servercore:ltsc2019 as pollen_step_os
FROM mcr.microsoft.com/windows/servercore:10.0.17763.737 as pollen_step_os

LABEL vendor="Pollen Metrology"
LABEL maintainer="emmanuel.richard@pollen-metrology.com"

RUN net accounts /MaxPWAge:unlimited
RUN net user gitlab /add
RUN net localgroup Administrators /add gitlab
USER gitlab
# ----------------------------------------------------------------------------------------------------- #

# --------------------------------------------- SCOOP - CHOCOLATEY - GIT ------------------------------ #
FROM pollen_step_os as pollen_step_scoop_choco_git
RUN powershell -Command \
    Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh'); \
	scoop update --global;
# --global 
RUN @"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))" && SET "PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin"
RUN choco install git -y    
# ----------------------------------------------------------------------------------------------------- #    

# --------------------------------------------- VS2015 ------------------------------------------------ #
FROM pollen_step_scoop_choco_git as pollen_step_vs2015
 RUN \
    # Install VS Build Tools 2015
    powershell.exe Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')) \
    && choco install -y --no-progress visualcpp-build-tools --version=14.0.25420.1 \
    && choco install -y --no-progress vcbuildtools --version=2015.2
# ----------------------------------------------------------------------------------------------------- #

# --------------------------------------------- VS2019 ------------------------------------------------ #
FROM pollen_step_vs2015 as pollen_step_vs2019
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

    
# --------------------------------------------- VCPKG ------------------------------------------------- #
FROM pollen_step_vs2019 as pollen_step_vcpkg
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
COPY vcpkg/triplets/x64-windows-static-dynamic-v140.cmake c:\\vcpkg\\triplets
RUN powershell -Command \
	.\vcpkg\vcpkg.exe install --overlay-ports=C:\extra-vcpkg-ports\ --triplet x64-windows-static-dynamic-v140 --clean-after-build boost-core boost-math boost-crc boost-random boost-format boost-stacktrace cereal vxl opencv3[core,contrib,tiff,png,jpeg] eigen3 gtest
# ----------------------------------------------------------------------------------------------------- #

# --------------------------------------------- CLEANUP ----------------------------------------------- #
FROM pollen_step_vcpkg as pollen_step_cleanup
RUN powershell -Command choco install -y choco-cleaner
RUN powershell -Command choco-cleaner
RUN \
    #Cleanup
    powershell Remove-Item -Force -Recurse "%TEMP%\*" \
    && rmdir /S /Q "%ProgramData%\Package Cache"
# ----------------------------------------------------------------------------------------------------- # 

# --------------------------------------------- PYTHON ------------------------------------------------ #
FROM pollen_step_cleanup as pollen_step_python
RUN powershell -Command \
	scoop install python@3.6.10 --global; \
	scoop install python@3.7.6 --global; \
	scoop install python@3.8.2 --global;
# ----------------------------------------------------------------------------------------------------- # 

# --------------------------------------------- DOXYGEN ----------------------------------------------- #
FROM pollen_step_python as pollen_step_doxygen
RUN powershell -Command scoop install doxygen --global;
# ----------------------------------------------------------------------------------------------------- # 

# --------------------------------------------- GRAPHVIZ ---------------------------------------------- #
FROM pollen_step_doxygen as pollen_step_graphiz
RUN powershell -Command scoop install graphviz --global;
# ----------------------------------------------------------------------------------------------------- # 

# --------------------------------------------- CMAKE ------------------------------------------------- #
FROM pollen_step_graphiz as pollen_step_cmake
RUN powershell -Command scoop install cmake@3.18.0 --global;
# ----------------------------------------------------------------------------------------------------- # 

# --------------------------------------------- CONAN ------------------------------------------------ #
FROM pollen_step_cmake as pollen_step_conan
RUN powershell -Command python3 -m pip install conan;
# ----------------------------------------------------------------------------------------------------- # 


# --------------------------------------------- GITLAB-RUNNER ----------------------------------------- #
FROM pollen_step_conan as pollen_step_gitlab_runner
RUN powershell -Command New-Item -Path "c:\\" -Name "GitLab-Runner" -ItemType "directory"

#RUN powershell -Command Invoke-WebRequest -Uri "https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-windows-amd64.exe" -UseBasicParsing -OutFile "c:\\GitLab-Runner\\gitlab-runner.exe"
COPY tools/gitlab-runner-windows-amd64.exe c:\\GitLab-Runner\\gitlab-runner.exe

RUN powershell -Command c:\GitLab-Runner\.\gitlab-runner.exe install

# ----------------------------------------------------------------------------------------------------- # 

# --------------------------------------------- COPY MISSING DLL ----------------------------------------- #
FROM pollen_step_gitlab_runner as pollen_step_copy_missing_dll
COPY dlls/opengl32.dll c:\\Windows\\System32\\opengl32.dll
COPY dlls/glu32.dll c:\\Windows\\System32\\glu32.dll
# ----------------------------------------------------------------------------------------------------- # 

# --------------------------------------------- ENTRYPOINT ------------------------------------------------ #
FROM pollen_step_copy_missing_dll as pollen_step_entrypoint
COPY run.ps1 c:

# RUN powershell -Command "$env:Path += ';c:\Users\gitlab\scoop\shims\'"

ENTRYPOINT [ "powershell.exe", "C:\\.\\run.ps1" ]
# --------------------------------------------------------------------------------------------------------- #
