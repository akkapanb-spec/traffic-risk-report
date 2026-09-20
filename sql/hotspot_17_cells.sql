-- ============================================================
-- จุดอุบัติเหตุซ้ำ  ไฟล์ 17  คืนรายการจุดพร้อมพิกัดออกมาด้วย
-- ============================================================
-- รันได้ต่อเมื่อไฟล์ hotspot_16_check.sql ขึ้นว่า ตรงกัน แก้ต่อได้
--
-- ของเดิมคืนออกมาเป็นข้อความก้อนเดียว การ์ดอินโฟกราฟิกจึงวาดทีละแถวไม่ได้
-- และจับคู่รูปของจุดไม่ได้ เพราะไม่มีพิกัดติดออกมา
--
-- ไฟล์นี้เพิ่มของใหม่ชื่อ cells เป็นรายการจุด แต่ละจุดมีชื่อ ถนน ตำบล
-- จำนวนครั้ง จำนวนเสียชีวิต สาหัส บาดเจ็บ และพิกัด
--
-- ข้อความที่ส่งเข้าไลน์ไม่ถูกแตะแม้แต่ตัวอักษรเดียว  ลำดับและเกณฑ์ทุกอย่างคงเดิม
-- ตัวฟังก์ชันคัดมาจาก line_pub_3_hotspot.sql ทั้งก้อน แล้วแทรกเพิ่มสามจุดด้วยเครื่อง
-- ไม่ได้พิมพ์ใหม่เอง จึงไม่มีทางพิมพ์ตกหล่นระหว่างทาง
--
-- ห้ามมีปีกกาในไฟล์นี้ ตัวแก้ไขจะเติมแบ็กสแลชให้
-- ก่อนกด Run ให้ลบสิ่งที่ตัวแก้ไขเติมไว้ท้ายสุดออกก่อน เป็นดอลลาร์ตามด้วยเลขศูนย์

create or replace function line_hotspot_build()
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
  v_r    float8;
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
  v_title text;
  v_cid int := 0;
  v_top int;
  v_seed bigint;
  v_nodes int;
  v_guess int;
  -- รายการจุดแบบข้อมูล ไว้ให้การ์ดอินโฟกราฟิกจับคู่รูปจากพิกัด
  v_cells jsonb := jsonb_build_array();
begin
  v_min  := coalesce((select (val #>> array[]::text[])::int from bs_settings where key = 'hotspotMinPerMonth'), 3);
  v_sev  := coalesce((select (val #>> array[]::text[])::int from bs_settings where key = 'hotspotSevereMinPerMonth'), 2);
  v_days := coalesce((select (val #>> array[]::text[])::int from bs_settings where key = 'hotspotWindowDays'), 30);
  v_r    := coalesce((select (val #>> array[]::text[])::float8 from bs_settings where key = 'hotspotClusterMetres'), 100);
  v_site := coalesce((select (val #>> array[]::text[]) from bs_settings where key = 'publicSiteUrl'), '');
  -- จำนวนจุดที่จะเขียนลงข้อความ  ไม่ตรึงไว้ในโค้ด
  v_top := greatest(1, coalesce((select (val #>> array[]::text[])::int from bs_settings
                                  where key = 'hotspotTopN'), 5));
  v_title := coalesce((select (val #>> array[]::text[]) from bs_settings where key = 'hotspotTitle'),
                      '📣 เตือนภัยอุบัติเหตุซ้ำ');

  v_from := now() - make_interval(days => v_days);
  v_to   := now();
  v_month := 'roll' || v_days || '-' || to_char(timezone('Asia/Bangkok', now()), 'YYYY-MM');

  create temporary table if not exists tmp_hot_pt
    (acc_id bigint, g geometry, dead int, serious int, minor int, major boolean,
     place text, road text, rchar text, tambon text, is_node boolean) on commit drop;
  truncate tmp_hot_pt;

  -- แตกผู้เกี่ยวข้องทุกคนออกมา แล้วนับแยกสามกลุ่มอาการในคราวเดียว
  -- ข้อมูลเก่าบางแถวเก็บผู้โดยสารเป็นวัตถุว่างแทนรายการ ถ้าอ่านตรง ๆ จะพังทันที
  insert into tmp_hot_pt (acc_id, g, dead, serious, minor, major,
                          place, road, rchar, tambon, is_node)
  select a.id,
         st_transform(st_setsrid(st_makepoint(a.longitude, a.latitude), 4326), 32647),
         coalesce(count(*) filter (where e.v->>'injury' = 'เสียชีวิต'), 0)::int,
         coalesce(count(*) filter (where e.v->>'injury' in ('สาหัส', 'หมดสติ')), 0)::int,
         coalesce(count(*) filter (where e.v->>'injury' = 'เล็กน้อย'), 0)::int,
         -- อุบัติเหตุใหญ่ทางถนน ตามเกณฑ์กรมป้องกันและบรรเทาสาธารณภัย
         -- ฟอร์มบันทึกไม่มีช่องว่ารับตัวไว้รักษาหรือไม่ จึงใช้อาการสาหัสหรือหมดสติเป็นตัวแทน
         (coalesce(count(*) filter (where e.v->>'injury' = 'เสียชีวิต'), 0) >= 2
          or coalesce(count(*) filter (where e.v->>'injury' in ('สาหัส', 'หมดสติ')), 0) >= 4
          or coalesce(count(*) filter (
               where e.v->>'injury' in ('เสียชีวิต', 'สาหัส', 'หมดสติ', 'เล็กน้อย')), 0) >= 4),
         nullif(btrim(a.place), ''),
         nullif(btrim(a.road), ''),
         nullif(btrim(a.road_character), ''),
         nullif(btrim(a.subdistrict), ''),
         -- จุดที่ตัวมันเองเป็นสาเหตุ  ดูจากช่องลักษณะทางก่อน
         -- ช่องนั้นว่างเป็นส่วนใหญ่ จึงอ่านจากชื่อสถานที่เสริมด้วย
         -- สะกดผิดมีจริงในข้อมูล เช่น เซ็ฯทรัล จึงจับหลายรูปแบบไว้
         (coalesce(btrim(a.road_character), '') in ('ทางแยก', 'ทางร่วม', 'จุดกลับรถ')
          or a.place ilike '%แยก%'      or a.place ilike '%วงเวียน%'
          or a.place ilike '%กลับรถ%'   or a.place ilike '%ยูเทิร์น%'
          or a.place ilike '%ยูเทิน%'   or a.place ilike '%ยูเทริน%'
          or a.place ilike '%u-turn%'   or a.place ilike '%uturn%')
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
    return jsonb_build_object('found', 0);
  end if;

  create index if not exists tmp_hot_pt_gix on tmp_hot_pt using gist (g);
  analyze tmp_hot_pt;

  select count(*) into v_nodes from tmp_hot_pt where is_node;

  -- นับว่ามีคู่ที่ต้องใช้ระยะถนนแต่ยังไม่มีข้อมูล จึงต้องถอยไปใช้เส้นตรงกี่คู่
  -- ตัวเลขนี้บอกว่ารายงานรอบนี้เชื่อได้แค่ไหน ไม่ใช่ของประดับ
  select count(*) into v_guess
    from tmp_hot_pt x join tmp_hot_pt y on x.acc_id < y.acc_id
   where not x.is_node and not y.is_node
     and st_dwithin(x.g, y.g, v_r)
     and not exists (select 1 from road_dist d
                      where d.a_id = x.acc_id and d.b_id = y.acc_id and d.metres is not null);

  -- ------------------------------------------------------------
  -- จับกลุ่มแบบเลือกศูนย์กลางทีละวง ไม่ให้ลามต่อกัน
  -- ------------------------------------------------------------
  create temporary table if not exists tmp_hot_asg
    (acc_id bigint primary key, cid int) on commit drop;
  truncate tmp_hot_asg;

  loop
    -- เลือกจุดที่กวาดเพื่อนที่ยังว่างได้มากที่สุดเป็นศูนย์กลาง
    -- ตัดสินเสมอด้วยความรุนแรงแล้วด้วยหมายเลข เพื่อให้ผลเหมือนเดิมทุกครั้งที่รัน
    -- ถ้าผลไม่คงที่ กุญแจกันส่งซ้ำจะเปลี่ยนเองทุกรอบ แล้วส่งซ้ำทุกห้านาที
    select p.acc_id into v_seed
      from tmp_hot_pt p
     where not exists (select 1 from tmp_hot_asg a where a.acc_id = p.acc_id)
     order by (select count(*) from tmp_hot_pt q
                where not exists (select 1 from tmp_hot_asg a2 where a2.acc_id = q.acc_id)
                  and hot_reach(p.acc_id, q.acc_id, p.g, q.g, p.is_node, q.is_node, v_r)) desc,
              p.dead desc, p.serious desc, p.acc_id
     limit 1;

    exit when v_seed is null;

    v_cid := v_cid + 1;

    insert into tmp_hot_asg (acc_id, cid)
    select q.acc_id, v_cid
      from tmp_hot_pt q, tmp_hot_pt s
     where s.acc_id = v_seed
       and not exists (select 1 from tmp_hot_asg a where a.acc_id = q.acc_id)
       and hot_reach(s.acc_id, q.acc_id, s.g, q.g, s.is_node, q.is_node, v_r);
  end loop;

  create temporary table if not exists tmp_hot_cell
    (lat float8, lng float8, n int, dead int, serious int, minor int, major int, score int,
     spread int, nodes int, place text, road text, rchar text, tambon text) on commit drop;
  truncate tmp_hot_cell;

  insert into tmp_hot_cell (lat, lng, n, dead, serious, minor, major, score,
                            spread, nodes, place, road, rchar, tambon)
  select st_y(st_transform(st_centroid(st_collect(p.g)), 4326)),
         st_x(st_transform(st_centroid(st_collect(p.g)), 4326)),
         count(*)::int,
         coalesce(sum(p.dead), 0)::int,
         coalesce(sum(p.serious), 0)::int,
         coalesce(sum(p.minor), 0)::int,
         count(*) filter (where p.major)::int,
         (count(*) * 3 + coalesce(sum(p.dead), 0) * 12
          + coalesce(sum(p.serious), 0) * 6 + coalesce(sum(p.minor), 0) * 3)::int,
         round(st_maxdistance(st_collect(p.g), st_collect(p.g)))::int,
         count(*) filter (where p.is_node)::int,
         mode() within group (order by p.place),
         mode() within group (order by p.road),
         mode() within group (order by p.rchar),
         mode() within group (order by p.tambon)
    from tmp_hot_pt p join tmp_hot_asg a on a.acc_id = p.acc_id
   group by a.cid;

  select count(*)::int into v_total
    from tmp_hot_cell where n >= v_min or (dead + serious) >= v_sev;

  if v_total = 0 then
    return jsonb_build_object('found', 0, 'clusters', v_cid,
                              'nodes', v_nodes, 'guessedPairs', v_guess,
                              'cells', jsonb_build_array());
  end if;

  v_lines := array[
    v_title,
    'ในรอบ ' || v_days || ' วันที่ผ่านมา'
  ];

  for c in
    select * from tmp_hot_cell
     where n >= v_min or (dead + serious) >= v_sev
     order by dead desc, score desc, n desc, lat, lng
     limit v_top
  loop
    v_rank := v_rank + 1;

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
    || case when v_total > 1 and v_rank < least(v_total, v_top) then array[''] else array[]::text[] end;

    -- เก็บจุดนี้ไว้เป็นข้อมูล ไม่เกี่ยวกับข้อความที่ส่งเข้าไลน์
    v_cells := v_cells || jsonb_build_array(jsonb_build_object(
      'rank',    v_rank,
      'place',   c.place,
      'road',    c.road,
      'rchar',   c.rchar,
      'tambon',  c.tambon,
      'n',       c.n,
      'dead',    c.dead,
      'serious', c.serious,
      'minor',   c.minor,
      'major',   c.major,
      'lat',     round(c.lat::numeric, 6),
      'lng',     round(c.lng::numeric, 6)));

    v_sig := v_sig || round(c.lat::numeric, 4) || ',' || round(c.lng::numeric, 4)
             || '=' || c.n || '/' || c.dead || '/' || c.serious || '/' || c.minor || ';';
  end loop;

  v_lines := v_lines || case when coalesce((select (val #>> array[]::text[]) from bs_settings where key = 'hotspotAgencyLine'), '') = '' then array[]::text[] else array[(select (val #>> array[]::text[]) from bs_settings where key = 'hotspotAgencyLine'), ''] end;

  if v_site <> '' then
    v_lines := v_lines || array['รายละเอียดที่นี่', v_site];
  end if;

  return jsonb_build_object(
    'found', v_total, 'listed', v_rank, 'topN', v_top,
    'clusters', v_cid, 'nodePoints', v_nodes, 'guessedPairs', v_guess,
    'metres', v_r, 'month', v_month,
    'min_per_cell', v_min, 'severe_min', v_sev,
    'ref',  v_month || ':node:' || v_sig,
    'cells', v_cells,
    'text', array_to_string(v_lines, chr(10)));
end;
$fn$;

-- คำนวณใหม่ทันที แคชจะได้มีรายการจุดเลย ไม่ต้องรอรอบถัดไป
select line_hotspot_refresh();

-- ตรวจ  จำนวนจุดในรายการต้องเท่ากับจำนวนที่เขียนลงข้อความ
-- และทุกจุดต้องมีพิกัดครบ ถ้าพิกัดว่างแปลว่าเหตุในกลุ่มนั้นไม่ได้กรอกพิกัดไว้
select
  (select body ->> 'found' from line_hotspot_cache where id = 1)                as จุดที่เข้าเกณฑ์,
  (select body ->> 'listed' from line_hotspot_cache where id = 1)               as เขียนลงข้อความ,
  (select jsonb_array_length(body -> 'cells') from line_hotspot_cache where id = 1) as จุดในรายการ,
  (select string_agg(
     (x ->> 'rank') || '  ' || coalesce(x ->> 'place', coalesce(x ->> 'road', 'ไม่ระบุ'))
     || '  ' || (x ->> 'n') || ' ครั้ง  พิกัด ' || coalesce(x ->> 'lat', 'ไม่มี') || ',' || coalesce(x ->> 'lng', 'ไม่มี'),
     chr(10) order by (x ->> 'rank')::int)
     from line_hotspot_cache h, jsonb_array_elements(h.body -> 'cells') x
    where h.id = 1)                                                             as รายการจุด;

-- จบไฟล์  อย่าเคาะบรรทัดใหม่ต่อท้ายบรรทัดนี้ ->
