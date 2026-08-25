-- ============================================================
-- เพิ่มข้อความสรุป 3 อันดับแรกของเดือน พร้อมลิงก์แผนที่
-- ============================================================
-- ต้องรัน line_hotspot_2_severity.sql มาก่อน ไฟล์นี้เขียนทับฟังก์ชันเดิมทั้งตัว
-- ไม่แตะงานตั้งเวลา ตารางเดิมยังเดินทุก 5 นาทีตามเดิม
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
-- ถ้ามี $0 ค้างอยู่บรรทัดสุดท้าย ให้ลบทิ้งก่อนกด Run
-- ไฟล์นี้ไม่มีวงเล็บปีกกาเลยแม้แต่ตัวเดียว
--
-- สิ่งที่เพิ่มจากไฟล์ที่แล้ว
--
--   1) นับจำนวนผู้บาดเจ็บเป็นราย ไม่ใช่นับเป็นครั้ง
--      เคสหนึ่งอาจมีคนเจ็บคนเดียวหรือเจ็บห้าคน ซึ่งหนักไม่เท่ากัน
--      นับทุกคนที่มีอาการตั้งแต่เล็กน้อยขึ้นไป รวมผู้เสียชีวิตด้วย
--      ทั้งคู่กรณีสองฝ่ายและผู้โดยสารทุกคน
--
--   2) ข้อความสรุป 3 อันดับแรกของเดือน ส่งเพิ่มจากการแจ้งรายจุด
--      เรียงตามจำนวนครั้ง ถ้าเท่ากันตัดสินด้วยจำนวนผู้บาดเจ็บ
--      เอาเฉพาะจุดที่เกิดตั้งแต่ 2 ครั้งขึ้นไป จุดที่เกิดครั้งเดียวไม่ใช่จุดซ้ำ
--
--      ทำไมต้องมีสรุปทั้งที่แจ้งรายจุดอยู่แล้ว
--      การแจ้งรายจุดบอกว่า "ตรงนี้ถึงเกณฑ์แล้ว" ซึ่งดีสำหรับสั่งการเฉพาะหน้า
--      แต่ไม่ได้บอกว่าเดือนนี้ที่ไหนหนักที่สุด ซึ่งเป็นคนละคำถาม
--      คนวางแผนกำลังพลต้องการอันหลัง คนที่อยู่หน้างานต้องการอันแรก
--
--   3) กันส่งซ้ำของข้อความสรุป ใช้ลายเซ็นของอันดับทั้งสามเป็นกุญแจ
--      อันดับไม่ขยับก็เงียบ พอมีจุดใดขยับหรือสลับอันดับจึงส่งใหม่
--      จึงไม่เด้งทุก 5 นาที แต่ก็ไม่พลาดตอนสถานการณ์เปลี่ยน
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

  create temporary table if not exists tmp_hot_pt (g geometry, severe boolean, inj int)
    on commit drop;
  truncate tmp_hot_pt;

  -- แตกผู้เกี่ยวข้องทุกคนออกมาครั้งเดียว แล้วใช้ทั้งนับความรุนแรงและนับผู้บาดเจ็บ
  -- ข้อมูลเก่าบางแถวเก็บผู้โดยสารเป็นวัตถุว่างแทนรายการ ถ้าอ่านตรง ๆ จะพังทันที
  -- จึงตรวจชนิดข้อมูลก่อนทุกครั้ง
  insert into tmp_hot_pt (g, severe, inj)
  select st_transform(st_setsrid(st_makepoint(a.longitude, a.latitude), 4326), 32647),
         coalesce(bool_or(e.v->>'injury' in ('สาหัส', 'เสียชีวิต')), false),
         coalesce(count(*) filter (
           where e.v->>'injury' in ('เล็กน้อย', 'หมดสติ', 'สาหัส', 'เสียชีวิต')), 0)::int
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
  group by a.id, a.longitude, a.latitude;

  if not exists (select 1 from tmp_hot_pt) then
    return jsonb_build_object('success', true, 'month', v_month, 'found', 0, 'sent', 0);
  end if;

  create index if not exists tmp_hot_pt_gix on tmp_hot_pt using gist (g);
  analyze tmp_hot_pt;

  select st_setsrid(st_expand(st_extent(g)::geometry, v_edge * 2), 32647)
    into v_bounds from tmp_hot_pt;

  -- สรุปรายช่องเก็บไว้ก่อน เพราะต้องใช้สองรอบ ทั้งแจ้งรายจุดและจัดอันดับ
  create temporary table if not exists tmp_hot_cell
    (lat float8, lng float8, n int, sev int, injured int) on commit drop;
  truncate tmp_hot_cell;

  insert into tmp_hot_cell (lat, lng, n, sev, injured)
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
         a.n, a.sev, a.injured
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

    v_txt := array_to_string(array[
      '🔴 จุดเกิดอุบัติเหตุซ้ำ ประจำเดือน',
      line_thai_date(v_from) || ' ถึงวันนี้',
      '',
      '📍 ในรัศมีราว 100 เมตร',
      '🔢 รวม ' || c.n || ' ครั้ง · ผู้บาดเจ็บ ' || c.injured || ' ราย',
      '🩸 สาหัสหรือเสียชีวิต ' || c.sev || ' ครั้ง',
      '⚖️ ' || v_reason,
      '🗺️ https://www.google.com/maps?q=' || round(c.lat::numeric, 6) || ',' || round(c.lng::numeric, 6),
      '',
      'นับใหม่ทุกวันที่ 1 ของเดือน'
    ], chr(10));

    if line_broadcast('hotspot', v_txt,
         v_month || ':' || round(c.lat::numeric, 4) || ',' || round(c.lng::numeric, 4)
         || ':' || c.n::text || '/' || c.sev::text) > 0 then
      v_sent := v_sent + 1;
    end if;
  end loop;

  -- ============ ส่วนที่ 2 สรุป 3 อันดับแรกของเดือน ============
  v_lines := array[
    '📊 สรุปจุดเสี่ยงซ้ำ 3 อันดับ ประจำเดือน',
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
    v_lines := v_lines || array[
      'อันดับ ' || v_rank || ' · ' || c.n || ' ครั้ง · บาดเจ็บ ' || c.injured || ' ราย'
        || case when c.sev > 0 then ' · สาหัสหรือเสียชีวิต ' || c.sev || ' ครั้ง' else '' end,
      '🗺️ https://www.google.com/maps?q=' || round(c.lat::numeric, 6) || ',' || round(c.lng::numeric, 6),
      ''
    ];
    v_sig := v_sig || round(c.lat::numeric, 4) || ',' || round(c.lng::numeric, 4)
             || '=' || c.n::text || '/' || c.injured::text || ';';
  end loop;

  -- ไม่มีจุดที่เกิดซ้ำเลย ไม่ต้องส่งสรุป เงียบดีกว่าส่งข้อความว่างเปล่า
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
-- ดูเกณฑ์ที่ใช้อยู่
--   select key, val from bs_settings where key like 'hotspot%';
--
-- อยากรู้ว่าเดือนนี้จะแจ้งกี่จุด ให้รัน sql/line_hotspot_tune_1.sql ก่อน
--
-- *** ระวัง: คำสั่งข้างล่างส่งเข้าไลน์จริง ไม่ใช่การทดลอง ***
--   select line_send_hotspots();
--
-- ค่าที่คืนกลับมาอ่านได้ว่า
--   found  = จำนวนจุดที่ถึงเกณฑ์ในรอบนี้
--   ranked = จำนวนจุดที่ติดอันดับในข้อความสรุป มากสุด 3
--   sent   = จำนวนข้อความที่ส่งจริงรอบนี้ ถ้าเป็น 0 แปลว่าไม่มีอะไรเปลี่ยนจากรอบก่อน
-- ============================================================
