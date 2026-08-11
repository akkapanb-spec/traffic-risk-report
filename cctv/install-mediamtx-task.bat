@echo off
REM ============================================================
REM  Install MediaMTX as a Windows Scheduled Task so the camera
REM  gateway comes back by itself after a reboot.
REM
REM  RIGHT-CLICK this file and choose "Run as administrator".
REM ============================================================
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-mediamtx-task.ps1"
