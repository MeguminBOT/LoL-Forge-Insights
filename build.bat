@echo off
REM Forge Insight — Build All Targets
echo === Building all targets ===
echo.

call "%~dp0scripts\build-browser.bat"
if errorlevel 1 goto :fail

call "%~dp0scripts\build-desktop.bat"
if errorlevel 1 goto :fail

echo.
echo === All targets built successfully ===
exit /b 0

:fail
echo.
echo === Build failed ===
exit /b 1
