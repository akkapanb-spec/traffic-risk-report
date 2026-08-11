@echo off
REM ============================================================
REM  Put the camera username and password into mediamtx.yml,
REM  then restart MediaMTX.
REM
REM  Double-click this file in the gateway folder.
REM  You will be asked to type the username and password.
REM  They are written only to the local config file.
REM ============================================================
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0set-camera-login.ps1"
