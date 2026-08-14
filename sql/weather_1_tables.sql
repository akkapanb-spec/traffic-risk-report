-- ============================================================
-- สภาพอากาศกับอุบัติเหตุ — เก็บรายชั่วโมงแยกตามโซนตำบล
-- ============================================================
-- ต้องรัน schema.sql และ officer.sql มาก่อน
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
--
-- คำถามที่ระบบนี้ตอบ
--   "ฝนตกทำให้เกิดอุบัติเหตุมากขึ้นกี่เท่า"
--
-- ทำไมต้องมีตัวหาร ถึงจะตอบได้
--   ถ้านับแค่ว่าอุบัติเหตุกี่เปอร์เซ็นต์เกิดตอนฝนตก จะตีความผิดทันที
--   วัดจริงแล้วนครสวรรค์เดือน ส.ค. ฝนตกไปแล้ว 44.6% ของเวลาทั้งหมด
--   ถ้าอุบัติเหตุ 45% เกิดตอนฝนตก แปลว่าฝน "ไม่ได้" เพิ่มความเสี่ยงเลย
--   ต้องเทียบอัตราต่อชั่วโมง ไม่ใช่สัดส่วนของจำนวนเคส
--
--   จึงต้องเก็บสภาพอากาศ "ทุกชั่วโมง" ไม่ใช่เฉพาะชั่วโมงที่เกิดเหตุ
--
-- ทำไมแบ่งตามตำบล ไม่ใช้จุดเดียวทั้งอำเภอ
--   วัดจริงระหว่างตัวเมืองกับฝั่งตะวันตกที่ห่างกัน 27 กม.
--   ตัดสิน "ฝนตก/แห้ง" ไม่ตรงกัน 430 จาก 2,448 ชั่วโมง = 17.6%
--   ใช้จุดเดียวจะติดป้ายสภาพอากาศผิดราวหนึ่งในหกเคส โดยไม่มีอะไรฟ้อง
--
--   ฝนเขตร้อนตกเป็นหย่อม ปริมาณรวมทั้งฤดูใกล้กัน (526 กับ 490 มม.)
--   แต่ตกคนละชั่วโมงกัน ซึ่งเป็นสิ่งที่มีผลกับการจับคู่รายเคส
--
-- ทำไมให้เบราว์เซอร์ไปดึง ไม่ให้ Postgres ยิงเอง
--   ท่าเดียวกับเครื่องวิเคราะห์จุดเสี่ยง — แอดมินกดดึง แล้วส่งผลมาเก็บ
--   pg_net ยิงแบบไม่รอผลลัพธ์ เอามาเก็บข้อมูลทีละพันแถวไม่ถนัด
--   และการดึงเป็นงานที่ทำนาน ๆ ครั้ง ไม่คุ้มที่จะสร้าง Edge Function มาดูแลเพิ่ม
-- ============================================================

set search_path = public, extensions;

-- ============================================================
-- 1) โซน — จุดตัวแทนของแต่ละตำบล
-- ============================================================
-- grid_lat/grid_lng คือพิกัดที่ Open-Meteo ใช้จริง ซึ่งไม่ตรงกับที่เราขอ
-- เก็บไว้เพื่อความซื่อสัตย์ของข้อมูล จะได้รู้ว่าโซนไหนใช้กริดร่วมกัน
-- วัดแล้ว 7 ตำบลตกลงบน 5 กริด — สามตำบลกลางเมืองใช้กริดเดียวกัน
-- ไม่ใช่ความผิดพลาด แต่แปลว่าฝนแถวนั้นตกเหมือนกันจริง
create table if not exists wx_zones (
  code       text primary key,          -- รหัสตำบล หรือชื่อถ้าไม่มีรหัส
  name       text not null,
  latitude   double precision not null, -- จุดกึ่งกลางตำบลที่เราขอไป
  longitude  double precision not null,
  grid_lat   double precision,          -- จุดกริดที่แหล่งข้อมูลใช้จริง
  grid_lng   double precision,
  enabled    boolean not null default true
);

-- ============================================================
-- 2) สภาพอากาศรายชั่วโมง
-- ============================================================
-- hour เก็บเป็นต้นชั่วโมงตามเวลาไทย
-- primary key กันข้อมูลซ้ำ ดึงทับช่วงเดิมกี่ครั้งก็ได้ ไม่บวกซ้ำ
create table if not exists wx_hourly (
  zone_code    text not null references wx_zones(code) on delete cascade,
  hour         timestamptz not null,
  precip_mm    real,
  weather_code int,
  source       text not null default 'open-meteo',   -- ห้ามผสมแหล่งในการวิเคราะห์เดียว
  primary key (zone_code, hour)
);

create index if not exists wx_hourly_hour_idx on wx_hourly (hour);

alter table wx_zones  enable row level security;
alter table wx_hourly enable row level security;

-- ============================================================
-- 3) ตั้งโซนเริ่มต้น — 7 ตำบล อำเภอเมืองนครสวรรค์
-- ============================================================
-- จุดกึ่งกลางคำนวณจากขอบเขตตำบลในไฟล์ data/tambon_muang.json ที่ใช้วาดแผนที่อยู่แล้ว
insert into wx_zones (code, name, latitude, longitude) values
  ('mueang',       'เทศบาลนครนครสวรรค์', 15.6990, 100.1227),
  ('takhianluean', 'ตะเคียนเลื่อน',       15.6325, 100.0681),
  ('nswtok',       'นครสวรรค์ตก',         15.6827, 100.0746),
  ('bankaeng',     'บ้านแก่ง',            15.7888, 100.0564),
  ('watsai',       'วัดไทรย์',            15.7388, 100.0818),
  ('nongkrot',     'หนองกรด',             15.7245,  99.9972),
  ('nongkradon',   'หนองกระโดน',          15.8054,  99.9656)
on conflict (code) do nothing;

-- ============================================================
-- 4) รายชื่อโซนให้หน้าเว็บเอาไปไล่ดึง
-- ============================================================
create or replace function wx_zone_list(p_token text)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $wx_zone_list$
declare v_err jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;

  return jsonb_build_object('success', true,
    'zones', coalesce((select jsonb_agg(to_jsonb(z) order by z.name) from wx_zones z where z.enabled), '[]'::jsonb),
    'coverage', coalesce((select jsonb_agg(c order by c->>'zone_code') from (
        select jsonb_build_object('zone_code', zone_code, 'hours', count(*),
                 'first', min(hour), 'last', max(hour)) c
          from wx_hourly group by zone_code) q), '[]'::jsonb));
end $wx_zone_list$;

grant execute on function wx_zone_list(text) to anon, authenticated;

-- ============================================================
-- 5) เก็บผลที่เบราว์เซอร์ดึงมา
-- ============================================================
-- p_rows รูปแบบ [{"t":"2026-08-01T00:00","p":0.1,"w":61}, ...]
-- on conflict do update — ดึงทับช่วงเดิมได้ ค่าใหม่แทนค่าเก่า
create or replace function wx_save(p_token text, p_zone text, p_grid_lat double precision,
  p_grid_lng double precision, p_rows jsonb)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $wx_save$
declare v_err jsonb; v_n int;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;

  if not exists (select 1 from wx_zones where code = p_zone) then
    return jsonb_build_object('success', false, 'message', 'ไม่รู้จักโซน ' || coalesce(p_zone,'(ว่าง)'));
  end if;

  update wx_zones set grid_lat = p_grid_lat, grid_lng = p_grid_lng where code = p_zone;

  insert into wx_hourly (zone_code, hour, precip_mm, weather_code)
  select p_zone,
         -- เวลาที่ส่งมาเป็นเวลาไทยแบบไม่มีเขตเวลาติด ต้องบอกให้ชัดว่าคือเวลาไทย
         (r->>'t')::timestamp at time zone 'Asia/Bangkok',
         nullif(r->>'p','')::real,
         nullif(r->>'w','')::int
    from jsonb_array_elements(coalesce(p_rows, '[]'::jsonb)) r
  on conflict (zone_code, hour) do update
     set precip_mm = excluded.precip_mm, weather_code = excluded.weather_code;

  get diagnostics v_n = row_count;
  return jsonb_build_object('success', true, 'saved', v_n,
    'message', 'บันทึก ' || v_n || ' ชั่วโมง');
end $wx_save$;

grant execute on function wx_save(text, text, double precision, double precision, jsonb) to anon, authenticated;

-- ============================================================
-- 6) การวิเคราะห์ — อัตราต่อชั่วโมง ตอนฝนตกเทียบตอนแห้ง
-- ============================================================
-- p_wet_mm  ฝนกี่มิลลิเมตรขึ้นไปถึงนับว่า "ตก"
--           ค่าปริยาย 0.2 เพราะต่ำกว่านั้นเป็นละอองที่ไม่ทำให้ถนนลื่น
--           นับ 0.1 เป็นฝนจะทำให้ชั่วโมงเปียกพองจนอัตราเจือจาง
--
-- อุบัติเหตุจับคู่กับโซนด้วยพิกัด ไม่ใช่ชื่อตำบลที่กรอกไว้
-- เพราะชื่อที่พิมพ์มือมีทั้งเว้นวรรคเกินและสะกดต่างกัน ส่วนพิกัดตรงไปตรงมา
create or replace function wx_stats(p_token text, p_from date default null,
  p_to date default null, p_wet_mm real default 0.2)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $wx_stats$
declare
  v_err jsonb; v_from timestamptz; v_to timestamptz; v_out jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;

  v_from := coalesce(p_from::timestamptz, (select min(hour) from wx_hourly));
  v_to   := coalesce((p_to + 1)::timestamptz, (select max(hour) from wx_hourly) + interval '1 hour');
  if v_from is null then
    return jsonb_build_object('success', false, 'message', 'ยังไม่มีข้อมูลสภาพอากาศ กดดึงข้อมูลก่อน');
  end if;

  with
  -- จับอุบัติเหตุเข้าโซนที่ใกล้ที่สุด แล้วปัดเวลาลงเป็นต้นชั่วโมงแบบเวลาไทย
  acc as (
    select date_trunc('hour', timezone('Asia/Bangkok', a.incident_datetime))
             at time zone 'Asia/Bangkok' as hour,
           (select z.code from wx_zones z where z.enabled
              order by (z.latitude - a.latitude)^2 + (z.longitude - a.longitude)^2
              limit 1) as zone_code
      from accidents a
     where a.latitude is not null and a.longitude is not null
       and a.latitude between 14 and 17 and a.longitude between 99 and 101
       and a.incident_datetime >= v_from and a.incident_datetime < v_to
  ),
  -- ชั่วโมงทั้งหมดในช่วง = ตัวหาร  แยกเปียก/แห้งต่อโซน
  hrs as (
    select h.zone_code, h.hour, coalesce(h.precip_mm, 0) >= p_wet_mm as wet
      from wx_hourly h
     where h.hour >= v_from and h.hour < v_to
  ),
  joined as (
    select h.zone_code, h.wet, count(a.hour) as n_acc
      from hrs h left join acc a on a.zone_code = h.zone_code and a.hour = h.hour
     group by h.zone_code, h.hour, h.wet
  ),
  per_zone as (
    select j.zone_code,
           count(*) filter (where j.wet)                  as wet_hours,
           count(*) filter (where not j.wet)              as dry_hours,
           coalesce(sum(j.n_acc) filter (where j.wet), 0)     as wet_acc,
           coalesce(sum(j.n_acc) filter (where not j.wet), 0) as dry_acc
      from joined j group by j.zone_code
  )
  select jsonb_build_object(
    'success', true,
    'from', v_from, 'to', v_to, 'wet_mm', p_wet_mm,
    'zones', coalesce(jsonb_agg(jsonb_build_object(
        'zone_code', p.zone_code,
        'name', (select name from wx_zones where code = p.zone_code),
        'wet_hours', p.wet_hours, 'dry_hours', p.dry_hours,
        'wet_acc', p.wet_acc, 'dry_acc', p.dry_acc,
        -- อัตราต่อ 1,000 ชั่วโมง ตัวเลขจะได้อ่านง่ายกว่าทศนิยมยาว ๆ
        'wet_rate', case when p.wet_hours > 0 then round((p.wet_acc::numeric / p.wet_hours) * 1000, 2) end,
        'dry_rate', case when p.dry_hours > 0 then round((p.dry_acc::numeric / p.dry_hours) * 1000, 2) end,
        'ratio', case when p.dry_hours > 0 and p.wet_hours > 0 and p.dry_acc > 0
                      then round(((p.wet_acc::numeric / p.wet_hours) / (p.dry_acc::numeric / p.dry_hours)), 2) end
      ) order by p.zone_code), '[]'::jsonb),
    'total', (select jsonb_build_object(
        'wet_hours', sum(wet_hours), 'dry_hours', sum(dry_hours),
        'wet_acc', sum(wet_acc), 'dry_acc', sum(dry_acc),
        'wet_rate', case when sum(wet_hours) > 0 then round((sum(wet_acc)::numeric / sum(wet_hours)) * 1000, 2) end,
        'dry_rate', case when sum(dry_hours) > 0 then round((sum(dry_acc)::numeric / sum(dry_hours)) * 1000, 2) end,
        'ratio', case when sum(dry_hours) > 0 and sum(wet_hours) > 0 and sum(dry_acc) > 0
                      then round(((sum(wet_acc)::numeric / sum(wet_hours)) / (sum(dry_acc)::numeric / sum(dry_hours))), 2) end
      ) from per_zone)
  ) into v_out from per_zone p;

  return v_out;
end $wx_stats$;

grant execute on function wx_stats(text, date, date, real) to anon, authenticated;

-- ============================================================
-- ตรวจผลหลังรัน
-- ============================================================
-- ต้องมี 7 โซน
--   select code, name, latitude, longitude from wx_zones order by name;
--
-- ยังไม่มีข้อมูลรายชั่วโมงจนกว่าจะกดดึงจากหน้าเว็บ
--   select count(*) from wx_hourly;
--
-- หลังดึงแล้ว ดูความครอบคลุมแต่ละโซน
--   select zone_code, count(*) hours, min(hour), max(hour) from wx_hourly group by 1 order by 1;
--
-- ตัวเลขสุดท้ายที่ต้องการ — อ่านที่ ratio
--   ratio > 1 แปลว่าฝนเพิ่มความเสี่ยง เช่น 1.8 = เสี่ยงกว่าตอนแห้ง 1.8 เท่า
--   ratio ใกล้ 1 แปลว่าฝนไม่ได้เพิ่มความเสี่ยง
