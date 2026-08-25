-- ============================================================
-- ซ่อมแจ้งเตือนไลน์ที่พังทุก 5 นาที
-- ============================================================
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
-- ถ้ามี $0 ค้างอยู่บรรทัดสุดท้าย ให้ลบทิ้งก่อนกด Run
--
-- ไฟล์นี้ไม่มีวงเล็บปีกกาเลยแม้แต่ตัวเดียว ด้วยเหตุผลเดียวกับไฟล์ที่แล้ว
-- แก้เฉพาะสองฟังก์ชันนี้ ไม่แตะงานตั้งเวลา ตารางเดิมยังเดินต่อตามปกติ
--
-- เจอจากบันทึกของฐานข้อมูล มีสอง error วนซ้ำทุก 5 นาที
--
-- บั๊กที่ 1 — record "d" is not assigned yet
--   ในฟังก์ชันแจ้งผู้เสียชีวิต ผมประกาศตัวแปรชื่อ d ไว้เก็บข้อมูลแต่ละแถว
--   แล้วเผลอตั้งชื่อย่อของตารางว่า d ซ้ำกันในคำสั่งนับจำนวนที่อยู่ก่อนหน้า
--   ฐานข้อมูลจึงเข้าใจว่า d.id หมายถึงตัวแปรที่ยังไม่มีค่า แล้วหยุดทำงานทันที
--   แจ้งเตือนผู้เสียชีวิตจึงไม่เคยส่งได้เลยตั้งแต่วันติดตั้ง
--   แก้โดยเปลี่ยนชื่อย่อตารางเป็น dx ไม่ให้ชนกับตัวแปร
--
-- บั๊กที่ 2 — malformed array literal
--   ในฟังก์ชันแจ้งจุดสะสม บรรทัดอ่านค่าเกณฑ์จากตารางตั้งค่า
--   ใช้เครื่องหมายชี้เส้นทางที่เขียนด้วยปีกกาเปิดปิดติดกันเพื่อบอกว่า "เอาค่าตรงนี้เลย"
--   ปีกกานั้นโดนแทรกแบ็กสแลชตอนติดตั้ง เลยกลายเป็นเส้นทางที่อ่านไม่ออก
--   แก้โดยเปลี่ยนไปใช้ array[]::text[] ซึ่งให้ผลเหมือนกันแต่ไม่มีปีกกา
-- ============================================================

-- ============================================================
-- 1) แจ้งผู้เสียชีวิต — เฉพาะที่เสียชีวิตในที่เกิดเหตุ
-- ============================================================
create or replace function line_send_new_deaths(p_max int default 3)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $lsnd$
declare
  d record; v_sent int := 0; v_skip int := 0; v_left int; v_txt text;
begin
  -- ชื่อย่อ dx ไม่ใช่ d เพราะ d เป็นชื่อตัวแปรที่ประกาศไว้ข้างบนแล้ว
  select count(*) into v_left from deaths dx
   where not exists (select 1 from line_sent s where s.kind = 'death' and s.ref_id = dx.id::text);

  if v_left = 0 then return jsonb_build_object('success', true, 'sent', 0, 'left', 0); end if;

  for d in
    select id, col_g from deaths d2
     where not exists (select 1 from line_sent s where s.kind = 'death' and s.ref_id = d2.id::text)
     order by incident_datetime desc nulls last, id desc
     limit greatest(1, p_max)
  loop
    if coalesce(btrim(d.col_g), '') <> 'เสียชีวิตที่เกิดเหตุ' then
      insert into line_sent (kind, ref_id, target_id, ok, detail)
      values ('death', d.id::text, 'SKIP', true,
              'ไม่ได้เสียชีวิตในที่เกิดเหตุ (' || coalesce(nullif(btrim(d.col_g), ''), 'ไม่ระบุ') || ')')
      on conflict do nothing;
      v_skip := v_skip + 1;
      continue;
    end if;

    v_txt := line_msg_death(d.id);
    if v_txt is not null then
      perform line_broadcast('death', v_txt, d.id::text);
      v_sent := v_sent + 1;
    else
      insert into line_sent (kind, ref_id, target_id, ok, detail)
      values ('death', d.id::text, 'ERROR', false, 'สร้างข้อความไม่ได้')
      on conflict do nothing;
    end if;
  end loop;

  return jsonb_build_object('success', true, 'sent', v_sent, 'skipped', v_skip, 'left', v_left);
end $lsnd$;

revoke execute on function line_send_new_deaths(int) from public, anon, authenticated;

-- ============================================================
-- 2) จุดสะสมอุบัติเหตุรายเดือน
-- ============================================================
create or replace function line_send_hotspots()
returns jsonb
language plpgsql security definer set search_path = public, extensions as $lshs$
declare
  v_from timestamptz;
  v_to   timestamptz;
  v_min  int;
  v_edge float8 := 100.0 / sqrt(3.0);   -- ช่องกว้าง 100 ม. เท่ากับด้านราว 58 ม.
  v_month text;
  v_bounds geometry;
  c record;
  v_txt text;
  v_sent int := 0;
  v_found int := 0;
begin
  -- array[]::text[] คือเส้นทางว่าง ให้ผลเท่ากับปีกกาเปิดปิดติดกัน แต่ไม่มีปีกกา
  v_min := coalesce(
    (select (val #>> array[]::text[])::int from bs_settings where key = 'hotspotMinPerMonth'), 4);
  v_from := date_trunc('month', timezone('Asia/Bangkok', now()));
  v_to   := now();
  v_month := to_char(v_from, 'YYYY-MM');

  create temporary table if not exists tmp_hot_pt (g geometry) on commit drop;
  truncate tmp_hot_pt;

  insert into tmp_hot_pt (g)
  select st_transform(st_setsrid(st_makepoint(a.longitude, a.latitude), 4326), 32647)
  from accidents a
  where a.latitude is not null and a.longitude is not null
    and a.latitude between 14 and 17 and a.longitude between 99 and 101
    and a.incident_datetime >= v_from and a.incident_datetime < v_to;

  if not exists (select 1 from tmp_hot_pt) then
    return jsonb_build_object('success', true, 'month', v_month, 'found', 0, 'sent', 0);
  end if;

  -- index เหมือน geo_density ไม่งั้นช่องเล็กขนาดนี้จะ timeout
  create index if not exists tmp_hot_pt_gix on tmp_hot_pt using gist (g);
  analyze tmp_hot_pt;

  select st_setsrid(st_expand(st_extent(g)::geometry, v_edge * 2), 32647)
    into v_bounds from tmp_hot_pt;

  for c in
    with cells as (select h.geom from st_hexagongrid(v_edge, v_bounds) h),
    agg as (
      select cl.geom, count(*)::int as n
        from cells cl join tmp_hot_pt p on st_intersects(cl.geom, p.g)
       group by cl.geom having count(*) >= v_min
    )
    select a.n,
           st_y(st_transform(st_centroid(a.geom), 4326)) as lat,
           st_x(st_transform(st_centroid(a.geom), 4326)) as lng
      from agg a order by a.n desc
  loop
    v_found := v_found + 1;
    v_txt := array_to_string(array[
      '🔴 จุดสะสมอุบัติเหตุ ประจำเดือน',
      line_thai_date(v_from) || ' ถึงวันนี้',
      '',
      'พบจุดที่เกิดอุบัติเหตุซ้ำในบริเวณเดียวกัน',
      '🔢 ' || c.n || ' ครั้ง ในรัศมีราว 100 เมตร',
      '🗺️ https://www.google.com/maps?q=' || round(c.lat::numeric, 6) || ',' || round(c.lng::numeric, 6),
      '',
      'นับใหม่ทุกวันที่ 1 ของเดือน'
    ], chr(10));

    -- กุญแจกันส่งซ้ำ เดือนบวกพิกัดกลางช่องปัด 4 ตำแหน่ง ราว 11 ม.
    if line_broadcast('hotspot', v_txt,
         v_month || ':' || round(c.lat::numeric, 4) || ',' || round(c.lng::numeric, 4)) > 0 then
      v_sent := v_sent + 1;
    end if;
  end loop;

  return jsonb_build_object('success', true, 'month', v_month,
    'min_per_cell', v_min, 'found', v_found, 'sent', v_sent);
end $lshs$;

revoke execute on function line_send_hotspots() from public, anon, authenticated;

-- ============================================================
-- ตรวจผลหลังรัน
-- ============================================================
-- รอ 5 นาทีให้งานตั้งเวลาเดินหนึ่งรอบ แล้วดูว่ายังมี error อยู่ไหม
-- Supabase > Logs > Postgres Logs แล้วค้นคำว่า not assigned
-- ถ้าไม่เจอแล้ว แปลว่าซ่อมติด
--
-- ระวัง: แจ้งผู้เสียชีวิตจะเริ่มส่งของเก่าที่ค้างอยู่ทันทีที่ซ่อมเสร็จ
-- รอบละไม่เกิน 3 ราย และส่งเฉพาะรายที่เสียชีวิตในที่เกิดเหตุเท่านั้น
-- ถ้าไม่อยากให้ส่งย้อนหลัง ให้ทำเครื่องหมายว่าส่งแล้วก่อน ด้วยคำสั่งนี้
--
--   insert into line_sent (kind, ref_id, target_id, ok, detail)
--   select 'death', id::text, 'SKIP', true, 'ข้ามของเก่าก่อนซ่อม'
--     from deaths where incident_datetime < now() - interval '1 day'
--   on conflict do nothing;
-- ============================================================
