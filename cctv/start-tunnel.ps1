# ============================================================
# เปิด tunnel ให้ดูกล้องจากนอกวงแลนได้
# ============================================================
# ใช้กับเครื่องเกตเวย์เท่านั้น (เครื่องที่รัน MediaMTX)
#
# วิธีใช้ — คลิกขวาที่ไฟล์นี้ แล้วเลือก "Run with PowerShell"
#         หรือเปิด PowerShell ในโฟลเดอร์นี้แล้วพิมพ์  .\start-tunnel.ps1
#
# ทำไมต้องเป็นสคริปต์แทนการพิมพ์คำสั่งเอง
#   แป้นพิมพ์ภาษาไทยวาง : กับ ; ไว้ปุ่มเดียวกัน พิมพ์ URL ผิดง่ายมาก
#   และ error ที่ได้จะไม่บอกว่าผิดตรงไหน สคริปต์นี้พิมพ์ไว้ให้ถูกแล้ว
# ============================================================

$ErrorActionPreference = 'Stop'
$port = 8888

Write-Host "=== ตรวจสิ่งที่ต้องมีก่อน ===" -ForegroundColor Cyan

# ---------- 1. MediaMTX ต้องทำงานอยู่ ----------
# เปิด tunnel ชี้ไปที่ที่ไม่มีอะไรฟังอยู่ จะได้ลิงก์ที่เปิดแล้วขึ้น error
# ตรวจก่อนดีกว่าปล่อยให้ไปงงตอนเปิดลิงก์
$listen = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
if (-not $listen) {
  Write-Host "ไม่พบ MediaMTX ที่พอร์ต $port" -ForegroundColor Red
  Write-Host "เปิด MediaMTX ให้ทำงานก่อน แล้วค่อยรันสคริปต์นี้ใหม่"
  Read-Host "กด Enter เพื่อปิด"
  exit 1
}
Write-Host "MediaMTX ทำงานอยู่ที่พอร์ต $port" -ForegroundColor Green

# ---------- 2. หา cloudflared ----------
# มองสามที่: ใน PATH, ข้าง ๆ สคริปต์นี้, และที่ winget ชอบติดตั้งไว้
$exe = $null
$cmd = Get-Command cloudflared -ErrorAction SilentlyContinue
if ($cmd) { $exe = $cmd.Source }
if (-not $exe) {
  foreach ($p in @(
    (Join-Path $PSScriptRoot 'cloudflared.exe'),
    (Join-Path $PSScriptRoot 'cloudflared-windows-amd64.exe'),
    "$env:ProgramFiles\cloudflared\cloudflared.exe",
    "$env:LOCALAPPDATA\Microsoft\WinGet\Links\cloudflared.exe"
  )) { if (Test-Path $p) { $exe = $p; break } }
}

# ---------- 3. ไม่มีก็โหลดมาวางข้างสคริปต์ ----------
# โหลดตรงจากผู้ผลิต ไม่ต้องพึ่ง winget ซึ่งบางเครื่องไม่มีหรือใช้ไม่ได้
if (-not $exe) {
  Write-Host "ยังไม่มี cloudflared - กำลังดาวน์โหลด..." -ForegroundColor Yellow
  $dest = Join-Path $PSScriptRoot 'cloudflared.exe'
  $url  = 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe'
  try {
    Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
    $exe = $dest
    Write-Host "ดาวน์โหลดเสร็จ" -ForegroundColor Green
  } catch {
    Write-Host "ดาวน์โหลดไม่สำเร็จ: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "โหลดเองได้ที่ https://github.com/cloudflare/cloudflared/releases"
    Write-Host "แล้วเปลี่ยนชื่อไฟล์เป็น cloudflared.exe วางไว้โฟลเดอร์เดียวกับสคริปต์นี้"
    Read-Host "กด Enter เพื่อปิด"
    exit 1
  }
}
Write-Host "ใช้ cloudflared จาก $exe" -ForegroundColor Green

# ---------- 4. เปิด tunnel ----------
Write-Host ""
Write-Host "=== กำลังเปิด tunnel ===" -ForegroundColor Cyan
Write-Host "รอสักครู่ จะมีลิงก์ trycloudflare.com ขึ้นมาด้านล่าง" -ForegroundColor Yellow
Write-Host "อย่าปิดหน้าต่างนี้ ปิดแล้ว tunnel จะดับทันที" -ForegroundColor Yellow
Write-Host ""

# ชี้ไปที่ 127.0.0.1 ไม่ใช่ชื่อเครื่อง เพื่อให้แน่ใจว่าไม่ได้อ้อมออกไปนอกเครื่องแล้ววนกลับ
& $exe tunnel --url "http://127.0.0.1:$port"
