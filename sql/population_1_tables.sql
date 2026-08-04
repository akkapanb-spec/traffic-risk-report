-- ============================================================
-- ประชากร อัตราต่อแสนประชากร และตารางสอบทาน - ตาราง (1 ของ 2)
-- ============================================================
-- ต้องรัน blackspot_1_tables.sql มาก่อน (ใช้ bs_settings เก็บเป้าหมาย)
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
-- ถ้าบรรทัดแรกเป็นข้อความไทยลอย ๆ แปลว่า paste ขาดหัว ให้วางใหม่
--
-- เรื่องที่ต้องเข้าใจก่อน: ไฟล์ทะเบียนราษฎรแบ่งข้อมูลเป็นสองส่วน
--   ส่วนบน  อำเภอ -> ตำบล   = ประชากร "นอกเขตเทศบาล"
--   ส่วนล่าง เทศบาล -> ตำบล  = ประชากร "ในเขตเทศบาล"
--   สองส่วนรวมกันจึงเป็นประชากรทั้งหมด (ตรวจแล้วบวกกันได้เท่ายอดจังหวัดพอดี)
-- ตำบลหนึ่งจึงมีได้สองแถว และแบ่งแบบนี้ตรงกับตัวแปร in_municipality
-- ที่ระบบใช้เลือกรัศมี 200 ม. หรือ 500 ม. พอดี
-- ============================================================

-- ============================================================
-- 1) ประชากรตามที่นำเข้าจากไฟล์ - เก็บดิบตามต้นฉบับ ไม่รวบยอดตั้งแต่ตอนนำเข้า
-- ============================================================
create table if not exists pop_rows (
  id              bigserial primary key,
  period_year     int not null,                  -- ปี พ.ศ. ตามที่ระบุในไฟล์
  period_month    int,                           -- เดือนของข้อมูล 1-12
  area_name       text not null,                 -- ชื่อตำบล ไม่มีคำว่า "ตำบล" นำหน้า
  parent_name     text,                          -- ชื่ออำเภอหรือเทศบาลที่แถวนี้อยู่ใต้
  in_municipality boolean not null default false,-- true = แถวจากส่วนเทศบาล
  male            int not null default 0,
  female          int not null default 0,
  total           int not null default 0,
  households      int not null default 0,
  by_age          jsonb,                         -- {"0":{"m":12,"f":9}, ...} เก็บไว้ทำอัตราจำเพาะกลุ่มอายุ
  source          text default 'กรมการปกครอง',
  created_by      text,
  created_at      timestamptz not null default now(),
  unique (period_year, period_month, area_name, parent_name, in_municipality)
);
create index if not exists pop_rows_period_idx on pop_rows (period_year desc, period_month desc);

-- ============================================================
-- 2) จับคู่แถวประชากรเข้ากับพื้นที่บนแผนที่
--    ไฟล์ประชากรแบ่งตามเขตปกครอง แต่ data/tambon_muang.json แบ่ง 7 พื้นที่
--    ซึ่งไม่ตรงกัน เช่น เทศบาลนครฯ กินพื้นที่ ต.ปากน้ำโพทั้งตำบล
--    บวกบางหมู่ของ นครสวรรค์ตก/ออก/วัดไทรย์/แควใหญ่
--    ตารางนี้บอกว่าแถวไหนควรบวกเข้าพื้นที่ไหน แก้ได้จากหน้าเว็บ
-- ============================================================
create table if not exists pop_area_map (
  id           bigserial primary key,
  map_area     text not null,              -- ต้องตรงกับ properties.tambon ใน tambon_muang.json
  source_area  text not null,              -- ชื่อตำบลในไฟล์ประชากร
  source_muni  boolean not null,           -- มาจากส่วนเทศบาลหรือไม่
  unique (map_area, source_area, source_muni)
);

-- ค่าตั้งต้นตามที่ตรวจสอบกับไฟล์ทะเบียนราษฎรแล้ว
-- เทศบาลนครฯ ใช้ยอดรวมของเทศบาลทั้งก้อน จึงจับคู่กับแถวเทศบาลของทุกตำบลที่อยู่ในเขต
insert into pop_area_map(map_area, source_area, source_muni) values
  ('เทศบาลนครนครสวรรค์','ปากน้ำโพ',      true),
  ('เทศบาลนครนครสวรรค์','นครสวรรค์ตก',   true),
  ('เทศบาลนครนครสวรรค์','นครสวรรค์ออก',  true),
  ('เทศบาลนครนครสวรรค์','วัดไทรย์',      true),
  ('เทศบาลนครนครสวรรค์','แควใหญ่',       true),
  ('ตะเคียนเลื่อน','ตะเคียนเลื่อน',      false),
  ('นครสวรรค์ตก','นครสวรรค์ตก',          false),
  ('บ้านแก่ง','บ้านแก่ง',                false),
  ('วัดไทรย์','วัดไทรย์',                false),
  ('หนองกรด','หนองกรด',                  false),
  ('หนองกรด','หนองกรด',                  true),   -- ส่วนที่อยู่ในเขต ทต.หนองเบน
  ('หนองกระโดน','หนองกระโดน',            false),
  ('หนองกระโดน','หนองกระโดน',            true)    -- ส่วนที่อยู่ในเขต ทต.หนองเบน
on conflict (map_area, source_area, source_muni) do nothing;

-- ============================================================
-- 3) ตัวเลขจากแหล่งอื่นไว้สอบทาน
--    ตัวเลขของเราไม่มีทางตรงกับ ThaiRSC หรือ 3 ฐานเป๊ะ เพราะนับคนละจังหวะ
--    (เรานับตอนเกิดเหตุ ThaiRSC นับตอนเคลมสำเร็จ 3 ฐานรวมข้อมูล รพ. ด้วย)
--    ที่ต้องจับตาคือช่องว่างที่กว้างผิดปกติ ซึ่งแปลว่ามีเคสตกหล่น
-- ============================================================
create table if not exists recon_counts (
  id           bigserial primary key,
  period_year  int not null,
  period_month int,                         -- null = ทั้งปี
  map_area     text,                        -- null = ทั้งพื้นที่รับผิดชอบ
  source       text not null,               -- ThaiRSC / 3 ฐาน / สาธารณสุข / อื่นๆ
  deaths       int not null default 0,
  injuries     int,
  checked      boolean not null default false,   -- สอบทานแล้วหรือยัง
  finding      text,                             -- สอบทานแล้วเจออะไร
  entered_by   text,
  updated_at   timestamptz not null default now(),
  unique (period_year, period_month, map_area, source)
);
create index if not exists recon_period_idx on recon_counts (period_year desc, period_month desc);

-- ============================================================
-- 4) เป้าหมายอัตราการเสียชีวิต
--    แผนแม่บทความปลอดภัยทางถนน ตั้งเป้า 12 ต่อประชากรแสนคน ในช่วงปี 2570-2573
-- ============================================================
insert into bs_settings(key, val) values
  ('deathRateTarget',     '12'::jsonb),
  ('deathRateTargetFrom', '2570'::jsonb),
  ('deathRateTargetTo',   '2573'::jsonb)
on conflict (key) do nothing;

-- ============================================================
-- 5) Row Level Security
--    ประชากรและเป้าหมายเป็นข้อมูลเปิด ประชาชนอ่านได้
--    ส่วนตารางสอบทานเป็นข้อมูลระหว่างหน่วยงาน ยังไม่ยืนยัน จึงปิดไว้
-- ============================================================
alter table pop_rows     enable row level security;
alter table pop_area_map enable row level security;
alter table recon_counts enable row level security;

drop policy if exists "public read" on pop_rows;
create policy "public read" on pop_rows for select using (true);

drop policy if exists "public read" on pop_area_map;
create policy "public read" on pop_area_map for select using (true);
-- recon_counts: ไม่สร้าง policy = anon อ่านไม่ได้เลย
