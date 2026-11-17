@echo off
rem Export the web build and publish it to Vercel (see docs/DEPLOYMENT.md).
cd /d "%~dp0"
if not exist build\web mkdir build\web
rem Keep Godot from importing the exported files as project assets.
if not exist build\.gdignore type nul > build\.gdignore
godot_console --headless --path . --export-release "Web" build/web/index.html
if errorlevel 1 (
  echo Export failed. Are the Godot export templates installed? See docs/DEPLOYMENT.md
  pause
  exit /b 1
)
rem Never upload Vercel's local token file (vercel link creates it in this folder).
if exist build\web\.env.local del /q build\web\.env.local
vercel deploy build/web --prod --yes
pause
