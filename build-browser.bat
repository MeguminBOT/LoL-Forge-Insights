@echo off
REM Forge Insight — Build Browser Target
echo Building browser target...
if not exist "build\browser" mkdir "build\browser"

haxe config/browser.hxml
if errorlevel 1 (
    echo FAILED: Browser build
    exit /b 1
)

REM Copy index.html into browser output, fixing script path
python -c "from pathlib import Path; s=Path('assets/index.html').read_text(encoding='utf-8'); s=s.replace('../build/browser/forge.js','forge.js'); Path('build/browser/index.html').write_text(s,encoding='utf-8')"
if errorlevel 1 (
    echo WARNING: Could not copy index.html
)

echo OK: build/browser/forge.js + build/browser/index.html
