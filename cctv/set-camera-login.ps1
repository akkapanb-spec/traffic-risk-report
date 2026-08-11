# ============================================================
# ใส่ชื่อผู้ใช้และรหัสผ่านกล้องลงใน mediamtx.yml
# ============================================================
# รันบนเครื่องเกตเวย์ ในโฟลเดอร์เดียวกับ mediamtx.yml
#
# ทำไมต้องเป็นสคริปต์
#   รหัสผ่านอยู่กลาง URL แบบ rtsp://ชื่อ:รหัส@ไอพี:554/stream1
#   แก้ด้วยมือแล้วพลาดง่ายมาก และถ้ารหัสมีอักขระพิเศษอย่าง @ : / #
#   ต้องแปลงเป็นรหัสแทนก่อน ไม่งั้น URL จะขาดตรงกลางโดยไม่มีอะไรเตือน
#
#   และรหัสที่พิมพ์ตรงนี้จะอยู่แค่ในเครื่องนี้เท่านั้น
# ============================================================

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$yml = Join-Path $PSScriptRoot 'mediamtx.yml'

if (-not (Test-Path $yml)) {
  Write-Host "ไม่พบ mediamtx.yml ในโฟลเดอร์นี้" -ForegroundColor Red
  Read-Host "กด Enter เพื่อปิด"; exit 1
}

$text = Get-Content $yml -Raw

# ---------- แสดงของเดิมแบบปิดบังรหัส ----------
Write-Host ""
Write-Host "=== ที่อยู่กล้องในไฟล์ตอนนี้ ===" -ForegroundColor Cyan
foreach ($m in [regex]::Matches($text, '(?m)^\s*source:\s*(rtsp://\S+)')) {
  # ปิดบังรหัสไว้ ไม่ให้โผล่บนจอเผื่อมีคนมองอยู่ หรือเผื่อถ่ายจอส่งให้ใครดู
  Write-Host ("  " + ($m.Groups[1].Value -replace '://[^@]+@', '://***ปิดบัง***@')) -ForegroundColor Gray
}

# ---------- ถามค่าใหม่ ----------
Write-Host ""
Write-Host "=== ใส่ข้อมูลใหม่ ===" -ForegroundColor Cyan
Write-Host "ดูได้จากแอป Tapo -> ตั้งค่า -> การตั้งค่าขั้นสูง -> บัญชีกล้อง" -ForegroundColor Gray
Write-Host ""

$user = Read-Host "ชื่อผู้ใช้กล้อง"
if ([string]::IsNullOrWhiteSpace($user)) { Write-Host "ไม่ได้ใส่ชื่อผู้ใช้" -ForegroundColor Red; Read-Host; exit 1 }

$sec = Read-Host "รหัสผ่านกล้อง (พิมพ์แล้วจะไม่แสดงบนจอ)" -AsSecureString
$pass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
          [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
if ([string]::IsNullOrWhiteSpace($pass)) { Write-Host "ไม่ได้ใส่รหัสผ่าน" -ForegroundColor Red; Read-Host; exit 1 }

$ipNew = Read-Host "เลข IP ของกล้อง (เว้นว่าง = ใช้ของเดิมในไฟล์)"

# ---------- แปลงอักขระพิเศษ ----------
# รหัสผ่านอยู่กลาง URL อักขระอย่าง @ : / # ? จะไปตัด URL ขาดกลางคัน
# ต้องแปลงเป็นรหัสแทนก่อน เช่น @ กลายเป็น %40
$userEnc = [uri]::EscapeDataString($user)
$passEnc = [uri]::EscapeDataString($pass)

# ---------- สำรองก่อนแก้ ----------
$bak = "$yml.backup-" + (Get-Date -Format 'yyyyMMdd-HHmmss')
Copy-Item $yml $bak
Write-Host ""
Write-Host "สำรองไฟล์เดิมไว้ที่ $(Split-Path $bak -Leaf)" -ForegroundColor Green

# ---------- ซ่อมพอร์ตซ้ำก่อนอย่างอื่น ----------
# เคยเจอในไฟล์จริงว่าเป็น 192.168.1.153:554:554 ซึ่งเป็นที่อยู่ผิดรูป
# MediaMTX จะเปิดไฟล์ไม่ได้เลย และไม่ได้บอกว่าผิดตรงพอร์ต
# ต้องซ่อมก่อน ไม่งั้นการแทนที่ IP ข้างล่างจะหาที่อยู่ไม่เจอแล้วเงียบไป
$fixed = [regex]::Replace($text, '(:\d+)(?::\d+)+(?=/)', '$1')
if ($fixed -ne $text) {
  Write-Host "ซ่อมพอร์ตที่ซ้ำกันในที่อยู่กล้องแล้ว" -ForegroundColor Yellow
  $text = $fixed
}

# ---------- แทนที่เฉพาะส่วนชื่อ:รหัส@ ----------
# ใช้ MatchEvaluator เพื่อไม่ให้อักขระในรหัสถูกตีความเป็นคำสั่ง regex
$text = [regex]::Replace($text, 'rtsp://[^@\s]*@', { param($m) "rtsp://${userEnc}:${passEnc}@" })

# ---------- เปลี่ยน IP ถ้าระบุมา ----------
# ต้องรายงานตามจริงว่าเปลี่ยนได้หรือไม่ได้
# รุ่นก่อนพิมพ์ว่าเปลี่ยนแล้วทุกครั้งแม้หาที่อยู่ไม่เจอ ทำให้เข้าใจผิดว่าแก้แล้ว
if (-not [string]::IsNullOrWhiteSpace($ipNew)) {
  # ดูว่า "หาเจอ" ไม่ใช่ "เปลี่ยนแล้วต่างไหม"
  # ถ้า IP เดิมตรงกับที่ใส่มาอยู่แล้ว ข้อความจะได้ไม่บอกว่าหาไม่เจอทั้งที่เจอ
  if ([regex]::IsMatch($text, '(?<=@)[0-9.]+(?=:\d+/)')) {
    $text = [regex]::Replace($text, '(?<=@)[0-9.]+(?=:\d+/)', $ipNew)
    Write-Host "ตั้งเลข IP เป็น $ipNew แล้ว" -ForegroundColor Green
  } else {
    Write-Host "หาเลข IP ในที่อยู่กล้องไม่เจอ จึงไม่ได้เปลี่ยน (รูปแบบที่อยู่อาจผิด)" -ForegroundColor Yellow
  }
}

# YAML ต้องไม่มี BOM ไม่งั้น MediaMTX เปิดไฟล์ไม่ได้
[System.IO.File]::WriteAllText($yml, $text, (New-Object System.Text.UTF8Encoding $false))
Write-Host "บันทึกไฟล์แล้ว" -ForegroundColor Green

Write-Host ""
Write-Host "=== ที่อยู่กล้องหลังแก้ ===" -ForegroundColor Cyan
foreach ($m in [regex]::Matches($text, '(?m)^\s*source:\s*(rtsp://\S+)')) {
  Write-Host ("  " + ($m.Groups[1].Value -replace '://[^@]+@', '://***ปิดบัง***@')) -ForegroundColor Gray
}

# ---------- รีสตาร์ต ----------
Write-Host ""
Write-Host "=== รีสตาร์ต MediaMTX ===" -ForegroundColor Cyan
if (Get-ScheduledTask -TaskName 'MediaMTX' -ErrorAction SilentlyContinue) {
  Stop-ScheduledTask  -TaskName 'MediaMTX' -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 3
  Start-ScheduledTask -TaskName 'MediaMTX'
} else {
  Get-Process mediamtx -ErrorAction SilentlyContinue | Stop-Process -Force
  Start-Sleep -Seconds 2
  Start-Process (Join-Path $PSScriptRoot 'mediamtx.exe') -WorkingDirectory $PSScriptRoot
}

Start-Sleep -Seconds 5
if (Get-NetTCPConnection -LocalPort 8888 -State Listen -ErrorAction SilentlyContinue) {
  Write-Host "MediaMTX กลับมาทำงานแล้ว" -ForegroundColor Green
  Write-Host ""
  Write-Host "ขั้นต่อไป: เปิดหน้าเจ้าหน้าที่แล้วกดดูกล้อง" -ForegroundColor Cyan
  Write-Host "ถ้ายังไม่ขึ้นภาพ ให้ดูหน้าต่างของ MediaMTX ว่ายังขึ้น 401 อยู่ไหม" -ForegroundColor Gray
  Write-Host "ถ้ายังขึ้น 401 แปลว่ารหัสยังไม่ตรง ให้รันสคริปต์นี้ใหม่" -ForegroundColor Gray
} else {
  Write-Host "MediaMTX ไม่กลับมา" -ForegroundColor Red
  Write-Host ""
  # รันตรง ๆ ให้เห็นว่ามันบ่นอะไร ตอนเป็น Scheduled Task ข้อความพวกนี้หายหมด
  $exe = Join-Path $PSScriptRoot 'mediamtx.exe'
  if (Test-Path $exe) {
    Write-Host "=== ลองรันตรง ๆ เพื่อดูว่ามันบ่นอะไร ===" -ForegroundColor Cyan
    & $exe 2>&1 | Select-Object -First 15
    Write-Host ""
  }
  Write-Host "เอาไฟล์เดิมกลับ:  Copy-Item '$bak' '$yml' -Force" -ForegroundColor Yellow
}
Read-Host "กด Enter เพื่อปิด"
