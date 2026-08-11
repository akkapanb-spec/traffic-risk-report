@echo off
REM ============================================================
REM  List every mediamtx.yml (including backups) and show the
REM  camera source line from each, so you can tell which file
REM  holds the credentials that actually work.
REM
REM  Double-click this file in the gateway folder.
REM ============================================================
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo.
echo ================================================================
echo   Config files in this folder, newest last
echo ================================================================
echo.

for /f "delims=" %%F in ('dir /b /o:d mediamtx.yml* 2^>nul') do (
  echo ----------------------------------------------------------------
  echo FILE: %%F
  for %%D in ("%%F") do echo SAVED: %%~tD
  echo.
  findstr /n "source:" "%%F"
  echo.
)

echo ================================================================
echo   What to do next
echo ================================================================
echo.
echo   1. Look at the rtsp:// lines above.
echo   2. Find the file whose username and password are the ones
echo      you set most recently in the Tapo app.
echo   3. Test that exact rtsp:// address in VLC first.
echo   4. If VLC shows the picture, tell Claude which file it was.
echo.
echo   mediamtx.yml  is the file MediaMTX actually reads.
echo   The backup-* files are older copies, kept automatically.
echo.
pause
