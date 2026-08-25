-- ============================================================
-- แจ้งจุดเสี่ยงซ้ำรายเดือน — เพิ่มเงื่อนไขความรุนแรง และส่งซ้ำเมื่อเพิ่มขึ้น
-- ============================================================
-- ต้องรัน fix_backslash_2_line.sql มาก่อน ไฟล์นี้เขียนทับฟังก์ชันเดิมทั้งตัว
-- ไม่แตะงานตั้งเวลา ตารางเดิมยังเดินทุก 5 นาทีตามเดิม
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
-- ถ้ามี $0 ค้างอยู่บรรทัดสุดท้าย ให้ลบทิ้งก่อนกด Run
-- ไฟล์นี้ไม่มีวงเล็บปีกกาเลยแม้แต่ตัวเดียว
--
-- สิ่งที่เปลี่ยนจากเดิม 3 ข้อ
--
--   1) เกณฑ์แจ้ง จากเดิมนับจำนวนครั้งอย่างเดียวที่ 4 ครั้ง
--      เปลี่ยนเป็นเข้าเงื่อนไขใดเงื่อนไขหนึ่งก็แจ้ง
--        รวมทุกระดับ 3 ครั้งต่อเดือน   หรือ
--        เฉพาะรายที่สาหัสหรือเสียชีวิต 2 ครั้งต่อเดือน
--      เหตุผลที่ต้องมีสองเงื่อนไข จุดที่ชนเบา ๆ 3 ครั้งกับจุดที่มีคนสาหัส 2 ครั้ง
--      อันตรายไม่เท่ากัน แต่ถ้าใช้เกณฑ์นับครั้งอย่างเดียว จุดหลังจะไม่เคยถึงเกณฑ์เลย
--
--   2) การนับความรุนแรง อ่านจากข้อมูลผู้เกี่ยวข้องในเคสโดยตรง
--      ทั้งคู่กรณีทั้งสองฝ่ายและผู้โดยสารทุกคน ถ้ามีใครสักคนอาการสาหัสหรือเสียชีวิต
--      ถือว่าเคสนั้นเป็นเคสรุนแรง
--
--      หมายเหตุที่ตัดสินใจแทนไว้ก่อน นับ "เสียชีวิต" รวมกับ "สาหัส"
--      เพราะจุดที่มีคนตาย 2 ครั้งในเดือนเดียว คือจุดที่ต้องรู้ยิ่งกว่าจุดที่สาหัส 2 ครั้ง
--      ถ้าไม่นับรวม จุดแบบนั้นจะเงียบสนิท ซึ่งกลับหัวกลับหางกับเจตนาของระบบ
--      ส่วน "หมดสติ" ยังไม่นับ ถ้าจะให้นับด้วยแก้ที่บรรทัดที่มีคำว่า สาหัส
--
--   3) การส่งซ้ำ เดิมจุดหนึ่งในเดือนหนึ่งส่งได้ครั้งเดียว
--      เปลี่ยนเป็นส่งใหม่ทุกครั้งที่ตัวเลขขยับ
--      ทำโดยเอาจำนวนครั้งใส่ไว้ในกุญแจกันส่งซ้ำด้วย
--      พอเกิดเพิ่มอีกหนึ่งครั้ง กุญแจก็เปลี่ยน ระบบจึงถือว่าเป็นข่าวใหม่
--      ตัวเลขไม่ขยับก็ยังเงียบเหมือนเดิม ไม่เด้งซ้ำทุก 5 นาที
--
-- ระวังเรื่องข้อมูลเก่า
--   เคสที่นำเข้าจากระบบเดิมบางแถวเก็บผู้โดยสารเป็นวัตถุว่างแทนที่จะเป็นรายการ
--   ถ้าอ่านตรง ๆ จะพังทันที จึงตรวจชนิดข้อมูลก่อนทุกครั้ง
-- ============================================================

-- เกณฑ์ทั้งสองตัว แก้ทีหลังได้โดยไม่ต้องรันไฟล์นี้ใหม่
insert into bs_settings(key, val) values ('hotspotMinPerMonth', '3'::jsonb)
on conflict (key) do update set val = '3'::jsonb, updated_at = now();

insert into bs_settings(key, val) values ('hotspotSevereMinPerMonth', '2'::jsonb)
on conflict (key) do nothing;

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
begin
  v_min := coalesce(
    (select (val #>> array[]::text[])::int from bs_settings where key = 'hotspotMinPerMonth'), 3);
  v_sev := coalesce(
    (select (val #>> array[]::text[])::int from bs_settings where key = 'hotspotSevereMinPerMonth'), 2);

  v_from := date_trunc('month', timezone('Asia/Bangkok', now()));
  v_to   := now();
  v_month := to_char(v_from, 'YYYY-MM');

  create temporary table if not exists tmp_hot_pt (g geometry, severe boolean) on commit drop;
  truncate tmp_hot_pt;

  insert into tmp_hot_pt (g, severe)
  select st_transform(st_setsrid(st_makepoint(a.longitude, a.latitude), 4326), 32647),
         exists (
           select 1
             from jsonb_array_elements(
                    jsonb_build_array(coalesce(a.party1, jsonb_build_object()),
                                      coalesce(a.party2, jsonb_build_object()))
                    || case when jsonb_typeof(a.party1->'passengers') = 'array'
                            then a.party1->'passengers' else jsonb_build_array() end
                    || case when jsonb_typeof(a.party2->'passengers') = 'array'
                            then a.party2->'passengers' else jsonb_build_array() end
                  ) as e(v)
            where v->>'injury' in ('สาหัส', 'เสียชีวิต')
         )
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
      select cl.geom,
             count(*)::int as n,
             count(*) filter (where p.severe)::int as sev
        from cells cl join tmp_hot_pt p on st_intersects(cl.geom, p.g)
       group by cl.geom
      having count(*) >= v_min or count(*) filter (where p.severe) >= v_sev
    )
    select a.n, a.sev,
           st_y(st_transform(st_centroid(a.geom), 4326)) as lat,
           st_x(st_transform(st_centroid(a.geom), 4326)) as lng
      from agg a order by a.sev desc, a.n desc
  loop
    v_found := v_found + 1;

    -- บอกด้วยว่าเข้าเกณฑ์ข้อไหน เพื่อให้คนอ่านตัดสินใจได้ว่าควรลงพื้นที่แบบไหน
    v_reason := case
      when c.sev >= v_sev and c.n >= v_min then 'ถึงเกณฑ์ทั้งจำนวนครั้งและความรุนแรง'
      when c.sev >= v_sev then 'ถึงเกณฑ์ความรุนแรง'
      else 'ถึงเกณฑ์จำนวนครั้ง' end;

    v_txt := array_to_string(array[
      '🔴 จุดเกิดอุบัติเหตุซ้ำ ประจำเดือน',
      line_thai_date(v_from) || ' ถึงวันนี้',
      '',
      '📍 ในรัศมีราว 100 เมตร',
      '🔢 รวม ' || c.n || ' ครั้ง',
      '🩸 สาหัสหรือเสียชีวิต ' || c.sev || ' ครั้ง',
      '⚖️ ' || v_reason,
      '🗺️ https://www.google.com/maps?q=' || round(c.lat::numeric, 6) || ',' || round(c.lng::numeric, 6),
      '',
      'นับใหม่ทุกวันที่ 1 ของเดือน'
    ], chr(10));

    -- กุญแจกันส่งซ้ำ เดือน + พิกัดปัด 4 ตำแหน่ง ราว 11 ม. + จำนวนครั้งทั้งสองแบบ
    -- ปัดพิกัดเพื่อให้จุดเดิมได้กุญแจเดิมทุกรอบ ไม่งั้นทศนิยมขยับนิดเดียวก็กลายเป็นจุดใหม่
    -- ใส่จำนวนครั้งเข้าไปด้วย เพื่อให้เกิดเพิ่มอีกครั้งแล้วส่งใหม่ตามที่ต้องการ
    if line_broadcast('hotspot', v_txt,
         v_month || ':' || round(c.lat::numeric, 4) || ',' || round(c.lng::numeric, 4)
         || ':' || c.n::text || '/' || c.sev::text) > 0 then
      v_sent := v_sent + 1;
    end if;
  end loop;

  return jsonb_build_object('success', true, 'month', v_month,
    'min_per_cell', v_min, 'severe_min', v_sev, 'found', v_found, 'sent', v_sent);
end $lshs$;

revoke execute on function line_send_hotspots() from public, anon, authenticated;

-- ============================================================
-- ตรวจผลหลังรัน
-- ============================================================
-- ดูเกณฑ์ที่ใช้อยู่
--   select key, val from bs_settings where key like 'hotspot%';
--
-- เปลี่ยนเกณฑ์ทีหลัง มีผลรอบถัดไปทันที ไม่ต้องรันไฟล์นี้ใหม่
--   update bs_settings set val = '4'::jsonb, updated_at = now()
--    where key = 'hotspotMinPerMonth';
--   update bs_settings set val = '3'::jsonb, updated_at = now()
--    where key = 'hotspotSevereMinPerMonth';
--
-- อยากรู้ว่าเดือนนี้จะแจ้งกี่จุดก่อนของจริง ให้รัน sql/line_hotspot_tune_1.sql
--
-- *** ระวัง: คำสั่งข้างล่างส่งเข้าไลน์จริง ไม่ใช่การทดลอง ***
--   select line_send_hotspots();
--
-- ถ้าเปิดใช้แล้วรู้สึกว่าเด้งบ่อยเกินไป ตัวที่ควรปรับก่อนคือเกณฑ์จำนวนครั้ง
-- เพราะเกณฑ์ความรุนแรงเป็นตัวที่ตั้งใจให้ไวอยู่แล้ว
-- ============================================================
