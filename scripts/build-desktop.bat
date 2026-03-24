@echo off
REM Forge Insight — Build Desktop Target (OpenFL + HaxeUI)
pushd "%~dp0.."
echo Building desktop target...

REM Ensure data directory exists
if not exist "data\meraki-champions.json" (
    echo ERROR: Missing data/meraki-champions.json
    echo Run: node scripts/fetch-data.js
    popd
    exit /b 1
)

lime build project.xml windows
if errorlevel 1 (
    echo FAILED: Desktop build
    popd
    exit /b 1
)

REM Copy data + images next to the executable
set OUTDIR=build\desktop\windows\bin
if exist "%OUTDIR%" (
    if not exist "%OUTDIR%\data" mkdir "%OUTDIR%\data"
    copy /Y data\meraki-champions.json "%OUTDIR%\data\" >nul
    copy /Y data\meraki-items.json "%OUTDIR%\data\" >nul
    copy /Y data\version.txt "%OUTDIR%\data\" >nul
    if exist data\overrides.json copy /Y data\overrides.json "%OUTDIR%\data\" >nul
    if exist "assets\img" (
        xcopy /E /I /Y /Q "assets\img" "%OUTDIR%\img" >nul 2>&1
    )
    if exist "assets\fonts" (
        xcopy /E /I /Y /Q "assets\fonts" "%OUTDIR%\fonts" >nul 2>&1
    )
    echo Data + images + fonts copied to %OUTDIR%
)

echo OK: Desktop build complete
echo Run: %OUTDIR%\ForgeInsight.exe
popd
