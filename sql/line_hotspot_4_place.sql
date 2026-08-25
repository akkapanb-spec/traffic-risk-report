-- ============================================================
-- เพิ่มชื่อสถานที่ ถนน ลักษณะทาง และตำบล ลงในข้อความแจ้งเตือน
-- ============================================================
-- ต้องรัน line_hotspot_3_top3.sql มาก่อน ไฟล์นี้เขียนทับฟังก์ชันเดิมทั้งตัว
-- ไม่แตะงานตั้งเวลา ไม่เปลี่ยนเกณฑ์ ตารางเดิมยังเดินทุก 5 นาทีตามเดิม
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
-- ถ้ามี $0 ค้างอยู่บรรทัดสุดท้าย ให้ลบทิ้งก่อนกด Run
-- ไฟล์นี้ไม่มีวงเล็บปีกกาเลยแม้แต่ตัวเดียว
--
-- ทำไมต้องมีชื่อ
--   ลิงก์แผนที่บอกได้ว่าอยู่ตรงไหน แต่ต้องกดเปิดก่อนถึงจะรู้
--   คนอ่านในกลุ่มไลน์ส่วนใหญ่อ่านผ่านตาแล้วเลื่อนผ่าน
--   ถ้าเห็นชื่อแยกที่คุ้นเคยตั้งแต่บรรทัดแรก จะรู้ทันทีว่าเกี่ยวกับพื้นที่ตัวเองไหม
--
-- ชื่อมาจากไหน
--   จากข้อมูลที่เจ้าหน้าที่กรอกไว้ในเคสอยู่แล้ว 4 ช่อง
--     สถานที่เกิดเหตุ เช่น แยกอุทยาน หรือ หน้าเรือนจำกลาง
--     ถนน เช่น ถนนรังสิโยทัย
--     ลักษณะทาง เช่น ทางแยก ทางโค้ง จุดกลับรถ
--     ตำบล
--
--   หนึ่งช่องกว้าง 100 เมตรอาจมีหลายเคส ซึ่งอาจกรอกชื่อไม่เหมือนกันเป๊ะ
--   จึงเลือกชื่อที่พบบ่อยที่สุดในช่องนั้น ไม่ใช่หยิบเคสใดเคสหนึ่งมาใช้
--   ถ้าเคสไหนเว้นว่างไว้ จะไม่ถูกนับ และถ้าไม่มีใครกรอกเลยก็ไม่แสดงบรรทัดนั้น
--
--   ผลพลอยได้ที่ตั้งใจ ถ้าเห็นชื่อเพี้ยนหรือว่างบ่อย ๆ แปลว่าการกรอกหน้างานหละหลวม
--   ซึ่งเป็นเรื่องที่ควรรู้อยู่แล้ว
-- ============================================================

create or replace function line_send_hotspots()
returns jsonb
language plpgsql security definer set search_path = public, extensions as $lshs$
declare
  v_from timestamptz;
  v_to   timestamptz;
  v_min  int;
  v_sev  int;
  v_edge float8 := 100.0 / sqrt(3.0);   -- ช่องกว้าง 100 ม. เท่ากับด้านราว 58 ม.
  v_month text;
  v_bounds geometry;
  c record;
  v_txt text;
  v_reason text;
  v_head text;
  v_road text;
  v_sent int := 0;
  v_found int := 0;
  v_lines text[];
  v_sig text;
  v_rank int;
begin
  v_min := coalesce(
    (select (val #>> array[]::text[])::int from bs_settings where key = 'hotspotMinPerMonth'), 3);
  v_sev := coalesce(
    (select (val #>> array[]::text[])::int from bs_settings where key = 'hotspotSevereMinPerMonth'), 2);

  v_from := date_trunc('month', timezone('Asia/Bangkok', now()));
  v_to   := now();
  v_month := to_char(v_from, 'YYYY-MM');

  create temporary table if not exists tmp_hot_pt
    (g geometry, severe boolean, inj int, place text, road text, rchar text, tambon text)
    on commit drop;
  truncate tmp_hot_pt;

  -- แตกผู้เกี่ยวข้องทุกคนออกมาครั้งเดียว แล้วใช้ทั้งนับความรุนแรงและนับผู้บาดเจ็บ
  -- ข้อมูลเก่าบางแถวเก็บผู้โดยสารเป็นวัตถุว่างแทนรายการ ถ้าอ่านตรง ๆ จะพังทันที
  insert into tmp_hot_pt (g, severe, inj, place, road, rchar, tambon)
  select st_transform(st_setsrid(st_makepoint(a.longitude, a.latitude), 4326), 32647),
         coalesce(bool_or(e.v->>'injury' in ('สาหัส', 'เสียชีวิต')), false),
         coalesce(count(*) filter (
           where e.v->>'injury' in ('เล็กน้อย', 'หมดสติ', 'สาหัส', 'เสียชีวิต')), 0)::int,
         nullif(btrim(a.place), ''),
         nullif(btrim(a.road), ''),
         nullif(btrim(a.road_character), ''),
         nullif(btrim(a.subdistrict), '')
  from accidents a
  left join lateral jsonb_array_elements(
         jsonb_build_array(coalesce(a.party1, jsonb_build_object()),
                           coalesce(a.party2, jsonb_build_object()))
         || case when jsonb_typeof(a.party1->'passengers') = 'array'
                 then a.party1->'passengers' else jsonb_build_array() end
         || case when jsonb_typeof(a.party2->'passengers') = 'array'
                 then a.party2->'passengers' else jsonb_build_array() end
       ) as e(v) on true
  where a.latitude is not null and a.longitude is not null
    and a.latitude between 14 and 17 and a.longitude between 99 and 101
    and a.incident_datetime >= v_from and a.incident_datetime < v_to
  group by a.id, a.longitude, a.latitude, a.place, a.road, a.road_character, a.subdistrict;

  if not exists (select 1 from tmp_hot_pt) then
    return jsonb_build_object('success', true, 'month', v_month, 'found', 0, 'sent', 0);
  end if;

  create index if not exists tmp_hot_pt_gix on tmp_hot_pt using gist (g);
  analyze tmp_hot_pt;

  select st_setsrid(st_expand(st_extent(g)::geometry, v_edge * 2), 32647)
    into v_bounds from tmp_hot_pt;

  create temporary table if not exists tmp_hot_cell
    (lat float8, lng float8, n int, sev int, injured int,
     place text, road text, rchar text, tambon text) on commit drop;
  truncate tmp_hot_cell;

  -- ชื่อที่พบบ่อยที่สุดในช่อง คิดทีละช่องด้วยการนับแล้วเรียง
  -- เขียนแบบนี้แทนการใช้ mode เพราะอ่านออกว่าทำอะไร และไม่ต้องเดาว่ามันจัดการค่าว่างยังไง
  insert into tmp_hot_cell (lat, lng, n, sev, injured, place, road, rchar, tambon)
  with cells as (select h.geom from st_hexagongrid(v_edge, v_bounds) h),
  agg as (
    select cl.geom,
           count(*)::int as n,
           count(*) filter (where p.severe)::int as sev,
           coalesce(sum(p.inj), 0)::int as injured
      from cells cl join tmp_hot_pt p on st_intersects(cl.geom, p.g)
     group by cl.geom
  )
  select st_y(st_transform(st_centroid(a.geom), 4326)),
         st_x(st_transform(st_centroid(a.geom), 4326)),
         a.n, a.sev, a.injured,
         (select p.place from tmp_hot_pt p
           where st_intersects(a.geom, p.g) and p.place is not null
           group by p.place order by count(*) desc, p.place limit 1),
         (select p.road from tmp_hot_pt p
           where st_intersects(a.geom, p.g) and p.road is not null
           group by p.road order by count(*) desc, p.road limit 1),
         (select p.rchar from tmp_hot_pt p
           where st_intersects(a.geom, p.g) and p.rchar is not null
           group by p.rchar order by count(*) desc, p.rchar limit 1),
         (select p.tambon from tmp_hot_pt p
           where st_intersects(a.geom, p.g) and p.tambon is not null
           group by p.tambon order by count(*) desc, p.tambon limit 1)
    from agg a;

  -- ============ ส่วนที่ 1 แจ้งรายจุดที่ถึงเกณฑ์ ============
  for c in
    select * from tmp_hot_cell
     where n >= v_min or sev >= v_sev
     order by n desc, injured desc
  loop
    v_found := v_found + 1;

    v_reason := case
      when c.sev >= v_sev and c.n >= v_min then 'ถึงเกณฑ์ทั้งจำนวนครั้งและความรุนแรง'
      when c.sev >= v_sev then 'ถึงเกณฑ์ความรุนแรง'
      else 'ถึงเกณฑ์จำนวนครั้ง' end;

    -- ไม่มีชื่อก็ไม่ต้องแสดงบรรทัดเปล่า บอกตรง ๆ ว่าไม่ได้ระบุ ดีกว่าเว้นว่างให้งง
    v_head := coalesce(c.place, 'ไม่ได้ระบุชื่อสถานที่')
              || case when c.rchar is not null then ' · ' || c.rchar else '' end;
    v_road := case when c.road is not null then c.road else '' end
              || case when c.tambon is not null then
                   case when c.road is not null then ' · ' else '' end || 'ต.' || c.tambon
                 else '' end;

    v_txt := array_to_string(array[
      '🔴 จุดเกิดอุบัติเหตุซ้ำ ประจำเดือน',
      line_thai_date(v_from) || ' ถึงวันนี้',
      '',
      '📍 ' || v_head
    ]
    || case when v_road <> '' then array['🛣️ ' || v_road] else array[]::text[] end
    || array[
      '🔢 รวม ' || c.n || ' ครั้ง · ผู้บาดเจ็บ ' || c.injured || ' ราย',
      '🩸 สาหัสหรือเสียชีวิต ' || c.sev || ' ครั้ง',
      '⚖️ ' || v_reason,
      '🗺️ https://www.google.com/maps?q=' || round(c.lat::numeric, 6) || ',' || round(c.lng::numeric, 6),
      '',
      'ในรัศมีราว 100 เมตร · นับใหม่ทุกวันที่ 1 ของเดือน'
    ], chr(10));

    if line_broadcast('hotspot', v_txt,
         v_month || ':' || round(c.lat::numeric, 4) || ',' || round(c.lng::numeric, 4)
         || ':' || c.n::text || '/' || c.sev::text) > 0 then
      v_sent := v_sent + 1;
    end if;
  end loop;

  -- ============ ส่วนที่ 2 สรุป 3 อันดับแรกของเดือน ============
  v_lines := array[
    '📊 สรุปจุดเสี่ยงซ้ำ ประจำเดือน',
    line_thai_date(v_from) || ' ถึงวันนี้',
    ''
  ];
  v_sig := '';
  v_rank := 0;

  for c in
    select * from tmp_hot_cell
     where n >= 2
     order by n desc, injured desc, lat, lng
     limit 3
  loop
    v_rank := v_rank + 1;
    v_head := coalesce(c.place, c.road, 'ไม่ได้ระบุชื่อสถานที่')
              || case when c.rchar is not null then ' · ' || c.rchar else '' end;
    v_road := case when c.road is not null and c.place is not null then c.road else '' end
              || case when c.tambon is not null then
                   case when c.road is not null and c.place is not null then ' · ' else '' end
                   || 'ต.' || c.tambon
                 else '' end;

    v_lines := v_lines || array[v_rank || '. ' || v_head]
      || case when v_road <> '' then array['   ' || v_road] else array[]::text[] end
      || array[
        '   ' || c.n || ' ครั้ง · บาดเจ็บ ' || c.injured || ' ราย'
          || case when c.sev > 0 then ' · สาหัสหรือเสียชีวิต ' || c.sev || ' ครั้ง' else '' end,
        '   🗺️ https://www.google.com/maps?q=' || round(c.lat::numeric, 6) || ',' || round(c.lng::numeric, 6),
        ''
      ];
    v_sig := v_sig || round(c.lat::numeric, 4) || ',' || round(c.lng::numeric, 4)
             || '=' || c.n::text || '/' || c.injured::text || ';';
  end loop;

  if v_rank > 0 then
    v_lines := v_lines || array['เรียงตามจำนวนครั้ง เท่ากันตัดสินด้วยจำนวนผู้บาดเจ็บ'];
    if line_broadcast('hotspot', array_to_string(v_lines, chr(10)),
         v_month || ':top3:' || v_sig) > 0 then
      v_sent := v_sent + 1;
    end if;
  end if;

  return jsonb_build_object('success', true, 'month', v_month,
    'min_per_cell', v_min, 'severe_min', v_sev,
    'found', v_found, 'ranked', v_rank, 'sent', v_sent);
end $lshs$;

revoke execute on function line_send_hotspots() from public, anon, authenticated;

-- ============================================================
-- ตรวจผลหลังรัน
-- ============================================================
-- ดูว่าชื่อสถานที่ในเดือนนี้กรอกกันครบแค่ไหน ถ้าว่างเยอะ ข้อความจะขึ้นว่าไม่ได้ระบุ
--   select count(*) as ทั้งหมด,
--          count(nullif(btrim(place), '')) as มีชื่อสถานที่,
--          count(nullif(btrim(road), '')) as มีชื่อถนน,
--          count(nullif(btrim(road_character), '')) as มีลักษณะทาง
--     from accidents
--    where incident_datetime >= date_trunc('month', timezone('Asia/Bangkok', now()));
--
-- *** ระวัง: คำสั่งข้างล่างส่งเข้าไลน์จริง ไม่ใช่การทดลอง ***
--   select line_send_hotspots();
-- ============================================================
