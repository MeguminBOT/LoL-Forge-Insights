@echo off
REM Forge Insight — Build Browser Target
pushd "%~dp0.."
echo Building browser target...
if not exist "build\browser\data" mkdir "build\browser\data"

haxe config/browser.hxml
if errorlevel 1 (
    echo FAILED: Browser build
    popd
    exit /b 1
)

REM Copy index.html into browser output, fixing script path
python -c "from pathlib import Path; s=Path('assets/index.html').read_text(encoding='utf-8'); s=s.replace('../build/browser/',''); Path('build/browser/index.html').write_text(s,encoding='utf-8')"

REM Copy image assets
if exist "assets\img" (
    xcopy /E /I /Y /Q "assets\img" "build\browser\img" >nul 2>&1
)

REM Copy font assets
if exist "assets\fonts" (
    xcopy /E /I /Y /Q "assets\fonts" "build\browser\fonts" >nul 2>&1
)

REM Copy data files
copy /Y data\meraki-champions.json "build\browser\data\" >nul 2>&1
copy /Y data\meraki-items.json "build\browser\data\" >nul 2>&1
copy /Y data\version.txt "build\browser\data\" >nul 2>&1
if exist data\overrides.json copy /Y data\overrides.json "build\browser\data\" >nul 2>&1

echo OK: build/browser/ ready
popd
