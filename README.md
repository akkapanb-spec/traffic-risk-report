# ระบบแจ้งข้อมูลจุดเสี่ยงอุบัติเหตุ สภ.เมืองนครสวรรค์

เว็บแจ้งจุดเสี่ยงอุบัติเหตุ + Dashboard สถิติ (ย้ายจาก Google Apps Script)

- **Frontend**: HTML + Tailwind + Chart.js + Leaflet → โฮสต์บน GitHub Pages
- **Database**: Supabase (PostgreSQL)
- **รูปภาพ**: Supabase Storage (bucket `risk-images`)

## โครงสร้าง

| ไฟล์ | หน้าที่ |
|---|---|
| `index.html` | เว็บทั้งหมด (ฟอร์มแจ้ง, ตารางข้อมูล, Dashboard, สถิติผู้เสียชีวิต, แผนที่) |
| `sql/schema.sql` | สร้างตาราง + RLS ใน Supabase |
| `sql/storage.sql` | สร้าง bucket เก็บรูปภาพ + สิทธิ์อัปโหลด |
| `sql/import_data.sql` | นำเข้าข้อมูลเดิมทั้งหมด + สลับ URL รูปเป็น Storage |
| `sql/officer.sql` | ระบบเจ้าหน้าที่: ตาราง officers/sessions + RPC ทั้งหมด + ปิด PII |
| `sql/officers_data.sql` | นำเข้าเจ้าหน้าที่ 50 นายจากชีทลงทะเบียน (อนุมัติสิทธิ์แล้ว) |
| `officer.html` | ระบบบันทึกข้อมูลอุบัติเหตุสำหรับเจ้าหน้าที่ (login + บันทึก + สถิติ + แผนที่) |
| `sync.html` | หน้าผู้ดูแล: ดึงข้อมูลใหม่จากระบบ GAS เดิมมาเทียบ แล้วสร้าง SQL ส่วนต่าง |
| `videos.html` | เพลเยอร์คลิปรณรงค์ ดึงรายการจากโฟลเดอร์ Google Drive อัตโนมัติ (ใส่ API Key เพื่อเล่นในหน้า) |
| `sql/update_public_view.sql` | เพิ่ม recorded_at ใน view สาธารณะ ให้สถิติหน้าแรกนับแบบเดียวกับระบบเดิม |
| `sql/admin.sql` | ระบบผู้ดูแล: ตั้ง admin, เมนูอนุมัติสิทธิ์ในหน้าเว็บ, แก้เบอร์โทร 0 หาย |
| `sql/risk_admin.sql` | RPC จัดการจุดเสี่ยงที่ประชาชนแจ้ง: อัปเดตสถานะ + บันทึกผลการดำเนินการ |
| `sql/risk_link.sql` | เชื่อม 2 ตารางด้วยเลขที่การแจ้ง (risk_id) + RPC แก้ไข/ลบข้อมูลที่ลงผิด |
| `sql/deaths_admin.sql` | หน้า admin บันทึก/แก้ไข/ลบข้อมูลผู้เสียชีวิต + ตั้ง ธนนธ เป็น admin |
| `data/risk_points_clean.csv` | ข้อมูลจุดเสี่ยงที่แปลงพร้อม import แล้ว |
| `MIGRATION_GUIDE.md` | คู่มือ migrate ทีละขั้นตอน |
| `SYNC_PLAN.md` | แผน sync ข้อมูลช่วงเปลี่ยนระบบ |

## ตั้งค่าก่อนใช้งาน

1. รัน `sql/schema.sql` ใน Supabase SQL Editor (สร้างตาราง)
2. รัน `sql/storage.sql` ใน Supabase SQL Editor (สร้างที่เก็บรูป)
3. ค่าเชื่อมต่อ (`SUPABASE_URL`, `SUPABASE_ANON_KEY`) อยู่ใน `APP_CONFIG` ของ `index.html`
