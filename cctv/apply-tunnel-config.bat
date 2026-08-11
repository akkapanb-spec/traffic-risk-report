@echo off
REM ============================================================
REM  Switch the gateway from IP-allowlist to officer-login auth,
REM  then restart MediaMTX.
REM
REM  Just double-click this file on the gateway PC.
REM  It must sit in the same folder as mediamtx.yml
REM ============================================================
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0apply-tunnel-config.ps1"
