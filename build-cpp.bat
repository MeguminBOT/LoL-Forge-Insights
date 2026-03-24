@echo off
REM Forge Insight — Build C++ Native Binary
echo Building C++ target...
if not exist "build\cpp" mkdir "build\cpp"

haxe config/cpp.hxml
if errorlevel 1 (
    echo FAILED: C++ build
    exit /b 1
)

echo OK: C++ native output ready in build/cpp
