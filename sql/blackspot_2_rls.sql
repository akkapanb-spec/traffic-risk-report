-- ============================================================
-- วิเคราะห์จุดเสี่ยงอุบัติเหตุ - Row Level Security
-- ============================================================
-- ส่วนที่ 2 ของ 4 - รันเรียงตามลำดับใน Supabase SQL Editor
-- ต้องรันส่วนที่ 1 ก่อน
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
-- ถ้าบรรทัดแรกเป็นข้อความไทยลอย ๆ แปลว่า paste ขาดหัว ให้วางใหม่
-- ============================================================

-- ============================================================
-- Row Level Security
-- ============================================================
alter table bs_settings  enable row level security;
alter table bs_features  enable row level security;
alter table bs_incidents enable row level security;
alter table bs_sites     enable row level security;
alter table bs_zones     enable row level security;
alter table bs_runs      enable row level security;

-- หน้าประชาชนอ่านได้: ค่าเกณฑ์ (ใช้เขียนคำอธิบายบนแผนที่), จุดกายภาพ,
-- และผลวิเคราะห์เฉพาะที่ admin กดเผยแพร่แล้วเท่านั้น
drop policy if exists "public read" on bs_settings;
create policy "public read" on bs_settings for select using (true);

drop policy if exists "public read" on bs_features;
create policy "public read" on bs_features for select using (true);

drop policy if exists "public read published" on bs_sites;
create policy "public read published" on bs_sites for select using (published);

drop policy if exists "public read published" on bs_zones;
create policy "public read published" on bs_zones for select using (published);

-- bs_incidents / bs_runs: ไม่สร้าง policy = ปิดการอ่านตรงจาก anon ทั้งหมด
