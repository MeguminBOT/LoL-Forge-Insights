@echo off
REM Forge Insight — Build C++ Native Binary
pushd "%~dp0.."
echo Building C++ target...
if not exist "build\cpp" mkdir "build\cpp"

haxe config/cpp.hxml
if errorlevel 1 (
    echo FAILED: C++ build
    popd
    exit /b 1
)

REM Copy image assets next to executable
if exist "assets\img" (
    xcopy /E /I /Y /Q "assets\img" "build\cpp\img" >nul 2>&1
)

REM Copy data files next to executable
if not exist "build\cpp\data" mkdir "build\cpp\data"
if exist "data\meraki-champions.json" copy /Y "data\meraki-champions.json" "build\cpp\data\" >nul 2>&1
if exist "data\meraki-items.json" copy /Y "data\meraki-items.json" "build\cpp\data\" >nul 2>&1
if exist "data\version.txt" copy /Y "data\version.txt" "build\cpp\data\" >nul 2>&1

echo OK: C++ native output ready in build/cpp
popd
