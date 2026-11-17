@echo off
rem Export the web build and publish it to Vercel (see docs/DEPLOYMENT.md).
cd /d "%~dp0"
if not exist build\web mkdir build\web
godot_console --headless --path . --export-release "Web" build/web/index.html
if errorlevel 1 (
  echo Export failed. Are the Godot export templates installed? See docs/DEPLOYMENT.md
  pause
  exit /b 1
)
vercel deploy build/web --prod
pause
