-- เก็บร่องรอยฝนและคำนวณเวลาที่คาดว่าจะถึง
-- ถ้ามีอักขระแปลกปลอมต่อท้ายบรรทัดสุดท้าย ให้ลบออกก่อนกด Run
-- ใช้แทนส่วนคำนวณใน rain_9_track.sql  ตารางเดิมใช้ต่อได้ ไม่ต้องสร้างใหม่
-- ต้อง deploy Edge Function ชื่อ rain ฉบับที่มีตัวหาทิศทางก่อน
--
-- ------------------------------------------------------------
-- ทำไมต้องเขียนทับของเดิม
-- ------------------------------------------------------------
-- rain_9_track.sql คำนวณทิศจากจุดศูนย์กลางของกลุ่มฝน
-- ทดสอบกับภาพจริงหกใบเมื่อ 28 ส.ค. 2569 ได้ 173 กม./ชม. แกว่ง บวกลบ 144
-- ซึ่งเป็นไปไม่ได้ ฝนไม่เคลื่อนที่เร็วกว่าเครื่องบิน
-- สาเหตุคือในภาพมีกลุ่มฝนหลายก้อน จุดศูนย์กลางเฉลี่ยจึงกระโดดตามก้อนที่โผล่และหาย
--
-- ตัวอ่านเรดาร์จึงเปลี่ยนไปใช้การเลื่อนภาพไปทับกัน ซึ่งข้อมูลชุดเดียวกัน
-- ให้ 12 กม./ชม. แกว่ง บวกลบ 9  และส่งทิศทางมาให้พร้อมแล้ว
-- ฐานข้อมูลจึงไม่ต้องคำนวณทิศเองอีก เหลือแค่เก็บและคำนวณเวลาที่จะถึง

-- ==========================================================
-- 1  เพิ่มช่องเก็บทิศทางในตารางเดิม
-- ==========================================================

alter table rain_track add column if not exists east_kmh   numeric;
alter table rain_track add column if not exists north_kmh  numeric;
alter table rain_track add column if not exists near_east  numeric;
alter table rain_track add column if not exists near_north numeric;
alter table rain_track add column if not exists spread_kmh numeric;

-- ==========================================================
-- 2  คำนวณเวลาที่คาดว่าฝนจะถึงแยกเดชาติวงศ์
-- ==========================================================
-- ใช้รอบล่าสุดรอบเดียว ไม่ต้องเทียบสองรอบอีกแล้ว
-- เพราะตัวอ่านเรดาร์คำนวณทิศจากภาพย้อนหลังของกรมฯ มาให้เสร็จแล้ว
--
-- วิธีคิด
--   ฝนที่ใกล้ที่สุดอยู่ที่ตำแหน่ง E ตะวันออก N เหนือ จากแยกเดชาติวงศ์
--   ฝนเคลื่อนด้วยความเร็ว vE ตะวันออก vN เหนือ
--   ความเร็วที่เข้าหาเรา คือส่วนของความเร็วที่ชี้กลับมาหาจุดศูนย์
--   เวลาที่จะถึง คือระยะหารด้วยความเร็วเข้าหา
--
-- ถ้าความเร็วเข้าหาติดลบ แปลว่าฝนกำลังออกห่าง ไม่ต้องเตือน
-- ตรงนี้คือข้อได้เปรียบเหนือการลดเกณฑ์พื้นที่
-- การลดเกณฑ์เตือนทั้งฝนที่กำลังมาและฝนที่กำลังไป วิธีนี้แยกสองอย่างออกจากกัน

create or replace function rain_eta(p_row rain_track)
returns jsonb
language plpgsql
immutable
as $fn$
declare
  v_dist    numeric;
  v_closing numeric;
  v_eta     numeric;
begin
  if p_row.near_east is null or p_row.east_kmh is null then
    return jsonb_build_object('ok', false, 'why', 'ไม่มีข้อมูลทิศทางหรือไม่มีฝนในวง');
  end if;

  v_dist := sqrt(p_row.near_east ^ 2 + p_row.near_north ^ 2);
  if v_dist < 0.5 then
    return jsonb_build_object('ok', true, 'arrived', true, 'etaMin', 0);
  end if;

  -- ความเร็วที่เข้าหาจุดศูนย์  เป็นบวกเมื่อฝนวิ่งเข้าหาเรา
  v_closing := -(p_row.near_east * p_row.east_kmh + p_row.near_north * p_row.north_kmh) / v_dist;

  if v_closing <= 1 then
    return jsonb_build_object('ok', true, 'approaching', false,
      'why', 'ฝนไม่ได้เข้าหาตัวเมือง',
      'distKm', round(v_dist, 1), 'closingKmh', round(v_closing, 1));
  end if;

  v_eta := v_dist / v_closing * 60;

  return jsonb_build_object('ok', true, 'approaching', true,
    'distKm', round(v_dist, 1),
    'closingKmh', round(v_closing, 1),
    'etaMin', round(v_eta),
    'spreadKmh', p_row.spread_kmh);
end;
$fn$;

-- ==========================================================
-- 3  ให้ตัวอ่านผลบันทึกทุกรอบลงตาราง
-- ==========================================================
-- แทรกเข้า rain_alert_collect โดยแตะให้น้อยที่สุด เหมือนที่ทำกับ line_reply
-- อ่านโค้ดที่ติดตั้งอยู่จริงมาแก้ ไม่พิมพ์ใหม่ทั้งตัว
-- นับจุดยึดก่อนแทนที่ ถ้าไม่เจอพอดีหนึ่งแห่งให้หยุด ไม่ติดตั้งอะไรเลย

do $fn$
declare
  v_src  text;
  v_crlf text := chr(13) || chr(10);
  v_a    text;
  v_n    int;
begin
  select pg_get_functiondef(p.oid) into v_src
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'rain_alert_collect';

  if v_src is null then
    raise exception 'ไม่พบ rain_alert_collect';
  end if;

  if position('rain_track' in v_src) > 0 then
    raise notice 'ต่อไว้แล้ว ไม่ต้องทำซ้ำ';
    return;
  end if;

  v_a := '  v_pct   := coalesce((v_j->>''rainPercent'')::numeric, 0);';
  v_n := (length(v_src) - length(replace(v_src, v_a, ''))) / length(v_a);
  if v_n <> 1 then
    raise exception 'จุดยึดพบ % แห่ง ไม่ใช่ 1 แห่ง จึงไม่แก้', v_n;
  end if;

  v_src := replace(v_src, v_a,
    v_a || v_crlf || v_crlf ||
    '  -- บันทึกร่องรอยทุกรอบ ไม่ว่าจะส่งข้อความหรือไม่' || v_crlf ||
    '  -- เก็บไว้ให้ตรวจย้อนหลังได้ว่าที่ทำนายไว้ตรงกับที่เกิดจริงแค่ไหน' || v_crlf ||
    '  insert into rain_track (pct8, nearest_km, outer_px, clat, clng,' || v_crlf ||
    '                          east_kmh, north_kmh, near_east, near_north, spread_kmh)' || v_crlf ||
    '  values (v_pct,' || v_crlf ||
    '          nullif(v_j->>''nearestKm'', '''')::numeric,' || v_crlf ||
    '          nullif(v_j->>''outerRainPixels'', '''')::int,' || v_crlf ||
    '          nullif(v_j->>''centroidLat'', '''')::float8,' || v_crlf ||
    '          nullif(v_j->>''centroidLng'', '''')::float8,' || v_crlf ||
    '          nullif(v_j#>>array[''motion'',''eastKmh''], '''')::numeric,' || v_crlf ||
    '          nullif(v_j#>>array[''motion'',''northKmh''], '''')::numeric,' || v_crlf ||
    '          nullif(v_j->>''nearestEastKm'', '''')::numeric,' || v_crlf ||
    '          nullif(v_j->>''nearestNorthKm'', '''')::numeric,' || v_crlf ||
    '          nullif(v_j#>>array[''motion'',''spreadKmh''], '''')::numeric);' || v_crlf || v_crlf ||
    '  delete from rain_track where seen_at < now() - interval ''30 days'';' || v_crlf);

  execute v_src;
  raise notice 'ต่อเข้ากับ rain_alert_collect แล้ว';
end;
$fn$;

-- ==========================================================
-- ตรวจผล  คำสั่งสุดท้ายคำสั่งเดียวที่จะแสดงผล
-- ==========================================================

select 'ตัวเก็บข้อมูล' as รายการ,
       coalesce((select case when prosrc like '%rain_track%' then 'ต่อแล้ว' else 'ยังไม่ต่อ' end
                 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
                 where n.nspname='public' and p.proname='rain_alert_collect'), 'ไม่พบ') as ผล
union all
select 'ช่องในตาราง',
       (select string_agg(column_name, ' ' order by ordinal_position)
        from information_schema.columns where table_schema='public' and table_name='rain_track')
union all
select 'ข้อมูลที่เก็บไว้', (select count(*)::text from rain_track) || ' รอบ'
union all
select 'สวิตช์คำทำนาย',
       coalesce((select val #>> array[]::text[] from bs_settings where key='rainForecastEnabled'), '-')
       || '   ยังปิดไว้ตามที่ตั้งใจ'
union all
select 'ขั้นต่อไป', 'รอรอบตรวจถัดไป แล้วดูว่ามีแถวเข้ามาในตารางไหม';
