@echo off
REM ============================================================
REM  Open a Cloudflare tunnel to the local MediaMTX gateway
REM ============================================================
REM  HOW TO USE:  just double-click this file on the gateway PC
REM
REM  Messages are in English on purpose: .bat files are read with the
REM  console code page, and Thai text there turns to garbage on most
REM  Windows setups. The PowerShell version has the Thai comments.
REM ============================================================
setlocal
cd /d "%~dp0"
set PORT=8888
set EXE=cloudflared.exe

echo.
echo === Step 1: check MediaMTX is listening on port %PORT% ===
REM A tunnel to a dead port gives a working link that shows an error page,
REM which looks like a tunnel problem and wastes time. Check first.
netstat -ano | findstr ":%PORT%" | findstr "LISTENING" >nul
if errorlevel 1 (
  echo.
  echo   [X] Nothing is listening on port %PORT%.
  echo       Start MediaMTX first, then run this again.
  echo.
  pause
  exit /b 1
)
echo   [OK] MediaMTX is running.

echo.
echo === Step 2: find cloudflared ===
if exist "%EXE%" goto haveexe
where cloudflared >nul 2>&1
if not errorlevel 1 (
  set EXE=cloudflared
  goto haveexe
)

echo   Not found - downloading from Cloudflare...
powershell -NoProfile -Command "try { Invoke-WebRequest -Uri 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe' -OutFile 'cloudflared.exe' -UseBasicParsing; exit 0 } catch { exit 1 }"
if errorlevel 1 (
  echo.
  echo   [X] Download failed.
  echo       Get cloudflared-windows-amd64.exe manually from
  echo       https://github.com/cloudflare/cloudflared/releases
  echo       rename it to cloudflared.exe and put it in this folder.
  echo.
  pause
  exit /b 1
)
echo   [OK] Downloaded.

:haveexe
echo.
echo === Step 3: opening tunnel ===
echo   Wait for a line containing  trycloudflare.com  below.
echo   That is the address to send to Claude.
echo.
echo   KEEP THIS WINDOW OPEN - closing it kills the tunnel.
echo.

"%EXE%" tunnel --url http://127.0.0.1:%PORT%

echo.
echo Tunnel stopped.
pause
