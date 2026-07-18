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
| `data/risk_points_clean.csv` | ข้อมูลจุดเสี่ยงที่แปลงพร้อม import แล้ว |
| `MIGRATION_GUIDE.md` | คู่มือ migrate ทีละขั้นตอน |
| `SYNC_PLAN.md` | แผน sync ข้อมูลช่วงเปลี่ยนระบบ |

## ตั้งค่าก่อนใช้งาน

1. รัน `sql/schema.sql` ใน Supabase SQL Editor (สร้างตาราง)
2. รัน `sql/storage.sql` ใน Supabase SQL Editor (สร้างที่เก็บรูป)
3. ค่าเชื่อมต่อ (`SUPABASE_URL`, `SUPABASE_ANON_KEY`) อยู่ใน `APP_CONFIG` ของ `index.html`
