# ============================================================
# ตั้งให้ tunnel รันเองเหมือน MediaMTX
# ============================================================
# รันบนเครื่องเกตเวย์ ในโฟลเดอร์เดียวกับ mediamtx.exe
# คลิกขวาที่ install-tunnel-task.bat แล้วเลือก "Run as administrator"
#
# ทำไมต้องมี
#   ตอนนี้ tunnel เปิดด้วยหน้าต่างดำที่ต้องคาไว้ ใครเผลอปิดกล้องดับทั้งระบบ
#   และเพราะ MediaMTX ฟังเฉพาะ 127.0.0.1 แล้ว tunnel จึงเป็นทางเข้าเดียว
#   ปิด tunnel = ดูกล้องไม่ได้เลยแม้แต่จากในวงแลน
#
# สิ่งที่ตั้งให้
#   - เริ่มเองตอนเปิดเครื่อง ไม่ต้องรอใครล็อกอิน
#   - พังแล้วลองใหม่เอง 3 ครั้ง ห่างกันครั้งละ 1 นาที
#   - ไม่มีเพดานเวลา และไม่หยุดเมื่อใช้แบตเตอรี่
# ============================================================

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$taskName = 'CloudflareTunnel'
$port     = 8888

# ---------- หา cloudflared ----------
$exe = $null
foreach ($p in @(
  (Join-Path $PSScriptRoot 'cloudflared.exe'),
  "$env:ProgramFiles\cloudflared\cloudflared.exe",
  "$env:LOCALAPPDATA\Microsoft\WinGet\Links\cloudflared.exe"
)) { if (Test-Path $p) { $exe = $p; break } }
if (-not $exe) {
  $cmd = Get-Command cloudflared -ErrorAction SilentlyContinue
  if ($cmd) { $exe = $cmd.Source }
}
if (-not $exe) {
  Write-Host "ไม่พบ cloudflared.exe" -ForegroundColor Red
  Write-Host "ดับเบิลคลิก start-tunnel.bat หนึ่งครั้งก่อน มันจะดาวน์โหลดให้ แล้วค่อยรันตัวนี้"
  Read-Host "กด Enter เพื่อปิด"; exit 1
}
Write-Host "ใช้ cloudflared จาก $exe" -ForegroundColor Green

# ---------- ต้องมีสิทธิ์ผู้ดูแล ----------
# งานที่เริ่มตอนเปิดเครื่องโดยไม่ต้องรอคนล็อกอิน ต้องตั้งด้วยสิทธิ์ผู้ดูแลเท่านั้น
$admin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
         ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
  Write-Host ""
  Write-Host "ต้องรันด้วยสิทธิ์ผู้ดูแล" -ForegroundColor Red
  Write-Host "ปิดหน้าต่างนี้ แล้วคลิกขวาที่ install-tunnel-task.bat เลือก Run as administrator"
  Read-Host "กด Enter เพื่อปิด"; exit 1
}

# ---------- สร้างงาน ----------
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
  Write-Host "มีงานชื่อ $taskName อยู่แล้ว - ลบของเดิมก่อน" -ForegroundColor Yellow
  Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

# ต้องเขียนล็อกลงไฟล์
# งานที่รันเป็น SYSTEM ไม่มีหน้าจอ ข้อความที่ cloudflared พิมพ์จะหายไปหมด
# รวมถึงลิงก์ trycloudflare ที่ต้องเอาไปใส่ในระบบ ถ้าไม่เขียนลงไฟล์จะหาไม่เจอเลย
$logPath = Join-Path $PSScriptRoot 'tunnel.log'
$action  = New-ScheduledTaskAction -Execute $exe `
             -Argument "tunnel --url http://127.0.0.1:$port --logfile `"$logPath`"" `
             -WorkingDirectory $PSScriptRoot
$trigger = New-ScheduledTaskTrigger -AtStartup

# SYSTEM ทำให้เริ่มได้ตั้งแต่ก่อนมีคนล็อกอิน และไม่ผูกกับบัญชีใคร
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

$settings = New-ScheduledTaskSettingsSet `
              -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
              -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) `
              -ExecutionTimeLimit ([TimeSpan]::Zero) `
              -StartWhenAvailable

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
                       -Principal $principal -Settings $settings `
                       -Description 'เปิด Cloudflare tunnel ให้ดูกล้องจากนอกวงแลน' | Out-Null

Write-Host "ตั้งงาน $taskName เรียบร้อย" -ForegroundColor Green

Start-ScheduledTask -TaskName $taskName
Write-Host "สั่งเริ่มงานแล้ว รอสักครู่..." -ForegroundColor Cyan
Start-Sleep -Seconds 8

$st = (Get-ScheduledTask -TaskName $taskName).State
Write-Host ""
Write-Host "สถานะงาน: $st" -ForegroundColor $(if ($st -eq 'Running') { 'Green' } else { 'Red' })

Write-Host ""
Write-Host "=== เรื่องที่ต้องรู้ ===" -ForegroundColor Cyan
Write-Host "ลิงก์ trycloudflare เปลี่ยนทุกครั้งที่งานนี้เริ่มใหม่" -ForegroundColor Yellow
Write-Host "หาลิงก์ปัจจุบันได้จากคำสั่งนี้" -ForegroundColor Yellow
Write-Host "  Get-Content `"$PSScriptRoot\tunnel.log`" | Select-String trycloudflare | Select-Object -Last 1" -ForegroundColor Gray
Write-Host ""
Write-Host "แก้ให้ลิงก์ไม่เปลี่ยนได้ด้วยการผูกโดเมนของหน่วยกับ Cloudflare" -ForegroundColor Yellow
Read-Host "กด Enter เพื่อปิด"
