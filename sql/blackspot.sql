-- ============================================================
-- ระบบวิเคราะห์จุดเสี่ยงอุบัติเหตุ (Black Spot / Risk Zone Analysis)
-- รันใน Supabase Dashboard → SQL Editor → New query → Run
--
-- ต้องรัน sql/deaths_admin.sql มาก่อน (ใช้ฟังก์ชัน admin_check_ ร่วมกัน)
--
-- หลักการ:
--   - ตารางนำเข้า (bs_features / bs_incidents) และค่าเกณฑ์ (bs_settings)
--     ให้ admin จัดการผ่าน RPC ที่ตรวจ token
--   - ตัวเครื่องวิเคราะห์อยู่ฝั่งเว็บ (officer.html) เพราะต้องคำนวณเชิงเรขาคณิต
--     (จับกลุ่ม/หา convex hull/วาด polygon) แล้วส่งผลกลับมาเก็บผ่าน bs_publish
--   - ผลลัพธ์ที่เผยแพร่แล้ว (published) เท่านั้นที่หน้าประชาชนอ่านได้
--     ผลที่ยังไม่เผยแพร่ = ฉบับร่าง เห็นเฉพาะ admin
--   - ไม่มี PII ในผลลัพธ์ (มีแต่พิกัด/จำนวน/คะแนน) จึงเปิด public read ได้
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

-- ============================================================
-- RPC — ทั้งหมดตรวจสิทธิ์ admin ด้วย admin_check_ (จาก deaths_admin.sql)
-- ============================================================

-- ดึงข้อมูลทุกอย่างที่หน้า admin ต้องใช้ในครั้งเดียว
create or replace function bs_admin_data(p_token text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb; v_set jsonb; v_feat jsonb; v_inc jsonb; v_sites jsonb; v_zones jsonb; v_run jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;

  select coalesce(jsonb_object_agg(key, val), '{}'::jsonb) into v_set from bs_settings;
  select coalesce(jsonb_agg(to_jsonb(t) order by t.name), '[]'::jsonb) into v_feat from bs_features t;
  select coalesce(jsonb_agg(to_jsonb(t) order by t.occurred_at desc), '[]'::jsonb) into v_inc from bs_incidents t;
  select coalesce(jsonb_agg(to_jsonb(t) order by t.score desc nulls last), '[]'::jsonb) into v_sites from bs_sites t;
  select coalesce(jsonb_agg(to_jsonb(t) order by t.level, t.point_count desc), '[]'::jsonb) into v_zones from bs_zones t;
  select to_jsonb(t) into v_run from bs_runs t order by t.ran_at desc limit 1;

  return jsonb_build_object('success', true, 'settings', v_set, 'features', v_feat,
    'incidents', v_inc, 'sites', v_sites, 'zones', v_zones, 'lastRun', v_run);
end $$;

-- บันทึกค่าเกณฑ์ (ส่งมาเป็น object {key: number})
create or replace function bs_settings_save(p_token text, p_settings jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb; v_user jsonb; k text; v jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  v_user := officer_session_user(p_token);

  for k, v in select * from jsonb_each(coalesce(p_settings, '{}'::jsonb))
  loop
    insert into bs_settings(key, val, updated_at, updated_by)
    values (k, v, now(), v_user->>'policeCode')
    on conflict (key) do update set val = excluded.val, updated_at = now(), updated_by = excluded.updated_by;
  end loop;
  return jsonb_build_object('success', true, 'message', 'บันทึกค่าเกณฑ์แล้ว');
end $$;

-- เพิ่ม/แก้ไขจุดกายภาพเสี่ยง (p_id = null คือเพิ่มใหม่)
create or replace function bs_feature_save(p_token text, p_id bigint, p_row jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb; v_user jsonb; v_id bigint;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  v_user := officer_session_user(p_token);

  if coalesce(p_row->>'name','') = '' then
    return jsonb_build_object('success', false, 'message', 'กรุณากรอกชื่อจุด');
  end if;
  if p_row->>'latitude' is null or p_row->>'longitude' is null then
    return jsonb_build_object('success', false, 'message', 'กรุณาระบุพิกัด');
  end if;

  if p_id is null then
    insert into bs_features(kind, name, road, subdistrict, in_municipality, latitude, longitude, note, created_by)
    values (coalesce(p_row->>'kind','junction'), p_row->>'name', p_row->>'road', p_row->>'subdistrict',
            coalesce((p_row->>'in_municipality')::boolean, false),
            (p_row->>'latitude')::double precision, (p_row->>'longitude')::double precision,
            p_row->>'note', v_user->>'policeCode')
    returning id into v_id;
  else
    update bs_features set
      kind = coalesce(p_row->>'kind', kind),
      name = coalesce(p_row->>'name', name),
      road = p_row->>'road',
      subdistrict = p_row->>'subdistrict',
      in_municipality = coalesce((p_row->>'in_municipality')::boolean, in_municipality),
      latitude = (p_row->>'latitude')::double precision,
      longitude = (p_row->>'longitude')::double precision,
      note = p_row->>'note',
      updated_at = now()
     where id = p_id
    returning id into v_id;
    if v_id is null then return jsonb_build_object('success', false, 'message', 'ไม่พบจุดที่ต้องการแก้ไข'); end if;
  end if;

  return jsonb_build_object('success', true, 'id', v_id, 'message', 'บันทึกจุดกายภาพเสี่ยงแล้ว');
end $$;

create or replace function bs_feature_delete(p_token text, p_id bigint) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  delete from bs_features where id = p_id;
  if not found then return jsonb_build_object('success', false, 'message', 'ไม่พบข้อมูล'); end if;
  return jsonb_build_object('success', true, 'message', 'ลบแล้ว');
end $$;

-- นำเข้าจุดกายภาพเป็นชุด (p_replace = true คือล้างของเดิมก่อน)
create or replace function bs_features_import(p_token text, p_rows jsonb, p_replace boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb; v_user jsonb; r jsonb; v_n int := 0; v_skip int := 0;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  v_user := officer_session_user(p_token);

  if coalesce(p_replace, false) then delete from bs_features; end if;

  for r in select value from jsonb_array_elements(coalesce(p_rows, '[]'::jsonb))
  loop
    if coalesce(r->>'name','') = '' or r->>'latitude' is null or r->>'longitude' is null then
      v_skip := v_skip + 1;
      continue;
    end if;
    insert into bs_features(kind, name, road, subdistrict, in_municipality, latitude, longitude, note, created_by)
    values (coalesce(r->>'kind','junction'), r->>'name', r->>'road', r->>'subdistrict',
            coalesce((r->>'in_municipality')::boolean, false),
            (r->>'latitude')::double precision, (r->>'longitude')::double precision,
            r->>'note', v_user->>'policeCode');
    v_n := v_n + 1;
  end loop;

  return jsonb_build_object('success', true, 'inserted', v_n, 'skipped', v_skip,
    'message', 'นำเข้าแล้ว ' || v_n || ' จุด' || case when v_skip > 0 then ' (ข้าม ' || v_skip || ' แถวที่ข้อมูลไม่ครบ)' else '' end);
end $$;

-- เพิ่ม/แก้ไขจุดเกิดเหตุเพิ่มเติม
create or replace function bs_incident_save(p_token text, p_id bigint, p_row jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb; v_user jsonb; v_id bigint;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  v_user := officer_session_user(p_token);

  if p_row->>'occurred_at' is null then
    return jsonb_build_object('success', false, 'message', 'กรุณาระบุวันเวลาเกิดเหตุ');
  end if;
  if p_row->>'latitude' is null or p_row->>'longitude' is null then
    return jsonb_build_object('success', false, 'message', 'กรุณาระบุพิกัด');
  end if;

  if p_id is null then
    insert into bs_incidents(occurred_at, latitude, longitude, place, road, subdistrict, in_municipality,
      direction, road_character, is_drunk, fatal_count, injury_count, cause, source, note, created_by)
    values ((p_row->>'occurred_at')::timestamptz,
            (p_row->>'latitude')::double precision, (p_row->>'longitude')::double precision,
            p_row->>'place', p_row->>'road', p_row->>'subdistrict',
            coalesce((p_row->>'in_municipality')::boolean, false),
            p_row->>'direction', p_row->>'road_character',
            coalesce((p_row->>'is_drunk')::boolean, false),
            coalesce((p_row->>'fatal_count')::int, 0), coalesce((p_row->>'injury_count')::int, 0),
            p_row->>'cause', p_row->>'source', p_row->>'note', v_user->>'policeCode')
    returning id into v_id;
  else
    update bs_incidents set
      occurred_at = (p_row->>'occurred_at')::timestamptz,
      latitude = (p_row->>'latitude')::double precision,
      longitude = (p_row->>'longitude')::double precision,
      place = p_row->>'place', road = p_row->>'road', subdistrict = p_row->>'subdistrict',
      in_municipality = coalesce((p_row->>'in_municipality')::boolean, in_municipality),
      direction = p_row->>'direction', road_character = p_row->>'road_character',
      is_drunk = coalesce((p_row->>'is_drunk')::boolean, is_drunk),
      fatal_count = coalesce((p_row->>'fatal_count')::int, 0),
      injury_count = coalesce((p_row->>'injury_count')::int, 0),
      cause = p_row->>'cause', source = p_row->>'source', note = p_row->>'note',
      updated_at = now()
     where id = p_id
    returning id into v_id;
    if v_id is null then return jsonb_build_object('success', false, 'message', 'ไม่พบข้อมูลที่ต้องการแก้ไข'); end if;
  end if;

  return jsonb_build_object('success', true, 'id', v_id, 'message', 'บันทึกข้อมูลจุดเกิดเหตุแล้ว');
end $$;

create or replace function bs_incident_delete(p_token text, p_id bigint) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  delete from bs_incidents where id = p_id;
  if not found then return jsonb_build_object('success', false, 'message', 'ไม่พบข้อมูล'); end if;
  return jsonb_build_object('success', true, 'message', 'ลบแล้ว');
end $$;

create or replace function bs_incidents_import(p_token text, p_rows jsonb, p_replace boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb; v_user jsonb; r jsonb; v_n int := 0; v_skip int := 0;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  v_user := officer_session_user(p_token);

  if coalesce(p_replace, false) then delete from bs_incidents; end if;

  for r in select value from jsonb_array_elements(coalesce(p_rows, '[]'::jsonb))
  loop
    if r->>'occurred_at' is null or r->>'latitude' is null or r->>'longitude' is null then
      v_skip := v_skip + 1;
      continue;
    end if;
    begin
      insert into bs_incidents(occurred_at, latitude, longitude, place, road, subdistrict, in_municipality,
        direction, road_character, is_drunk, fatal_count, injury_count, cause, source, note, created_by)
      values ((r->>'occurred_at')::timestamptz,
              (r->>'latitude')::double precision, (r->>'longitude')::double precision,
              r->>'place', r->>'road', r->>'subdistrict',
              coalesce((r->>'in_municipality')::boolean, false),
              r->>'direction', r->>'road_character',
              coalesce((r->>'is_drunk')::boolean, false),
              coalesce((r->>'fatal_count')::int, 0), coalesce((r->>'injury_count')::int, 0),
              r->>'cause', r->>'source', r->>'note', v_user->>'policeCode');
      v_n := v_n + 1;
    exception when others then
      v_skip := v_skip + 1;   -- แถวที่แปลงวันที่/ตัวเลขไม่ผ่าน ข้ามไป ไม่ล้มทั้งชุด
    end;
  end loop;

  return jsonb_build_object('success', true, 'inserted', v_n, 'skipped', v_skip,
    'message', 'นำเข้าแล้ว ' || v_n || ' แถว' || case when v_skip > 0 then ' (ข้าม ' || v_skip || ' แถวที่ข้อมูลไม่ครบ/รูปแบบผิด)' else '' end);
end $$;

-- เพิ่ม/แก้ไขโซนที่ admin วาดเอง (source='manual')
create or replace function bs_zone_save(p_token text, p_id bigint, p_row jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb; v_user jsonb; v_id bigint;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  v_user := officer_session_user(p_token);

  if coalesce(p_row->>'title','') = '' then
    return jsonb_build_object('success', false, 'message', 'กรุณากรอกชื่อโซน');
  end if;
  if jsonb_array_length(coalesce(p_row->'polygon', '[]'::jsonb)) < 3 then
    return jsonb_build_object('success', false, 'message', 'ต้องวาดพื้นที่อย่างน้อย 3 จุด');
  end if;

  if p_id is null then
    insert into bs_zones(source, level, title, polygon, centroid_lat, centroid_lng, note,
                         area_km2, published, created_by)
    values ('manual', coalesce(p_row->>'level','red'), p_row->>'title', p_row->'polygon',
            (p_row->>'centroid_lat')::double precision, (p_row->>'centroid_lng')::double precision,
            p_row->>'note', (p_row->>'area_km2')::numeric,
            coalesce((p_row->>'published')::boolean, false), v_user->>'policeCode')
    returning id into v_id;
  else
    update bs_zones set
      level = coalesce(p_row->>'level', level),
      title = coalesce(p_row->>'title', title),
      polygon = coalesce(p_row->'polygon', polygon),
      centroid_lat = (p_row->>'centroid_lat')::double precision,
      centroid_lng = (p_row->>'centroid_lng')::double precision,
      note = p_row->>'note',
      area_km2 = (p_row->>'area_km2')::numeric,
      published = coalesce((p_row->>'published')::boolean, published),
      updated_at = now()
     where id = p_id and source = 'manual'
    returning id into v_id;
    if v_id is null then return jsonb_build_object('success', false, 'message', 'ไม่พบโซน หรือเป็นโซนที่ระบบสร้างอัตโนมัติ (แก้ไม่ได้)'); end if;
  end if;

  return jsonb_build_object('success', true, 'id', v_id, 'message', 'บันทึกโซนแล้ว');
end $$;

create or replace function bs_zone_delete(p_token text, p_id bigint) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  delete from bs_zones where id = p_id;
  if not found then return jsonb_build_object('success', false, 'message', 'ไม่พบข้อมูล'); end if;
  return jsonb_build_object('success', true, 'message', 'ลบแล้ว');
end $$;

-- เปิด/ปิดการเผยแพร่รายโซน (ใช้กับโซนที่วาดเอง)
create or replace function bs_zone_set_published(p_token text, p_id bigint, p_published boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  update bs_zones set published = coalesce(p_published, false), updated_at = now() where id = p_id;
  if not found then return jsonb_build_object('success', false, 'message', 'ไม่พบข้อมูล'); end if;
  return jsonb_build_object('success', true, 'message', case when p_published then 'เผยแพร่แล้ว' else 'ซ่อนจากหน้าประชาชนแล้ว' end);
end $$;

-- ============================================================
-- บันทึกผลการวิเคราะห์ทั้งชุด
--   - ล้างผลอัตโนมัติของรอบก่อน (source='auto') แล้วใส่ชุดใหม่
--   - โซนที่ admin วาดเอง (source='manual') ไม่ถูกแตะต้อง
--   - p_publish = true คือให้ขึ้นหน้าประชาชนทันที
-- ============================================================
create or replace function bs_publish(p_token text, p_run jsonb, p_sites jsonb, p_zones jsonb, p_publish boolean)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_err jsonb; v_user jsonb; v_run_id bigint; r jsonb;
  v_pub boolean := coalesce(p_publish, false);
  v_start date; v_end date; v_sites int := 0; v_zones int := 0;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  v_user := officer_session_user(p_token);

  v_start := nullif(p_run->>'period_start','')::date;
  v_end   := nullif(p_run->>'period_end','')::date;

  insert into bs_runs(ran_by, as_of, period_start, period_end, settings, totals, published)
  values ((v_user->>'rank') || ' ' || (v_user->>'firstName') || ' ' || (v_user->>'lastName'),
          nullif(p_run->>'as_of','')::date, v_start, v_end,
          p_run->'settings', p_run->'totals', v_pub)
  returning id into v_run_id;

  -- ผลรอบก่อนถูกแทนที่ทั้งหมด (จุดเสี่ยงเป็นภาพรวม ณ รอบวิเคราะห์ ไม่สะสม)
  delete from bs_sites;
  delete from bs_zones where source = 'auto';

  for r in select value from jsonb_array_elements(coalesce(p_sites, '[]'::jsonb))
  loop
    insert into bs_sites(run_id, rule, kind, title, latitude, longitude, road, subdistrict,
      in_municipality, radius_m, acc_count, fatal_count, injury_count, drunk_count, month_count,
      score, level, confirmed, peak, members, period_start, period_end, published)
    values (v_run_id, coalesce(r->>'rule','corridor'), r->>'kind', coalesce(r->>'title','จุดเสี่ยง'),
      (r->>'latitude')::double precision, (r->>'longitude')::double precision,
      r->>'road', r->>'subdistrict', (r->>'in_municipality')::boolean,
      coalesce((r->>'radius_m')::int, 0),
      coalesce((r->>'acc_count')::int, 0), coalesce((r->>'fatal_count')::int, 0),
      coalesce((r->>'injury_count')::int, 0), coalesce((r->>'drunk_count')::int, 0),
      coalesce((r->>'month_count')::int, 0),
      (r->>'score')::numeric, r->>'level', coalesce((r->>'confirmed')::boolean, false),
      r->'peak', r->'members', v_start, v_end, v_pub);
    v_sites := v_sites + 1;
  end loop;

  for r in select value from jsonb_array_elements(coalesce(p_zones, '[]'::jsonb))
  loop
    insert into bs_zones(run_id, source, level, title, polygon, corridor, centroid_lat, centroid_lng,
      point_count, fatal_count, month_count, area_km2, peak, note, period_start, period_end, published, created_by)
    values (v_run_id, 'auto', coalesce(r->>'level','red'), coalesce(r->>'title','โซนเสี่ยง'),
      coalesce(r->'polygon', '[]'::jsonb), r->'corridor',
      (r->>'centroid_lat')::double precision, (r->>'centroid_lng')::double precision,
      coalesce((r->>'point_count')::int, 0), coalesce((r->>'fatal_count')::int, 0),
      coalesce((r->>'month_count')::int, 0), (r->>'area_km2')::numeric,
      r->'peak', r->>'note', v_start, v_end, v_pub,
      (v_user->>'rank') || ' ' || (v_user->>'firstName') || ' ' || (v_user->>'lastName'));
    v_zones := v_zones + 1;
  end loop;

  return jsonb_build_object('success', true, 'runId', v_run_id, 'sites', v_sites, 'zones', v_zones,
    'message', case when v_pub
      then 'บันทึกและเผยแพร่แล้ว — จุดเสี่ยง ' || v_sites || ' จุด, โซน ' || v_zones || ' โซน'
      else 'บันทึกเป็นฉบับร่างแล้ว — จุดเสี่ยง ' || v_sites || ' จุด, โซน ' || v_zones || ' โซน (ยังไม่ขึ้นหน้าประชาชน)' end);
end $$;

-- เผยแพร่/ถอนเผยแพร่ผลรอบล่าสุดทั้งชุด
create or replace function bs_set_published(p_token text, p_published boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb; v_pub boolean := coalesce(p_published, false);
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  update bs_sites set published = v_pub;
  update bs_zones set published = v_pub where source = 'auto';
  update bs_runs set published = v_pub
   where id = (select id from bs_runs order by ran_at desc limit 1);
  return jsonb_build_object('success', true,
    'message', case when v_pub then 'เผยแพร่ผลวิเคราะห์ขึ้นหน้าประชาชนแล้ว' else 'ถอนผลวิเคราะห์ออกจากหน้าประชาชนแล้ว' end);
end $$;

-- ป้องกันการเรียกตรงจากคนทั่วไป (ทุกตัวตรวจ token อยู่แล้ว แต่กันไว้อีกชั้น)
revoke execute on function bs_publish(text, jsonb, jsonb, jsonb, boolean) from public;
revoke execute on function bs_set_published(text, boolean) from public;
grant execute on function bs_publish(text, jsonb, jsonb, jsonb, boolean) to anon, authenticated;
grant execute on function bs_set_published(text, boolean) to anon, authenticated;
