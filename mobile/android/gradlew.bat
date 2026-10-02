@echo off
setlocal

set "GRADLE_VERSION=8.14.3"
set "GRADLE_HOME=%USERPROFILE%\.gradle\local-gradle\gradle-%GRADLE_VERSION%"
set "GRADLE_ZIP=%TEMP%\gradle-%GRADLE_VERSION%-bin.zip"

if not exist "%GRADLE_HOME%\bin\gradle.bat" (
    echo Gradle %GRADLE_VERSION% not found. Downloading it...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri 'https://services.gradle.org/distributions/gradle-%GRADLE_VERSION%-bin.zip' -OutFile '%GRADLE_ZIP%'"
    if errorlevel 1 (
        echo Failed to download Gradle %GRADLE_VERSION%.
        exit /b 1
    )

    if exist "%USERPROFILE%\.gradle\local-gradle\gradle-%GRADLE_VERSION%" rmdir /s /q "%USERPROFILE%\.gradle\local-gradle\gradle-%GRADLE_VERSION%"
    if not exist "%USERPROFILE%\.gradle\local-gradle" mkdir "%USERPROFILE%\.gradle\local-gradle"

    powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -Path '%GRADLE_ZIP%' -DestinationPath '%USERPROFILE%\.gradle\local-gradle' -Force"
    if errorlevel 1 (
        echo Failed to extract Gradle %GRADLE_VERSION%.
        exit /b 1
    )

    del /q "%GRADLE_ZIP%" >nul 2>&1
)

call "%GRADLE_HOME%\bin\gradle.bat" %*
exit /b %ERRORLEVEL%
