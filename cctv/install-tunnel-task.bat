@echo off
REM ============================================================
REM  Install the Cloudflare tunnel as a Windows Scheduled Task
REM  so it starts by itself and nobody has to keep a window open.
REM
REM  RIGHT-CLICK this file and choose "Run as administrator".
REM  A task that starts before anyone logs in cannot be created
REM  without admin rights.
REM ============================================================
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-tunnel-task.ps1"
