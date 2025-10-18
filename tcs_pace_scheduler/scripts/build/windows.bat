@echo off
REM ========================================
REM Windows Build Script (Native CMD)
REM TCS PacePort Scheduler
REM ========================================
REM
REM IMPORTANT: Firebase is excluded from Windows builds
REM due to C++ SDK linking incompatibilities.
REM Windows uses local_notifier for desktop notifications.

setlocal EnableDelayedExpansion

echo.
echo ========================================================
echo   Windows Build - TCS PacePort Scheduler
echo ========================================================
echo.

cd /d "%~dp0\..\..\"

REM Version Management
echo [INFO] Checking current version...

for /f "tokens=2 delims=: " %%a in ('findstr "^version:" pubspec.yaml') do set CURRENT_VERSION=%%a
for /f "tokens=1 delims=+" %%a in ("%CURRENT_VERSION%") do set VERSION_NAME=%%a
for /f "tokens=2 delims=+" %%a in ("%CURRENT_VERSION%") do set BUILD_NUMBER=%%a

echo [INFO] Current version: %VERSION_NAME% (build %BUILD_NUMBER%)

set /a NEW_BUILD_NUMBER=%BUILD_NUMBER%+1
set NEW_VERSION=%VERSION_NAME%+%NEW_BUILD_NUMBER%

echo [INFO] New version: %VERSION_NAME% (build %NEW_BUILD_NUMBER%)
echo.

set /p CONFIRM="Continue with build? [Y/n]: "
if /i "%CONFIRM%"=="n" (
    echo [WARNING] Build cancelled by user
    pause
    exit /b 0
)

REM Update version
echo [INFO] Updating version in pubspec.yaml...
powershell -Command "(Get-Content pubspec.yaml) -replace '^version:.*', 'version: %NEW_VERSION%' | Set-Content pubspec.yaml"
echo [SUCCESS] Version updated to %NEW_VERSION%
echo.

REM Clean & Dependencies
echo [INFO] Cleaning previous builds...
call flutter clean
if errorlevel 1 (
    echo [ERROR] Clean failed
    pause
    exit /b 1
)
echo [SUCCESS] Clean complete
echo.

echo [INFO] Getting Flutter dependencies...
call flutter pub get
if errorlevel 1 (
    echo [ERROR] Failed to get dependencies
    pause
    exit /b 1
)
echo [SUCCESS] Dependencies updated
echo.

REM ========================================
REM FIREBASE EXCLUSION (WINDOWS-SPECIFIC)
REM ========================================
echo ========================================================
echo   Configuring Windows Build
echo ========================================================
echo.
echo [WARNING] Excluding Firebase from Windows build (C++ SDK incompatible)
echo [INFO] Windows will use local_notifier for notifications instead
echo.

REM Exclude Firebase from CMake plugin list (Step 1: CMake file)
if exist "windows\flutter\generated_plugins.cmake" (
    powershell -Command "(Get-Content windows\flutter\generated_plugins.cmake) -replace '^  firebase_core', '  # firebase_core  # Excluded' | Set-Content windows\flutter\generated_plugins.cmake"
    echo [SUCCESS] Firebase excluded from CMake plugin list
)

REM Exclude Firebase from plugin registrant (Step 2: C++ includes)
if exist "windows\flutter\generated_plugin_registrant.cc" (
    powershell -Command "(Get-Content windows\flutter\generated_plugin_registrant.cc) -replace '#include <firebase_core/firebase_core_plugin_c_api.h>', '// #include <firebase_core/firebase_core_plugin_c_api.h>  // Excluded' | Set-Content windows\flutter\generated_plugin_registrant.cc"
    echo [SUCCESS] Firebase include excluded from plugin registrant
)

REM Exclude Firebase registrar calls (Step 3: Multi-line function call)
if exist "windows\flutter\generated_plugin_registrant.cc" (
    powershell -Command "$content = Get-Content -Raw 'windows\flutter\generated_plugin_registrant.cc'; $content = $content -replace '(?m)^  FirebaseCorePluginCApiRegisterWithRegistrar\(\r?\n      registry->GetRegistrarForPlugin\(\"FirebaseCorePluginCApi\"\)\);', '  // FirebaseCorePluginCApiRegisterWithRegistrar(  // Excluded - Firebase C++ SDK has linking issues\r\n  //     registry->GetRegistrarForPlugin(\"FirebaseCorePluginCApi\"));'; Set-Content -NoNewline 'windows\flutter\generated_plugin_registrant.cc' $content"
    echo [SUCCESS] Firebase registrar call excluded
)

echo.

REM Build Windows executable
echo ========================================================
echo   Building Windows Executable
echo ========================================================
echo.
echo [INFO] Building release Windows executable...
echo [INFO] Using --no-pub to preserve Firebase exclusion
echo [WARNING] This may take 5-10 minutes on first build...
echo.

call flutter build windows --release --no-pub

if errorlevel 1 (
    echo.
    echo [ERROR] Windows build failed!
    pause
    exit /b 1
)

echo.

REM Verify build output
set BUILD_DIR=build\windows\x64\runner\Release
set EXE_PATH=%BUILD_DIR%\flutter_multiplatform_app.exe

if not exist "%EXE_PATH%" (
    echo [ERROR] Windows build failed - executable not found at: %EXE_PATH%
    pause
    exit /b 1
)

echo [SUCCESS] Windows build complete!
echo.

for %%A in ("%EXE_PATH%") do set EXE_SIZE=%%~zA
set /a EXE_SIZE_KB=!EXE_SIZE!/1024
echo [INFO] Executable: %EXE_PATH% (!EXE_SIZE_KB! KB)
echo.

REM Create ZIP archive
echo [INFO] Creating ZIP archive for distribution...
set ZIP_NAME=tcs-pace-scheduler-v%VERSION_NAME%-build%NEW_BUILD_NUMBER%-windows-x64.zip
set ZIP_PATH=build\windows\x64\runner\!ZIP_NAME!

REM Change to runner directory to create ZIP with correct structure
pushd build\windows\x64\runner
powershell -Command "Compress-Archive -Path 'Release\*' -DestinationPath '!ZIP_NAME!' -Force" >nul 2>&1
popd

if exist "!ZIP_PATH!" (
    for %%A in ("!ZIP_PATH!") do set ZIP_SIZE=%%~zA
    set /a ZIP_SIZE_KB=!ZIP_SIZE!/1024
    set /a ZIP_SIZE_MB=!ZIP_SIZE!/1024/1024
    echo [SUCCESS] ZIP created: !ZIP_PATH! (!ZIP_SIZE_MB! MB)
) else (
    echo [WARNING] Could not create ZIP archive - you can manually ZIP the Release folder
)

REM Summary
echo.
echo ========================================================
echo   Build Summary
echo ========================================================
echo.
echo Version:        %VERSION_NAME%
echo Build Number:   %NEW_BUILD_NUMBER%
echo Full Version:   %NEW_VERSION%
echo.
echo Executable: %EXE_PATH%
echo Distribution folder: %BUILD_DIR% (copy entire folder)
if exist "%ZIP_PATH%" (
    echo ZIP Archive: %ZIP_PATH%
)
echo.
echo WARNING: Firebase excluded (uses local_notifier for notifications)
echo.
echo ========================================================
echo   Build Complete!
echo ========================================================
echo.
echo [INFO] Next steps:
echo   1. Test the executable: %EXE_PATH%
echo   2. Distribute the entire Release folder or ZIP archive
echo   3. Required files for distribution:
echo      - flutter_multiplatform_app.exe (main executable)
echo      - flutter_windows.dll (Flutter runtime)
echo      - data/ folder (app resources)
echo      - Plugin DLLs (*.dll files)
echo.
echo [INFO] Installation:
echo   1. Extract ZIP to any folder
echo   2. Run flutter_multiplatform_app.exe
echo   3. No installation required - portable application
echo.

pause
