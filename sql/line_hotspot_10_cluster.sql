-- เปลี่ยนวิธีหาจุดเสี่ยงซ้ำ จากช่องตารางหกเหลี่ยม ไปเป็นการวัดระยะจริง 120 เมตร
-- ถ้ามีอักขระแปลกปลอมต่อท้ายบรรทัดสุดท้าย ให้ลบออกก่อนกด Run
--
-- ปัญหาของวิธีเดิม
--   วิธีเดิมแบ่งพื้นที่เป็นช่องหกเหลี่ยมกว้าง 100 เมตร แล้วนับเฉพาะเหตุที่ตกช่องเดียวกัน
--   เส้นแบ่งช่องเป็นเส้นสมมติ ไม่เกี่ยวกับถนนจริง อุบัติเหตุที่ห่างกัน 120 เมตร
--   บนถนนเส้นเดียวกันจึงถูกนับแยกช่อง และไม่มีวันกลายเป็นจุดซ้ำ
--
--   วัดจริงเมื่อ 26 ส.ค. 2569 ด้วยข้อมูล 30 วันล่าสุด
--     แยกเดชาฯ เชิงสะพาน   เกิดจริง 5 ครั้ง   วิธีเดิมเห็นกระจายเป็นช่องละ 2-3 ไม่ถึงเกณฑ์
--     ซอยฟ้าใหม่ มหาเทพ     เกิดจริง 5 ครั้ง   วิธีเดิมไม่เห็น
--     แยกอุทยานสวรรค์       เกิดจริง 3 ครั้ง   วิธีเดิมไม่เห็น
--   ระบบเห็นเพียงสี่ช่อง และช่องที่หนักที่สุดนับได้แค่ 3 ครั้ง
--
-- วิธีใหม่
--   จับกลุ่มด้วยระยะทางจริง จุดที่ห่างกันไม่เกิน 120 เมตรถือเป็นจุดเดียวกัน
--   ขอบเขตกลุ่มจึงเดินตามการกระจุกของเหตุ ไม่ถูกเส้นตารางหั่น
--   ทดสอบแล้วได้ 8 จุด กลุ่มที่ยาวที่สุดกินระยะ 246 เมตร ไม่ลามยาวเป็นพืดทั้งถนน
--
--   ตั้ง minpoints เป็น 1 โดยตั้งใจ ไม่ใช่ 3
--   เพราะต้องให้จุดที่เกิดครั้งเดียวแต่มีคนเสียชีวิตยังเข้าเกณฑ์ได้เหมือนเดิม
--   ถ้าตั้ง 3 จุดแบบนั้นจะไม่ถูกจัดเป็นกลุ่มเลย แล้วหายไปจากรายงานเงียบ ๆ
--   การกรองด้วยจำนวนครั้งและความรุนแรง ทำทีหลังในขั้นตอนคัดเลือก
--
-- ข้อจำกัดที่ต้องพูดให้ชัด
--   นี่คือระยะเส้นตรง ไม่ใช่ระยะตามแนวถนน เพราะระบบไม่มีเครื่องมือคำนวณเส้นทาง
--   ผลต่างเกิดเมื่อสองจุดอยู่คนละฝั่งของสิ่งกีดขวาง เช่น คนละฝั่งแม่น้ำหรือคนละฝั่งทางรถไฟ
--   ซึ่งเส้นตรงใกล้แต่ต้องขับอ้อมไกล กรณีแบบนั้นจะถูกนับรวมทั้งที่ไม่ควร
--   ในเขตเมืองที่ถนนเป็นตาราง ผลต่างมีน้อย จึงยอมรับได้ และบอกไว้ตรงนี้แทนการซ่อน
--
-- ข้อความแจ้งเตือนไม่ถูกแตะ ยังเป็นถ้อยคำเดิมทุกตัวอักษร
-- เกณฑ์จำนวนครั้งและความรุนแรงยังเป็นค่าเดิมใน bs_settings

insert into bs_settings (key, val) values
  ('hotspotClusterMetres', to_jsonb(120))
on conflict (key) do update set val = excluded.val;

create or replace function line_send_hotspots()
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $fn$
declare
  v_from timestamptz;
  v_to   timestamptz;
  v_days int;
  v_min  int;
  v_sev  int;
  v_eps  float8;
  v_month text;
  v_site text;
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
begin
  v_min  := coalesce((select (val #>> array[]::text[])::int from bs_settings where key = 'hotspotMinPerMonth'), 3);
  v_sev  := coalesce((select (val #>> array[]::text[])::int from bs_settings where key = 'hotspotSevereMinPerMonth'), 2);
  v_days := coalesce((select (val #>> array[]::text[])::int from bs_settings where key = 'hotspotWindowDays'), 30);
  v_eps  := coalesce((select (val #>> array[]::text[])::float8 from bs_settings where key = 'hotspotClusterMetres'), 120);
  v_site := coalesce((select (val #>> array[]::text[]) from bs_settings where key = 'publicSiteUrl'), '');
  v_title := coalesce((select (val #>> array[]::text[]) from bs_settings where key = 'hotspotTitle'),
                      '📣 เตือนภัยอุบัติเหตุซ้ำ');

  -- ใช้ now() ตรง ๆ ไม่แปลงเขตเวลาก่อนลบ
  -- ของเดิมเขียน timezone('Asia/Bangkok', now()) ซึ่งคืนค่าเวลาที่ไม่มีเขตเวลาติดมา
  -- พอเอาไปใส่ตัวแปรที่มีเขตเวลา ระบบตีความเป็นเวลาสากล หน้าต่างจึงเลื่อนไปเจ็ดชั่วโมง
  v_from := now() - make_interval(days => v_days);
  v_to   := now();
  v_month := 'roll' || v_days || '-' || to_char(timezone('Asia/Bangkok', now()), 'YYYY-MM');

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
         -- ฟอร์มบันทึกไม่มีช่องว่ารับตัวไว้รักษาหรือไม่ จึงใช้อาการสาหัสหรือหมดสติเป็นตัวแทน
         -- ตัวเลขนี้จึงต่ำกว่าความจริงได้ เพราะคนเจ็บเล็กน้อยบางรายก็ถูกรับไว้สังเกตอาการ
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

  create temporary table if not exists tmp_hot_cell
    (lat float8, lng float8, n int, dead int, serious int, minor int, major int, score int,
     spread int, place text, road text, rchar text, tambon text) on commit drop;
  truncate tmp_hot_cell;

  insert into tmp_hot_cell (lat, lng, n, dead, serious, minor, major, score,
                            spread, place, road, rchar, tambon)
  with grp as (
    select st_clusterdbscan(g, eps := v_eps, minpoints := 1) over () as cid,
           g, dead, serious, minor, major, place, road, rchar, tambon
    from tmp_hot_pt
  )
  select st_y(st_transform(st_centroid(st_collect(g)), 4326)),
         st_x(st_transform(st_centroid(st_collect(g)), 4326)),
         count(*)::int,
         coalesce(sum(dead), 0)::int,
         coalesce(sum(serious), 0)::int,
         coalesce(sum(minor), 0)::int,
         count(*) filter (where major)::int,
         (count(*) * 3 + coalesce(sum(dead), 0) * 12
          + coalesce(sum(serious), 0) * 6 + coalesce(sum(minor), 0) * 3)::int,
         -- ระยะที่กลุ่มกินพื้นที่ เก็บไว้ให้ตรวจสอบภายหลังว่ากลุ่มลามยาวเกินควรหรือไม่
         round(st_maxdistance(st_collect(g), st_collect(g)))::int,
         -- ชื่อที่พบบ่อยที่สุดในกลุ่ม ไม่ใช่หยิบเคสใดเคสหนึ่งมาใช้
         mode() within group (order by place),
         mode() within group (order by road),
         mode() within group (order by rchar),
         mode() within group (order by tambon)
    from grp
   group by cid;

  select count(*)::int into v_total
    from tmp_hot_cell where n >= v_min or (dead + serious) >= v_sev;

  if v_total = 0 then
    return jsonb_build_object('success', true, 'month', v_month, 'found', 0, 'sent', 0);
  end if;

  v_lines := array[
    v_title,
    'ในรอบ ' || v_days || ' วันที่ผ่านมา'
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
      v_head := coalesce(c.place, 'ไม่ได้ระบุชื่อสถานที่')
                || case when c.rchar is not null then ' · ' || c.rchar else '' end;
      v_road := concat_ws(' · ', c.road,
                          case when c.tambon is not null then 'ต.' || c.tambon end);

      v_lines := v_lines || array['📍 ' || v_head]
        || case when v_road <> '' then array['🛣️ ' || v_road] else array[]::text[] end
        || array['🔢 รวม ' || c.n || ' ครั้ง'];
    else
      v_head := concat_ws(' · ',
                  coalesce(c.place, c.road, 'ไม่ได้ระบุชื่อสถานที่'),
                  c.rchar,
                  case when c.place is not null then c.road end);

      v_lines := v_lines || array['📍 ' || v_head, '🔢 ' || c.n || ' ครั้ง'];
    end if;

    if v_hurt <> '' then
      v_lines := v_lines || array['🩸 ' || v_hurt];
    end if;

    if c.major > 0 then
      v_lines := v_lines || array['⚠️ อุบัติเหตุใหญ่ตามเกณฑ์ ปภ. ' || c.major || ' ครั้ง'];
    end if;

    v_lines := v_lines || array[
      '🗺️ https://www.google.com/maps?q=' || round(c.lat::numeric, 6) || ',' || round(c.lng::numeric, 6)
    ]
    || case when v_total > 1 and v_rank < least(v_total, 3) then array[''] else array[]::text[] end;

    v_sig := v_sig || round(c.lat::numeric, 4) || ',' || round(c.lng::numeric, 4)
             || '=' || c.n || '/' || c.dead || '/' || c.serious || '/' || c.minor || ';';
  end loop;

  v_lines := v_lines || case when coalesce((select (val #>> array[]::text[]) from bs_settings where key = 'hotspotAgencyLine'), '') = '' then array[]::text[] else array[(select (val #>> array[]::text[]) from bs_settings where key = 'hotspotAgencyLine'), ''] end;

  if v_site <> '' then
    v_lines := v_lines || array['รายละเอียดที่นี่', v_site];
  end if;

  -- กุญแจกันส่งซ้ำมีตัวเลขทุกกลุ่มอาการของทุกจุดอยู่ด้วย
  -- ตัวเลขไม่ขยับก็เงียบ พอมีเพิ่มอีกครั้งหรืออาการเปลี่ยนกลุ่ม จึงส่งใหม่
  if line_broadcast('hotspot', array_to_string(v_lines, chr(10)),
       v_month || ':dbscan:' || v_sig) > 0 then
    v_sent := 1;
  end if;

  return jsonb_build_object('success', true, 'month', v_month,
    'method', 'dbscan', 'metres', v_eps,
    'min_per_cell', v_min, 'severe_min', v_sev,
    'found', v_total, 'listed', v_rank, 'sent', v_sent);
end;
$fn$;

-- ==========================================================
-- ตรวจผล  คำสั่งสุดท้ายคำสั่งเดียวที่จะแสดงผล
-- ==========================================================
-- เรียกฟังก์ชันจริงหนึ่งครั้ง จะได้เห็นว่าจับได้กี่จุดและส่งหรือไม่
-- ถ้ากุญแจกันส่งซ้ำยังตรงกับของเดิม จะขึ้น sent เป็น 0 ซึ่งถูกต้อง

select 'ผลการทำงานจริง' as รายการ, line_send_hotspots()::text as ผล
union all
select 'ระยะจับกลุ่ม',
       coalesce((select val #>> array[]::text[] from bs_settings where key = 'hotspotClusterMetres'), '-') || ' เมตร'
union all
select 'เกณฑ์จำนวนครั้ง',
       coalesce((select val #>> array[]::text[] from bs_settings where key = 'hotspotMinPerMonth'), '-') || ' ครั้ง'
union all
select 'เกณฑ์ความรุนแรง',
       'เสียชีวิตรวมสาหัสตั้งแต่ '
       || coalesce((select val #>> array[]::text[] from bs_settings where key = 'hotspotSevereMinPerMonth'), '-') || ' ราย'
union all
select 'หมายเหตุ', 'เป็นระยะเส้นตรง ไม่ใช่ระยะตามแนวถนน ระบบไม่มีเครื่องมือคำนวณเส้นทาง';
