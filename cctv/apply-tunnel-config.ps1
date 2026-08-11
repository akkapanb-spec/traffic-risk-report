# ============================================================
# เปลี่ยนเกตเวย์จาก "กั้นด้วยเลข IP" เป็น "กั้นด้วยการล็อกอินของระบบ"
# ============================================================
# รันบนเครื่องเกตเวย์ ในโฟลเดอร์เดียวกับ mediamtx.yml
#
# ทำไมต้องแก้ด้วยสคริปต์ ไม่แก้ด้วยมือ
#   ไฟล์เดิมมีรหัสผ่านกล้องอยู่ เอาไฟล์ใหม่ไปทับทั้งไฟล์ไม่ได้
#   และการแก้ YAML ด้วยมือพลาดง่ายมาก เว้นวรรคผิดช่องเดียวก็ไม่ทำงาน
#   สคริปต์นี้แก้เฉพาะ 2 จุดที่ต้องแก้ แตะที่อื่นไม่ได้เลย
#
# ทำอะไรบ้าง
#   1. สำรองไฟล์เดิมไว้ก่อนเสมอ
#   2. ให้ MediaMTX ฟังเฉพาะในเครื่อง — ทางเข้าเดียวคือผ่าน tunnel
#   3. เปลี่ยนจากกั้นด้วย IP เป็นถามระบบเจ้าหน้าที่ทุกครั้ง
#   4. รีสตาร์ตแล้วตรวจว่ากลับมาทำงานจริง
# ============================================================

$ErrorActionPreference = 'Stop'
$authUrl = 'https://ftpruljwwsmvipfcedyk.supabase.co/functions/v1/cam-auth'

Set-Location $PSScriptRoot
$yml = Join-Path $PSScriptRoot 'mediamtx.yml'

if (-not (Test-Path $yml)) {
  Write-Host "ไม่พบไฟล์ mediamtx.yml ในโฟลเดอร์นี้" -ForegroundColor Red
  Write-Host "เอาสคริปต์นี้ไปวางในโฟลเดอร์เดียวกับ mediamtx.exe แล้วรันใหม่"
  Read-Host "กด Enter เพื่อปิด"; exit 1
}

# ---------- 1. สำรองก่อนแตะอะไรทั้งสิ้น ----------
$bak = "$yml.backup-" + (Get-Date -Format 'yyyyMMdd-HHmmss')
Copy-Item $yml $bak
Write-Host "สำรองไฟล์เดิมไว้ที่ $bak" -ForegroundColor Green

$text = Get-Content $yml -Raw

# ---------- 2. ให้ฟังเฉพาะในเครื่อง ----------
# ถ้ายังฟังทุกช่องทาง เครื่องอื่นในวงจะยังเข้าตรงได้โดยไม่ผ่านการตรวจสิทธิ์
if ($text -match '(?m)^\s*hlsAddress:\s*.*$') {
  $text = $text -replace '(?m)^\s*hlsAddress:\s*.*$', 'hlsAddress: 127.0.0.1:8888'
  Write-Host "ตั้งให้ฟังเฉพาะ 127.0.0.1:8888 แล้ว" -ForegroundColor Green
} else {
  $text = "hlsAddress: 127.0.0.1:8888`r`n" + $text
  Write-Host "เพิ่ม hlsAddress ให้ใหม่" -ForegroundColor Yellow
}

# ---------- 3. เปลี่ยนวิธีตรวจสิทธิ์ ----------
# ต้องตัดสองก้อนแยกกัน ไม่ใช่ก้อนเดียว
#   authMethod: เป็นบรรทัดเดี่ยว
#   authInternalUsers: เป็นบล็อกที่มีบรรทัดเยื้องตามมาอีกหลายบรรทัด
# เคยเขียนรวบเป็นก้อนเดียวแล้วตัดได้แค่บรรทัดแรก เหลือบล็อกรายชื่อ IP ค้างไว้
# ซึ่งแปลว่ากล้องยังเปิดให้ทุกคนดูอยู่ ทั้งที่ดูเผิน ๆ เหมือนแก้แล้ว
$authBlock = "authMethod: http`r`nauthHTTPAddress: $authUrl`r`n"

# ต้องลบของเดิมให้หมดทุกบรรทัดก่อนใส่ใหม่ รวมถึง authHTTPAddress ด้วย
# รุ่นก่อนลบแต่ authMethod แล้วเติมสองบรรทัดกลับเข้าไป
# รันซ้ำสี่รอบจึงได้ authHTTPAddress สี่บรรทัด แล้ว YAML ก็ปฏิเสธคีย์ซ้ำ
# สคริปต์ที่ผู้ใช้จะรันซ้ำได้ต้องให้ผลเหมือนเดิมทุกครั้ง ไม่ใช่สะสมทับ
$text = [regex]::Replace($text, '(?m)^authMethod:.*\r?\n', '')
$text = [regex]::Replace($text, '(?m)^authHTTPAddress:.*\r?\n', '')
$text = [regex]::Replace($text, '(?m)^authHTTPExclude:.*\r?\n', '')
$text = [regex]::Replace($text, '(?ms)^authInternalUsers:.*?(?=^\S|\z)', '')
$text = $authBlock + $text
Write-Host "เปลี่ยนเป็นถามระบบเจ้าหน้าที่ทุกครั้งแล้ว" -ForegroundColor Green

# ---------- 3.5 ซ่อมช่องว่างที่ขาดหลังเครื่องหมาย : ----------
# YAML บังคับว่าต้องมีช่องว่างหลัง : เสมอ ขาดช่องเดียวอ่านไม่ออกทั้งไฟล์
# และข้อความที่ MediaMTX บ่นก็ไม่ได้บอกว่าขาดช่องว่าง บอกแค่ว่าคีย์แปลก
# ซ่อมเฉพาะคีย์ที่รู้จักแน่ ๆ ไม่ไล่ซ่อมทั้งไฟล์ เพราะ rtsp:// มี : ที่ห้ามแตะ
$before = $text
foreach ($k in 'source', 'sourceOnDemand', 'rtspTransport', 'runOnDemand') {
  $text = [regex]::Replace($text, "(?m)^(\s*$k):(\S)", "`$1: `$2")
}
if ($text -ne $before) {
  Write-Host "ซ่อมช่องว่างที่ขาดหลังเครื่องหมาย : ให้แล้ว" -ForegroundColor Yellow
}

# เตือนถ้ายังเหลือร่องรอยของการกั้นด้วย IP — แปลว่าตัดไม่หมด
if ($text -match 'authInternalUsers') {
  Write-Host ""
  Write-Host "[!] ยังพบ authInternalUsers ค้างอยู่ในไฟล์" -ForegroundColor Red
  Write-Host "    แปลว่าตัดบล็อกเดิมไม่หมด กรุณาส่งไฟล์มาให้ตรวจก่อนใช้งาน" -ForegroundColor Red
  Write-Host "    ไฟล์เดิมยังอยู่ที่ $bak" -ForegroundColor Yellow
  Read-Host "กด Enter เพื่อปิด"; exit 1
}

# ต้องเขียนแบบไม่มี BOM
# Set-Content -Encoding UTF8 บน PowerShell 5.1 ใส่ BOM ให้เสมอ
# แล้วตัวอ่าน YAML ของ MediaMTX จะสะดุดอักขระนั้นจนเปิดไฟล์ไม่ได้
# อาการคือโปรแกรมไม่ยอมสตาร์ต โดยไฟล์ดูปกติทุกอย่างเมื่อเปิดอ่าน
[System.IO.File]::WriteAllText($yml, $text, (New-Object System.Text.UTF8Encoding $false))
Write-Host "บันทึกไฟล์แล้ว (ไม่มี BOM)" -ForegroundColor Green

# ---------- 4. รีสตาร์ต ----------
Write-Host ""
Write-Host "=== รีสตาร์ต MediaMTX ===" -ForegroundColor Cyan
$task = Get-ScheduledTask -TaskName 'MediaMTX' -ErrorAction SilentlyContinue
if ($task) {
  Stop-ScheduledTask  -TaskName 'MediaMTX' -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 3
  Start-ScheduledTask -TaskName 'MediaMTX'
  Write-Host "สั่งรีสตาร์ต Scheduled Task แล้ว" -ForegroundColor Green
} else {
  Get-Process mediamtx -ErrorAction SilentlyContinue | Stop-Process -Force
  Start-Sleep -Seconds 2
  Start-Process (Join-Path $PSScriptRoot 'mediamtx.exe') -WorkingDirectory $PSScriptRoot
  Write-Host "ปิดแล้วเปิด mediamtx.exe ใหม่" -ForegroundColor Green
}

# ---------- 5. ตรวจว่ากลับมาจริง ----------
Start-Sleep -Seconds 4
$ok = $false
foreach ($i in 1..5) {
  if (Get-NetTCPConnection -LocalPort 8888 -State Listen -ErrorAction SilentlyContinue) { $ok = $true; break }
  Start-Sleep -Seconds 2
}

Write-Host ""
if ($ok) {
  Write-Host "MediaMTX กลับมาทำงานแล้ว ฟังที่พอร์ต 8888" -ForegroundColor Green
  Write-Host ""
  Write-Host "ขั้นต่อไป: ดับเบิลคลิก start-tunnel.bat เพื่อเปิด tunnel ใหม่" -ForegroundColor Cyan
} else {
  Write-Host "MediaMTX ไม่กลับมา - ไฟล์ตั้งค่าอาจผิด" -ForegroundColor Red
  Write-Host ""
  # รันตรง ๆ เพื่อให้เห็นข้อความบ่นจริงจาก MediaMTX
  # ตอนรันเป็น Scheduled Task ข้อความพวกนี้จะหายไปหมด ไม่มีใครเห็นสาเหตุ
  $exe = Join-Path $PSScriptRoot 'mediamtx.exe'
  if (Test-Path $exe) {
    Write-Host "=== ลองรันตรง ๆ เพื่อดูว่ามันบ่นอะไร ===" -ForegroundColor Cyan
    & $exe 2>&1 | Select-Object -First 15
    Write-Host ""
  }
  Write-Host "เอาไฟล์เดิมกลับด้วยคำสั่งนี้:" -ForegroundColor Yellow
  Write-Host "  Copy-Item '$bak' '$yml' -Force" -ForegroundColor Yellow
}
Read-Host "กด Enter เพื่อปิด"
