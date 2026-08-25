-- ============================================================
-- รูปแบบรายงานจุดเสี่ยงซ้ำ ตามที่กำหนด
-- ============================================================
-- ต้องรัน line_hotspot_2_severity.sql มาก่อน ไฟล์นี้เขียนทับฟังก์ชันเดิมทั้งตัว
-- ไม่ต้องรันไฟล์ 3 กับ 4 ไฟล์นี้รวมทุกอย่างไว้ครบแล้ว
-- ไม่แตะงานตั้งเวลา ตารางเดิมยังเดินทุก 5 นาทีตามเดิม
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
-- ถ้ามี $0 ค้างอยู่บรรทัดสุดท้าย ให้ลบทิ้งก่อนกด Run
-- ไฟล์นี้ไม่มีวงเล็บปีกกาเลยแม้แต่ตัวเดียว
--
-- โครงข้อความ
--   ส่งฉบับเดียวต่อรอบ ไม่แจ้งรายจุดแยก
--   รูปแบบต่างกันตามจำนวนจุดที่เข้าเกณฑ์
--     จุดเดียว    ลงรายละเอียดเต็ม แยกบรรทัดสถานที่กับถนน
--     หลายจุด     ไล่เรียงมากสุด 3 จุด แต่ละจุดใช้โครงเดียวกัน
--
-- การนับอาการ แยกสามกลุ่มไม่ทับกัน
--   เสียชีวิต
--   สาหัส หรือ หมดสติ นับรวมเป็นกลุ่มเดียว
--   บาดเจ็บ หมายถึงเล็กน้อยเท่านั้น ไม่รวมสองกลุ่มข้างบน
--
-- การจัดลำดับ สองชั้น
--   ชั้นแรก  จำนวนผู้เสียชีวิต มาก่อนเสมอ
--            จุดที่มีคนตายอยู่เหนือจุดที่ไม่มี ไม่ว่าอย่างอื่นจะมากแค่ไหน
--   ชั้นสอง  คะแนนความรุนแรง ใช้ตารางน้ำหนักที่กำหนดไว้ตรง ๆ
--              เสียชีวิต 1 ราย        = 12
--              สาหัสหรือหมดสติ 1 ราย  = 6
--              อุบัติเหตุ 1 ครั้ง      = 3
--              บาดเจ็บเล็กน้อย 1 ราย  = 3
--
--            ตารางนี้แทนที่อัตราแลกชุดก่อนหน้าที่เคยกำหนดว่า
--            สาหัสหรือหมดสติ 1 ราย เท่ากับ บาดเจ็บเล็กน้อย 3 ราย
--            ตามน้ำหนักชุดนี้จะกลายเป็นเท่ากับเล็กน้อย 2 ราย
--            ยึดตามตารางเป็นหลัก เพราะเป็นสิ่งที่กำหนดไว้ล่าสุด
--
--            อีกจุดที่เปลี่ยนไป อุบัติเหตุหนึ่งครั้งมีน้ำหนักเท่าคนเจ็บเล็กน้อยหนึ่งราย
--            แปลว่าเคสที่ชนแล้วไม่มีใครเจ็บเลย ยังได้ 3 คะแนนจากตัวการเกิดเหตุเอง
--            ซึ่งตรงกับเจตนา เพราะจุดที่ชนบ่อยแม้ไม่มีใครเจ็บ ก็ยังเป็นจุดที่ต้องแก้
--
--   หมายเหตุ ชั้นแรกทำให้ลำดับต่างจากตัวอย่างที่ให้มา
--   จุดที่มีผู้เสียชีวิตจะขึ้นก่อนจุดที่มีสาหัสสองรายเสมอ ตามกฎที่กำหนดไว้
--
-- คำว่าบาดเจ็บในข้อความหมายถึงเล็กน้อยเท่านั้นเสมอ ไม่มีวงเล็บกำกับและไม่มีหมายเหตุท้าย
-- ตามที่กำหนด เพราะในกลุ่มไลน์ข้อความยาวคนจะเลื่อนผ่าน
-- ============================================================

-- ที่อยู่หน้าเว็บสาธารณะ แก้ทีหลังได้ด้วย update ไม่ต้องรันไฟล์นี้ใหม่
insert into bs_settings(key, val)
values ('publicSiteUrl',
        to_jsonb('https://traffic-risk-muangnakhonsawan.netlify.app/index.html'::text))
on conflict (key) do nothing;

-- หัวข้อของข้อความ เก็บแยกไว้เพราะเป็นถ้อยคำที่ปรับบ่อย
-- เปลี่ยนได้ด้วย update บรรทัดเดียว ไม่ต้องลากไฟล์มารันใหม่
insert into bs_settings(key, val)
values ('hotspotTitle', to_jsonb('📣 เตือนภัยอุบัติเหตุซ้ำ'::text))
on conflict (key) do update set val = to_jsonb('📣 เตือนภัยอุบัติเหตุซ้ำ'::text),
                                updated_at = now();

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
  v_monthth text;
  v_site text;
  v_bounds geometry;
  c record;
  v_lines text[];
  v_sig text := '';
  v_rank int := 0;
  v_total int;
  v_head text;
  v_road text;
  v_hurt text;
  v_sent int := 0;
  v_title text;
  v_thmonth text[] := array['ม.ค.','ก.พ.','มี.ค.','เม.ย.','พ.ค.','มิ.ย.',
                            'ก.ค.','ส.ค.','ก.ย.','ต.ค.','พ.ย.','ธ.ค.'];
begin
  v_min := coalesce(
    (select (val #>> array[]::text[])::int from bs_settings where key = 'hotspotMinPerMonth'), 3);
  v_sev := coalesce(
    (select (val #>> array[]::text[])::int from bs_settings where key = 'hotspotSevereMinPerMonth'), 2);
  v_site := coalesce(
    (select (val #>> array[]::text[]) from bs_settings where key = 'publicSiteUrl'), '');
  -- หัวข้อเก็บในตารางตั้งค่า เปลี่ยนถ้อยคำได้ด้วย update บรรทัดเดียว ไม่ต้องรันไฟล์ใหม่
  v_title := coalesce(
    (select (val #>> array[]::text[]) from bs_settings where key = 'hotspotTitle'),
    '📣 เตือนภัยอุบัติเหตุซ้ำ');

  v_from := date_trunc('month', timezone('Asia/Bangkok', now()));
  v_to   := now();
  v_month := to_char(v_from, 'YYYY-MM');
  -- ชื่อเดือนไทยกับปีพุทธศักราชสองหลัก เช่น สิงหาคม 69
  -- ชื่อเดือนแบบย่อกับปีพุทธศักราชสองหลัก ติดกันไม่มีเว้นวรรค เช่น ส.ค.69
  v_monthth := v_thmonth[extract(month from v_from)::int] ||
               lpad(((extract(year from v_from)::int + 543) % 100)::text, 2, '0');

  create temporary table if not exists tmp_hot_pt
    (g geometry, dead int, serious int, minor int, major boolean,
     place text, road text, rchar text, tambon text) on commit drop;
  truncate tmp_hot_pt;

  -- แตกผู้เกี่ยวข้องทุกคนออกมา แล้วนับแยกสามกลุ่มอาการในคราวเดียว
  -- ข้อมูลเก่าบางแถวเก็บผู้โดยสารเป็นวัตถุว่างแทนรายการ ถ้าอ่านตรง ๆ จะพังทันที
  insert into tmp_hot_pt (g, dead, serious, minor, major, place, road, rchar, tambon)
  select st_transform(st_setsrid(st_makepoint(a.longitude, a.latitude), 4326), 32647),
         coalesce(count(*) filter (where e.v->>'injury' = 'เสียชีวิต'), 0)::int,
         coalesce(count(*) filter (where e.v->>'injury' in ('สาหัส', 'หมดสติ')), 0)::int,
         coalesce(count(*) filter (where e.v->>'injury' = 'เล็กน้อย'), 0)::int,
         -- อุบัติเหตุใหญ่ทางถนน ตามเกณฑ์กรมป้องกันและบรรเทาสาธารณภัย
         -- เข้าเงื่อนไขข้อใดข้อหนึ่งก็ถือว่าใช่
         --   เสียชีวิตตั้งแต่ 2 ราย
         --   บาดเจ็บที่ต้องรับไว้รักษาในโรงพยาบาลตั้งแต่ 4 ราย
         --   บาดเจ็บรวมเสียชีวิตตั้งแต่ 4 ราย
         --
         -- ข้อจำกัดที่ต้องรู้ ฟอร์มบันทึกไม่มีช่องว่ารับตัวไว้รักษาหรือไม่
         -- จึงใช้อาการสาหัสหรือหมดสติเป็นตัวแทน ซึ่งใกล้เคียงแต่ไม่ใช่สิ่งเดียวกัน
         -- คนเจ็บเล็กน้อยบางรายก็ถูกรับไว้สังเกตอาการ ตัวเลขนี้จึงต่ำกว่าความจริงได้
         (coalesce(count(*) filter (where e.v->>'injury' = 'เสียชีวิต'), 0) >= 2
          or coalesce(count(*) filter (where e.v->>'injury' in ('สาหัส', 'หมดสติ')), 0) >= 4
          or coalesce(count(*) filter (
               where e.v->>'injury' in ('เสียชีวิต', 'สาหัส', 'หมดสติ', 'เล็กน้อย')), 0) >= 4),
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
    (lat float8, lng float8, n int, dead int, serious int, minor int, major int, score int,
     place text, road text, rchar text, tambon text) on commit drop;
  truncate tmp_hot_cell;

  insert into tmp_hot_cell (lat, lng, n, dead, serious, minor, major, score,
                            place, road, rchar, tambon)
  with cells as (select h.geom from st_hexagongrid(v_edge, v_bounds) h),
  agg as (
    select cl.geom,
           count(*)::int as n,
           coalesce(sum(p.dead), 0)::int    as dead,
           coalesce(sum(p.serious), 0)::int as serious,
           coalesce(sum(p.minor), 0)::int   as minor,
           count(*) filter (where p.major)::int as major
      from cells cl join tmp_hot_pt p on st_intersects(cl.geom, p.g)
     group by cl.geom
  )
  select st_y(st_transform(st_centroid(a.geom), 4326)),
         st_x(st_transform(st_centroid(a.geom), 4326)),
         a.n, a.dead, a.serious, a.minor, a.major,
         a.n * 3 + a.dead * 12 + a.serious * 6 + a.minor * 3,
         -- ชื่อที่พบบ่อยที่สุดในช่องนั้น ไม่ใช่หยิบเคสใดเคสหนึ่งมาใช้
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

  select count(*)::int into v_total
    from tmp_hot_cell where n >= v_min or (dead + serious) >= v_sev;

  if v_total = 0 then
    return jsonb_build_object('success', true, 'month', v_month, 'found', 0, 'sent', 0);
  end if;

  v_lines := array[
    -- หัวข้อเหมือนกันทั้งสองแบบ ไม่ต่อท้ายด้วยจำนวนอันดับ
    v_title,
    'ประจำเดือน ' || v_monthth
  ];

  for c in
    select * from tmp_hot_cell
     where n >= v_min or (dead + serious) >= v_sev
     -- เสียชีวิตมาก่อนเสมอ แล้วค่อยตัดสินด้วยคะแนนความรุนแรง
     order by dead desc, score desc, n desc, lat, lng
     limit 3
  loop
    v_rank := v_rank + 1;

    -- บรรทัดอาการ เขียนเฉพาะกลุ่มที่มีจริง เสียชีวิตขึ้นก่อนเสมอ
    v_hurt := concat_ws(' · ',
      case when c.dead > 0 then 'เสียชีวิต ' || c.dead || ' ราย' end,
      case when c.serious > 0 then 'สาหัส/หมดสติ ' || c.serious || ' ราย' end,
      case when c.minor > 0 then 'บาดเจ็บ ' || c.minor || ' ราย' end);

    if v_total = 1 then
      -- แบบจุดเดียว แยกบรรทัดสถานที่กับถนนให้อ่านง่าย
      v_head := coalesce(c.place, 'ไม่ได้ระบุชื่อสถานที่')
                || case when c.rchar is not null then ' · ' || c.rchar else '' end;
      v_road := concat_ws(' · ', c.road,
                          case when c.tambon is not null then 'ต.' || c.tambon end);

      v_lines := v_lines || array['📍 ' || v_head]
        || case when v_road <> '' then array['🛣️ ' || v_road] else array[]::text[] end
        || array['🔢 รวม ' || c.n || ' ครั้ง'];
    else
      -- แบบหลายจุด รวมสถานที่ ลักษณะทาง และถนน ไว้บรรทัดเดียวให้กระชับ
      v_head := concat_ws(' · ',
                  coalesce(c.place, c.road, 'ไม่ได้ระบุชื่อสถานที่'),
                  c.rchar,
                  case when c.place is not null then c.road end);

      v_lines := v_lines || array['📍 ' || v_head, '🔢 ' || c.n || ' ครั้ง'];
    end if;

    if v_hurt <> '' then
      v_lines := v_lines || array['🩸 ' || v_hurt];
    end if;

    -- ติดป้ายให้เห็นชัดว่าจุดนี้มีเคสที่เข้าเกณฑ์อุบัติเหตุใหญ่ของ ปภ.
    if c.major > 0 then
      v_lines := v_lines || array['⚠️ อุบัติเหตุใหญ่ตามเกณฑ์ ปภ. ' || c.major || ' ครั้ง'];
    end if;

    v_lines := v_lines || array[
      '🗺️ https://www.google.com/maps?q=' || round(c.lat::numeric, 6) || ',' || round(c.lng::numeric, 6)
    ]
    -- เว้นบรรทัดคั่นระหว่างจุด เฉพาะแบบหลายจุด และไม่ใส่ท้ายจุดสุดท้าย
    || case when v_total > 1 and v_rank < least(v_total, 3) then array[''] else array[]::text[] end;

    v_sig := v_sig || round(c.lat::numeric, 4) || ',' || round(c.lng::numeric, 4)
             || '=' || c.n || '/' || c.dead || '/' || c.serious || '/' || c.minor || ';';
  end loop;

  if v_site <> '' then
    v_lines := v_lines || array['รายละเอียดที่นี่', v_site];
  end if;

  -- กุญแจกันส่งซ้ำมีตัวเลขทุกกลุ่มอาการของทุกจุดอยู่ด้วย
  -- ตัวเลขไม่ขยับก็เงียบ พอมีเพิ่มอีกครั้งหรืออาการเปลี่ยนกลุ่ม จึงส่งใหม่
  if line_broadcast('hotspot', array_to_string(v_lines, chr(10)),
       v_month || ':report:' || v_sig) > 0 then
    v_sent := 1;
  end if;

  return jsonb_build_object('success', true, 'month', v_month,
    'min_per_cell', v_min, 'severe_min', v_sev,
    'found', v_total, 'listed', v_rank, 'sent', v_sent);
end $lshs$;

revoke execute on function line_send_hotspots() from public, anon, authenticated;

-- ============================================================
-- ตรวจผลหลังรัน
-- ============================================================
-- ดูค่าที่ตั้งไว้ทั้งหมด
--   select key, val from bs_settings
--    where key like 'hotspot%' or key = 'publicSiteUrl';
--
-- เปลี่ยนที่อยู่หน้าเว็บทีหลัง เช่นตอนย้ายไปโดเมนของตัวเอง
--   update bs_settings set val = to_jsonb('https://ชื่อโดเมนใหม่/'::text),
--          updated_at = now() where key = 'publicSiteUrl';
--
-- *** ระวัง: คำสั่งข้างล่างส่งเข้าไลน์จริง ไม่ใช่การทดลอง ***
--   select line_send_hotspots();
--
-- ค่าที่คืนกลับมา
--   found  = จำนวนจุดที่เข้าเกณฑ์ทั้งหมดในเดือนนี้
--   listed = จำนวนจุดที่ลงในข้อความ มากสุด 3
--   sent   = 1 ถ้าส่งจริง หรือ 0 ถ้าไม่มีอะไรเปลี่ยนจากรอบก่อน
-- ============================================================
