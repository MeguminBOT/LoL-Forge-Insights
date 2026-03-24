@echo off
REM Forge Insight — Build and Run Champion Data Generator
pushd "%~dp0.."
echo Building generator tool...
if not exist "build\generate" mkdir "build\generate"

haxe config/generate.hxml
if errorlevel 1 (
    echo FAILED: Generator build
    popd
    exit /b 1
)

echo Running champion data generator...
build\generate\GenerateChampionData.exe
if errorlevel 1 (
    echo FAILED: Generator execution
    popd
    exit /b 1
)

echo OK: Static champion JSON files ready in build/champion-data/
popd
