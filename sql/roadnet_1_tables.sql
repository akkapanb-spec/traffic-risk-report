-- ============================================================
-- โครงข่ายถนน - ตาราง (ส่วนที่ 1 ของ 3)
-- ============================================================
-- ต้องรัน blackspot_1..4 ก่อน เพราะต่อยอดตาราง bs_features
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
-- ถ้าบรรทัดแรกเป็นข้อความไทยลอย ๆ แปลว่า paste ขาดหัว ให้วางใหม่
--
-- ทำไมใช้ PostGIS: เกณฑ์ข้อ 1 และ 2 กำหนดให้วัด ระยะทาง ตามถนน
-- ไม่ใช่ระยะเส้นตรง เดิมประมาณด้วยเส้นตรงคูณตัวคูณอ้อม พอมีแนวกลางถนน
-- เก็บเป็น LineString แล้ว ST_LineLocatePoint วัดระยะตามแนวถนนได้จริง
-- ============================================================

create extension if not exists postgis;

-- postgis อาจถูกติดตั้งใน schema extensions ตามค่าเริ่มต้นของ Supabase
-- ใส่ไว้ใน search_path ทั้งตอนสร้างตารางและตอนสร้างฟังก์ชัน
set search_path = public, extensions;

-- ============================================================
-- 1) ถนน - หนึ่งแถวคือถนนหนึ่งสาย
-- ============================================================
create table if not exists rn_roads (
  id              bigserial primary key,
  name            text not null,                    -- ชื่อถนน เน้นชื่อที่ใช้จริงในเขตเทศบาล
  code            text,                             -- หมายเลขทางหลวงหรือรหัสถนน เช่น ทล.1 นว.1120
  highway_type    text,                             -- ทล.แผ่นดิน / ทล.ชนบท / ทล.อปท. / ถนนเทศบาล / ซอย
  subdistrict     text,
  local_authority text,
  in_municipality boolean not null default false,   -- ใช้เลือกรัศมี 200 ม. หรือ 500 ม.
  center_line     geography(LineString, 4326),      -- แนวกลางถนน วาดบนแผนที่
  start_name      text,                             -- จุดเริ่มต้น เช่น สี่แยกสวรรค์วิถี
  end_name        text,                             -- จุดสิ้นสุด
  length_km       numeric(8,3),                     -- คำนวณจาก center_line ไม่ต้องกรอกเอง
  direction_mode  text not null default 'two_way',  -- two_way หรือ one_way
  dir_a_label     text default 'ขาเข้าเมือง',       -- ชื่อทิศทางฝั่ง ก เช่น ขาขึ้น
  dir_b_label     text default 'ขาออกเมือง',        -- ชื่อทิศทางฝั่ง ข เช่น ขาล่อง
  has_median      boolean not null default false,   -- มีเกาะกลางหรือไม่
  lanes           int,
  speed_limit     int,
  note            text,
  created_by      text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index if not exists rn_roads_line_idx on rn_roads using gist (center_line);
create index if not exists rn_roads_name_idx on rn_roads (name);

-- ============================================================
-- 2) ช่วงถนน - ระบบตัดให้อัตโนมัติจาก center_line ไม่ต้องกรอกมือ
--    ความยาวเป้าหมายตั้งได้ที่ bs_settings คีย์ segmentTargetM ค่าเริ่มต้น 200 ม.
-- ============================================================
create table if not exists rn_segments (
  id          bigserial primary key,
  road_id     bigint not null references rn_roads(id) on delete cascade,
  seq         int not null,                          -- ลำดับช่วงจากต้นถนน เริ่มที่ 1
  code        text not null,                         -- รหัสประจำช่วง เช่น TL1-007
  geom        geography(LineString, 4326) not null,
  start_m     numeric(10,1) not null,                -- ระยะสะสมจากต้นถนน ถึงต้นช่วง
  end_m       numeric(10,1) not null,
  length_m    numeric(8,1) not null,
  mid_lat     double precision not null,             -- จุดกึ่งกลางช่วง ใช้ปักหมุดบนแผนที่
  mid_lng     double precision not null,
  acc_count   int not null default 0,                -- เติมโดย rn_refresh_counts
  fatal_count int not null default 0,
  drunk_count int not null default 0,
  created_at  timestamptz not null default now(),
  unique (road_id, seq)
);
create index if not exists rn_segments_geom_idx on rn_segments using gist (geom);
create index if not exists rn_segments_road_idx on rn_segments (road_id, seq);

-- ============================================================
-- 3) ต่อยอด bs_features - จุดกายภาพเสี่ยงเดิม ให้ผูกกับถนนและช่วงถนนได้
--    ไม่สร้างตารางใหม่ เพราะเป็นแนวคิดเดียวกัน จะได้ไม่มีข้อมูลสองที่
-- ============================================================
alter table bs_features add column if not exists road_id    bigint references rn_roads(id) on delete set null;
alter table bs_features add column if not exists segment_id bigint references rn_segments(id) on delete set null;
alter table bs_features add column if not exists offset_m   numeric(10,1);   -- ระยะจากต้นถนน
alter table bs_features add column if not exists direction  text;            -- ใช้ได้กับทิศทางเดียว หรือทั้งสองทิศ
alter table bs_features add column if not exists geom       geography(Point, 4326);
create index if not exists bs_features_geom_idx on bs_features using gist (geom);

-- เติม geom ให้แถวเดิมที่มีแต่ lat/lng
update bs_features
   set geom = st_setsrid(st_makepoint(longitude, latitude), 4326)::geography
 where geom is null and latitude is not null and longitude is not null;

-- ============================================================
-- 4) สถานที่ข้างทางที่ทำให้เสี่ยง - โรงเรียน สถานบันเทิง ตลาด ฯลฯ
--    ผูกกับถนนสายเดียวกับโครงข่าย จะได้ไม่ต้องพิมพ์ชื่อถนนซ้ำ
-- ============================================================
create table if not exists rn_places (
  id              bigserial primary key,
  kind            text not null,                     -- โรงเรียน / สถานบันเทิง / ตลาด / โรงพยาบาล / วัด / สวนสาธารณะ / ห้างสรรพสินค้า / สถานที่ราชการ / โรงงาน / อื่นๆ
  name            text not null,
  road_id         bigint references rn_roads(id) on delete set null,
  segment_id      bigint references rn_segments(id) on delete set null,
  subdistrict     text,
  in_municipality boolean not null default false,
  latitude        double precision not null,
  longitude       double precision not null,
  geom            geography(Point, 4326),
  side            text,                              -- ฝั่งถนน ซ้าย/ขวา/สองฝั่ง
  risk_level      text default 'ปกติ',               -- ปกติ / เฝ้าระวัง / เสี่ยงสูง
  open_hours      text,                              -- ช่วงเวลาที่คนพลุกพล่าน เช่น 07:00-08:30, 15:00-16:30
  student_count   int,                               -- เฉพาะโรงเรียน
  note            text,
  created_by      text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index if not exists rn_places_geom_idx on rn_places using gist (geom);
create index if not exists rn_places_kind_idx on rn_places (kind);

-- geom ให้ตรงกับ lat/lng เสมอ โดยไม่ต้องให้ฝั่งเว็บส่งมา
create or replace function rn_sync_geom() returns trigger
language plpgsql as $$
begin
  new.geom := st_setsrid(st_makepoint(new.longitude, new.latitude), 4326)::geography;
  return new;
end $$;

drop trigger if exists rn_places_geom_trg on rn_places;
create trigger rn_places_geom_trg before insert or update of latitude, longitude
  on rn_places for each row execute function rn_sync_geom();

drop trigger if exists bs_features_geom_trg on bs_features;
create trigger bs_features_geom_trg before insert or update of latitude, longitude
  on bs_features for each row execute function rn_sync_geom();

-- ============================================================
-- 5) ค่าเกณฑ์เพิ่มเติมของโครงข่ายถนน
-- ============================================================
insert into bs_settings(key, val) values
  ('segmentTargetM',  '200'::jsonb),   -- ความยาวช่วงถนนเป้าหมาย 100-250 ม.
  ('snapRadiusM',     '60'::jsonb),    -- ระยะสูงสุดที่ยอมจับจุดเกิดเหตุเข้าช่วงถนน
  ('useRoadDistance', 'true'::jsonb)   -- true = วัดตามแนวถนน, false = กลับไปใช้เส้นตรงคูณตัวคูณอ้อม
on conflict (key) do nothing;

-- ============================================================
-- 6) Row Level Security
--    ประชาชนอ่านโครงข่ายถนนและสถานที่ได้ ไม่มีข้อมูลส่วนบุคคล
-- ============================================================
alter table rn_roads    enable row level security;
alter table rn_segments enable row level security;
alter table rn_places   enable row level security;

drop policy if exists "public read" on rn_roads;
create policy "public read" on rn_roads for select using (true);

drop policy if exists "public read" on rn_segments;
create policy "public read" on rn_segments for select using (true);

drop policy if exists "public read" on rn_places;
create policy "public read" on rn_places for select using (true);
