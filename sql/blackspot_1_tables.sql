-- ============================================================
-- วิเคราะห์จุดเสี่ยงอุบัติเหตุ - ตารางและค่าเกณฑ์
-- ============================================================
-- ส่วนที่ 1 ของ 4 - รันเรียงตามลำดับใน Supabase SQL Editor
-- สร้างตาราง bs_* ทั้ง 6 ตัว index และค่าเกณฑ์ตั้งต้น
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
-- ถ้าบรรทัดแรกเป็นข้อความไทยลอย ๆ แปลว่า paste ขาดหัว ให้วางใหม่
-- ============================================================

-- ============================================================
-- 1) ค่าเกณฑ์การวิเคราะห์ — แก้จากหน้าเว็บได้ ไม่ต้อง deploy ใหม่
-- ============================================================
create table if not exists bs_settings (
  key        text primary key,
  val        jsonb not null,
  updated_at timestamptz not null default now(),
  updated_by text
);

-- ค่าตั้งต้นตามสเปก (insert เฉพาะคีย์ที่ยังไม่มี — รันซ้ำไม่ทับค่าที่ admin ปรับไว้)
insert into bs_settings(key, val) values
  ('blackSpotKm',     '0.10'::jsonb),  -- BLACK_SPOT_DISTANCE  จุดอันตรายทางกายภาพ
  ('redClusterKm',    '1.50'::jsonb),  -- RED_CLUSTER_DISTANCE กลุ่มอุบัติเหตุเมาแล้วขับ
  ('patrolZoneKm',    '2.00'::jsonb),  -- PATROL_ZONE_DISTANCE ขอบเขตวางกำลัง/จุดตรวจ
  ('analysisMonths',  '12'::jsonb),    -- ANALYSIS_WINDOW      แผนที่สีประจำปี
  ('confirmMonths',   '36'::jsonb),    -- CONFIRMATION_WINDOW  ยืนยันพื้นที่เสี่ยงระยะยาว
  ('muniRadiusKm',    '0.20'::jsonb),  -- รัศมีเกณฑ์ข้อ 1/2 ในเขตเทศบาล  (200 ม.)
  ('ruralRadiusKm',   '0.50'::jsonb),  -- รัศมีเกณฑ์ข้อ 1/2 นอกเขตเทศบาล (500 ม.)
  ('detourFactor',    '1.30'::jsonb),  -- ตัวคูณแปลงระยะเส้นตรง → ระยะทางถนนโดยประมาณ
  ('siteMinScore',    '2'::jsonb),     -- คะแนนขั้นต่ำที่ถือว่าเป็นจุดเสี่ยง
  ('fatalWeight',     '2'::jsonb),     -- อุบัติเหตุที่มีผู้เสียชีวิต = กี่คะแนน
  ('redMinPoints',    '3'::jsonb),     -- เมาขับกี่จุดขึ้นไปจึงเป็นโซนแดง
  ('orangeMinPoints', '2'::jsonb),     -- เมาขับกี่จุดขึ้นไปจึงเป็นโซนส้ม
  ('redBufferKm',     '0.20'::jsonb),  -- ระยะกันชนรอบกลุ่ม ตอนวาด polygon โซนแดง
  ('orangeBufferKm',  '0.50'::jsonb)   -- ระยะกันชนรอบกลุ่ม ตอนวาด polygon โซนส้ม
on conflict (key) do nothing;

-- ============================================================
-- 2) จุดกายภาพเสี่ยง (ข้อ 1) — ทางแยก/ทางร่วม/จุดกลับรถ/สะพาน/ทางโค้ง/เนิน/ทางลอด
--    admin ปักหมุดเองบนแผนที่ หรือนำเข้าเป็นชุด
-- ============================================================
create table if not exists bs_features (
  id              bigint generated always as identity primary key,
  kind            text not null,                    -- junction / junction_signal / merge / u_turn / bridge / curve / hill / underpass
  name            text not null,                    -- ชื่อจุด เช่น แยกสวรรค์วิถี-มาตุลี
  road            text,
  subdistrict     text,
  in_municipality boolean not null default false,   -- true = ใช้เกณฑ์ 200 ม. / false = 500 ม.
  latitude        double precision not null,
  longitude       double precision not null,
  note            text,
  created_by      text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index if not exists bs_features_pos_idx on bs_features (latitude, longitude);

-- ============================================================
-- 3) จุดเกิดเหตุเพิ่มเติม — ข้อมูลจากแหล่งอื่นที่ไม่ได้บันทึกผ่านระบบเจ้าหน้าที่
--    (ปิดจาก anon เพราะอาจมีรายละเอียดเคส เข้าถึงผ่าน RPC เท่านั้น)
-- ============================================================
create table if not exists bs_incidents (
  id              bigint generated always as identity primary key,
  occurred_at     timestamptz not null,
  latitude        double precision not null,
  longitude       double precision not null,
  place           text,
  road            text,
  subdistrict     text,
  in_municipality boolean not null default false,
  direction       text,                             -- ทิศทางเดินรถ เช่น ขาเข้าเมือง (ใช้ในเกณฑ์ข้อ 2)
  road_character  text,                             -- ลักษณะทาง ใช้จับเกณฑ์ข้อ 1
  is_drunk        boolean not null default false,   -- เมาแล้วขับ (เกณฑ์ข้อ 3)
  fatal_count     int not null default 0,
  injury_count    int not null default 0,
  cause           text,
  source          text,                             -- ที่มาข้อมูล เช่น ThaiRSC หรือ บันทึกประจำวัน
  note            text,
  created_by      text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index if not exists bs_incidents_time_idx on bs_incidents (occurred_at);

-- ============================================================
-- 4) ผลวิเคราะห์: จุดเสี่ยง (ข้อ 1 + ข้อ 2 + จุดเมาขับข้อ 3)
-- ============================================================
create table if not exists bs_sites (
  id              bigint generated always as identity primary key,
  run_id          bigint,
  rule            text not null,                    -- 'feature' | 'corridor' | 'drunk'
  kind            text,                             -- ชนิดจุดกายภาพ (เฉพาะ rule='feature')
  title           text not null,
  latitude        double precision not null,
  longitude       double precision not null,
  road            text,
  subdistrict     text,
  in_municipality boolean,
  radius_m        int,                              -- รัศมีเกณฑ์ที่ใช้ตัดสินจุดนี้
  acc_count       int not null default 0,
  fatal_count     int not null default 0,
  injury_count    int not null default 0,
  drunk_count     int not null default 0,
  month_count     int not null default 0,           -- จำนวนเหตุที่ตกอยู่ในเดือนที่วิเคราะห์
  score           numeric,
  level           text,                             -- 'watch' | 'risk' | 'high'
  confirmed       boolean not null default false,   -- ยังเสี่ยงอยู่ในหน้าต่าง 36 เดือนด้วย
  peak            jsonb,                            -- {buckets:[...], top:[...]}
  members         jsonb,                            -- id ของเหตุที่ประกอบเป็นจุดนี้
  period_start    date,
  period_end      date,
  published       boolean not null default false,
  created_at      timestamptz not null default now()
);
create index if not exists bs_sites_pub_idx on bs_sites (published, rule);

-- ============================================================
-- 5) โซนพื้นที่ (แดง/ส้ม) + Red Corridor — วาดเป็น polygon บนแผนที่
--    source='auto' มาจากเครื่องวิเคราะห์ / source='manual' admin วาดเอง
-- ============================================================
create table if not exists bs_zones (
  id            bigint generated always as identity primary key,
  run_id        bigint,
  source        text not null default 'auto',       -- 'auto' | 'manual'
  level         text not null,                      -- 'red' | 'orange'
  title         text not null,
  polygon       jsonb not null,                     -- [[lat,lng], ...] ขอบเขตโซน
  corridor      jsonb,                              -- [[lat,lng], ...] เส้นทางเชื่อม (Red Corridor)
  centroid_lat  double precision,
  centroid_lng  double precision,
  point_count   int not null default 0,
  fatal_count   int not null default 0,
  month_count   int not null default 0,
  area_km2      numeric,
  peak          jsonb,
  note          text,
  period_start  date,
  period_end    date,
  published     boolean not null default false,
  created_by    text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index if not exists bs_zones_pub_idx on bs_zones (published, level);

-- ============================================================
-- 6) บันทึกการรันวิเคราะห์
-- ============================================================
create table if not exists bs_runs (
  id           bigint generated always as identity primary key,
  ran_at       timestamptz not null default now(),
  ran_by       text,
  as_of        date,
  period_start date,
  period_end   date,
  settings     jsonb,
  totals       jsonb,
  published    boolean not null default false
);
