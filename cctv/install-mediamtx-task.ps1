# ============================================================
# ตั้งให้ MediaMTX รันเองตอนเปิดเครื่อง
# ============================================================
# คลิกขวาที่ install-mediamtx-task.bat แล้วเลือก "Run as administrator"
#
# ทำไมต้องมี
#   ตรวจแล้วพบว่าตอนนี้ MediaMTX รันเป็นหน้าต่างธรรมดา ไม่ใช่ Scheduled Task
#   (สคริปต์รีสตาร์ตหางานชื่อ MediaMTX ไม่เจอ จึงเปิด mediamtx.exe ตรง ๆ แทน)
#   ผลคือเครื่องรีบูตแล้วกล้องไม่กลับมา ต้องมีคนมาเปิดหน้าต่างเอง
#   ซึ่งขัดกับความตั้งใจที่จะให้เครื่องนี้เป็นเกตเวย์เปิดตลอด
#
# ตั้งแบบเดียวกับ tunnel — เริ่มตอนเปิดเครื่อง ไม่ต้องรอใครล็อกอิน
# ============================================================

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$taskName = 'MediaMTX'
$exe = Join-Path $PSScriptRoot 'mediamtx.exe'

if (-not (Test-Path $exe)) {
  Write-Host "ไม่พบ mediamtx.exe ในโฟลเดอร์นี้" -ForegroundColor Red
  Write-Host "เอาสคริปต์นี้ไปวางในโฟลเดอร์เดียวกับ mediamtx.exe แล้วรันใหม่"
  Read-Host "กด Enter เพื่อปิด"; exit 1
}

$admin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
         ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
  Write-Host "ต้องรันด้วยสิทธิ์ผู้ดูแล" -ForegroundColor Red
  Write-Host "ปิดหน้าต่างนี้ แล้วคลิกขวาที่ install-mediamtx-task.bat เลือก Run as administrator"
  Read-Host "กด Enter เพื่อปิด"; exit 1
}

# ปิดตัวที่รันเป็นหน้าต่างอยู่ก่อน ไม่งั้นจะแย่งพอร์ตกับตัวที่ Task เปิด
$running = Get-Process mediamtx -ErrorAction SilentlyContinue
if ($running) {
  Write-Host "ปิด mediamtx.exe ที่รันเป็นหน้าต่างอยู่ ($($running.Count) ตัว)" -ForegroundColor Yellow
  $running | Stop-Process -Force
  Start-Sleep -Seconds 2
}

if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
  Write-Host "มีงานชื่อ $taskName อยู่แล้ว - ลบของเดิมก่อน" -ForegroundColor Yellow
  Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

$action  = New-ScheduledTaskAction -Execute $exe -WorkingDirectory $PSScriptRoot
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet `
              -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
              -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) `
              -ExecutionTimeLimit ([TimeSpan]::Zero) `
              -StartWhenAvailable

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
                       -Principal $principal -Settings $settings `
                       -Description 'แปลงสัญญาณกล้องวงจรปิดเป็น HLS ให้หน้าเว็บเล่นได้' | Out-Null

Write-Host "ตั้งงาน $taskName เรียบร้อย" -ForegroundColor Green

Start-ScheduledTask -TaskName $taskName
Start-Sleep -Seconds 6

if (Get-NetTCPConnection -LocalPort 8888 -State Listen -ErrorAction SilentlyContinue) {
  Write-Host "MediaMTX ทำงานแล้ว ฟังที่พอร์ต 8888" -ForegroundColor Green
} else {
  Write-Host "ยังไม่ฟังที่พอร์ต 8888 - รอสักครู่แล้วเช็คใหม่ด้วย" -ForegroundColor Yellow
  Write-Host "  Get-ScheduledTask -TaskName MediaMTX | Select-Object State" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== ตรวจงานทั้งสองตัว ===" -ForegroundColor Cyan
foreach ($t in 'MediaMTX', 'CloudflareTunnel') {
  $s = Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue
  if ($s) { "{0,-18} {1}" -f $t, $s.State } else { "{0,-18} ยังไม่ได้ตั้ง" -f $t }
}

Write-Host ""
Write-Host "ทั้งสองตัวรันเองแล้ว ปิดหน้าต่างดำที่เปิดค้างไว้ได้เลย" -ForegroundColor Green
Write-Host "แล้วดับเบิลคลิก show-tunnel-url.bat เพื่อดูลิงก์ปัจจุบัน" -ForegroundColor Cyan
Read-Host "กด Enter เพื่อปิด"
