@echo off
REM ============================================================
REM  Show the current tunnel address from tunnel.log
REM
REM  The free trycloudflare address changes every time the tunnel
REM  restarts, and a scheduled task has no window to read it from.
REM  Double-click this whenever you need the current one.
REM ============================================================
cd /d "%~dp0"

echo.
echo ================================================================
echo   Current tunnel address
echo ================================================================
echo.

if not exist tunnel.log (
  echo   [X] tunnel.log not found.
  echo.
  echo       The tunnel task may not be running yet. Check with:
  echo         Get-ScheduledTask -TaskName CloudflareTunnel
  echo.
  pause
  exit /b 1
)

powershell -NoProfile -Command "$m = Select-String -Path 'tunnel.log' -Pattern 'https://[a-z0-9-]+\.trycloudflare\.com' -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Value } | Select-Object -Last 1; if ($m) { Write-Host ''; Write-Host $m -ForegroundColor Green; Write-Host ''; Write-Host 'Copy this into the officer app:' -ForegroundColor Cyan; Write-Host '  Camera menu -> edit each camera -> gateway address field' -ForegroundColor Gray } else { Write-Host 'No address found in tunnel.log yet - wait a few seconds and try again' -ForegroundColor Yellow }"

echo.
pause
