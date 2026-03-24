@echo off
REM Forge Insight — Build Offline Target
echo Building offline target...
if not exist "build\offline" mkdir "build\offline"

haxe config/offline.hxml
if errorlevel 1 (
    echo FAILED: Offline build
    exit /b 1
)

REM Copy index.html into offline output, fixing script path
python -c "from pathlib import Path; s=Path('assets/index.html').read_text(encoding='utf-8'); s=s.replace('../build/browser/forge.js','../build/offline/forge-offline.js'); Path('build/offline/index.html').write_text(s,encoding='utf-8')"
if errorlevel 1 (
    echo WARNING: Could not copy index.html
)

echo OK: build/offline/forge-offline.js + build/offline/index.html
