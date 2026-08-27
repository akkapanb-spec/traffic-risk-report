-- ให้บอทตอบคีย์เวิร์ดเดิม ด้วยเนื้อหาเดิม แต่ตัวเลขนับสดทุกครั้ง
-- ถ้ามีอักขระแปลกปลอมต่อท้ายบรรทัดสุดท้าย ให้ลบออกก่อนกด Run
-- ใช้แทน line_pub_1_answer.sql  ไฟล์นั้นไม่ต้องรัน
--
-- ต้องรัน line_pub_3_hotspot.sql ก่อนไฟล์นี้
-- เพราะไฟล์นี้เรียกใช้ line_road_full ซึ่งสร้างอยู่ในไฟล์นั้น
--
-- ------------------------------------------------------------
-- ทำไมต้องย้ายมาไว้ในฐานข้อมูล
-- ------------------------------------------------------------
-- คำตอบเดิมตั้งไว้ในระบบของไลน์ เป็นข้อความที่พิมพ์ตัวเลขแช่ไว้ล่วงหน้า
-- และมีวันหมดอายุ  ณ 28 ส.ค. 2569
--   ac-w หมดอายุ 30 ส.ค.  และเนื้อหายังเป็นสัปดาห์ 17-23 ส.ค. ที่ผ่านไปแล้ว
--   ac-m หมดอายุ 31 ส.ค.
-- พอหมดอายุ ประชาชนพิมพ์แล้วเงียบ ซึ่งแย่กว่าไม่มีให้พิมพ์
-- เพราะเขาจะสรุปว่าระบบพัง แล้วเลิกถามไปเลย
--
-- ไฟล์นี้ให้ฐานข้อมูลเป็นคนตอบแทน คีย์เวิร์ดเดิมทุกตัว รูปแบบเดิมทุกบรรทัด
-- ต่างกันแค่ตัวเลขนับใหม่ทุกครั้งที่มีคนถาม จึงไม่มีวันเก่าและไม่มีวันหมดอายุ
--
-- การตอบกลับคนที่ทักมาไม่นับโควตาข้อความของไลน์ ทั้งของเดิมและของนี้
-- การย้ายจึงไม่ได้เพิ่มค่าใช้จ่ายเลย ที่ประหยัดคือแรงงานคนที่ต้องมาพิมพ์ใหม่ทุกเดือน
--
-- ------------------------------------------------------------
-- หลังรันไฟล์นี้ ต้องปิดคำตอบสำเร็จรูปในระบบไลน์
-- ------------------------------------------------------------
-- ถ้าไม่ปิด ประชาชนจะได้คำตอบสองฉบับพร้อมกัน และตัวเลขจะไม่ตรงกัน
-- ให้ปิดสามรายการ คือ ac-w  ac-m  ac-y
-- ส่วน ช่วยเหลือ เก็บไว้ได้ เพราะเป็นข้อความทักทาย ไม่ใช่ตัวเลข

-- ==========================================================
-- 1  ตัวช่วยวันที่ไทย
-- ==========================================================

create or replace function line_thai_dm(p_d date)
returns text
language sql
immutable
as $fn$
  select extract(day from p_d)::int || ' ' ||
         (array['ม.ค.','ก.พ.','มี.ค.','เม.ย.','พ.ค.','มิ.ย.',
                'ก.ค.','ส.ค.','ก.ย.','ต.ค.','พ.ย.','ธ.ค.'])[extract(month from p_d)::int];
$fn$;

create or replace function line_thai_year(p_d date)
returns text
language sql
immutable
as $fn$
  select (extract(year from p_d)::int + 543)::text;
$fn$;

-- ==========================================================
-- 1.5  ลิงก์แผนที่จากพิกัด
-- ==========================================================
-- พิกัดที่เป็นตัวเลขเปล่า ๆ คนต้องคัดลอกไปวางในแอปแผนที่เอง ซึ่งแทบไม่มีใครทำ
-- ทำเป็นลิงก์ให้กดเปิดได้ทันที ข้อมูลเดิมจึงถูกใช้จริง
--
-- ต้องตัดช่องว่างออกก่อน เพราะพิกัดในฐานข้อมูลเก็บเป็น 15.724810, 100.060615
-- ช่องว่างในที่อยู่เว็บทำให้ลิงก์ขาดตรงกลาง แล้วเปิดไม่ติด

create or replace function line_map_link(p_coord text)
returns text
language sql
immutable
as $fn$
  select case
    when nullif(btrim(coalesce(p_coord, '')), '') is null then null
    else 'https://www.google.com/maps?q=' || replace(btrim(p_coord), ' ', '')
  end;
$fn$;

-- ==========================================================
-- 2  สรุปอุบัติเหตุรอบสัปดาห์  ตอบคีย์เวิร์ด ac-w
-- ==========================================================
-- ใช้สัปดาห์เต็มล่าสุด จันทร์ถึงอาทิตย์ ที่ผ่านไปแล้ว
-- ไม่ใช้เจ็ดวันย้อนหลังแบบเลื่อนไปเรื่อย เพราะคนอ่านเทียบสัปดาห์ต่อสัปดาห์ไม่ได้
-- และตรงกับรูปแบบเดิมที่เคยตั้งไว้ คือ 17-23 ส.ค.

create or replace function line_msg_ac_w()
returns text
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_end   date := (date_trunc('week', line_today())::date) - 1;   -- อาทิตย์ที่แล้ว
  v_start date := v_end - 6;                                       -- จันทร์ที่แล้ว
  v_pstart date := v_start - 7;
  v_pend   date := v_end - 7;
  v_now  jsonb;
  v_prev jsonb;
  v_lines text[];
  v_site text := coalesce((select val #>> array[]::text[] from bs_settings where key='publicSiteUrl'), '');
  r record;
  v_diff int;
begin
  v_now  := line_acc_counts(timezone('Asia/Bangkok', v_start::timestamp),
                            timezone('Asia/Bangkok', (v_end + 1)::timestamp));
  v_prev := line_acc_counts(timezone('Asia/Bangkok', v_pstart::timestamp),
                            timezone('Asia/Bangkok', (v_pend + 1)::timestamp));

  v_diff := (v_now->>'accidents')::int - (v_prev->>'accidents')::int;

  v_lines := array[
    '📊 สรุปอุบัติเหตุรอบสัปดาห์ ' ||
      extract(day from v_start)::int || '-' || line_thai_dm(v_end) || ' ' || line_thai_year(v_end),
    '• อุบัติเหตุ ' || (v_now->>'accidents') || ' ครั้ง (' ||
      case when v_diff > 0 then '🔺 +' || v_diff
           when v_diff < 0 then '🔻 ' || v_diff
           else 'เท่าเดิม' end ||
      ' จาก ' || (v_prev->>'accidents') || ')',
    '• เสียชีวิต ' || (v_now->>'deaths') || ' ราย'
  ];

  -- รายจุดที่เสียชีวิต  อ่านจากตาราง deaths ซึ่งมีถนนกับพิกัดครบ
  for r in
    select line_road_full(road_name) as road,
           nullif(btrim(coordinates), '') as coord
    from deaths
    where incident_datetime >= timezone('Asia/Bangkok', v_start::timestamp)
      and incident_datetime <  timezone('Asia/Bangkok', (v_end + 1)::timestamp)
    order by incident_datetime
  loop
    v_lines := v_lines || array['📌ถนน: ' || r.road];
    if r.coord is not null then
      v_lines := v_lines || array['      พิกัด: ' || line_map_link(r.coord)];
    end if;
  end loop;

  v_lines := v_lines || array['• สาหัส/หมดสติ ' || (v_now->>'severe') || ' ราย'];

  -- รายจุดที่สาหัสหรือหมดสติ  ตาราง injuries เก็บแต่ข้อมูลดิบ
  -- จึงต้องอ่านจาก accidents โดยตรง และนับเฉพาะรายที่มีอาการสองกลุ่มนี้
  for r in
    select line_road_full(a.road) as road,
           case when a.latitude is not null and a.longitude is not null
                then to_char(a.latitude, 'FM990.000000') || ', ' || to_char(a.longitude, 'FM990.000000')
           end as coord
    from accidents a
    where a.incident_datetime >= timezone('Asia/Bangkok', v_start::timestamp)
      and a.incident_datetime <  timezone('Asia/Bangkok', (v_end + 1)::timestamp)
      and exists (
        select 1 from jsonb_array_elements(
          jsonb_build_array(coalesce(a.party1, jsonb_build_object()), coalesce(a.party2, jsonb_build_object()))
          || case when jsonb_typeof(a.party1->'passengers') = 'array' then a.party1->'passengers' else jsonb_build_array() end
          || case when jsonb_typeof(a.party2->'passengers') = 'array' then a.party2->'passengers' else jsonb_build_array() end
        ) e where e->>'injury' in ('สาหัส', 'หมดสติ'))
    order by a.incident_datetime
  loop
    v_lines := v_lines || array['📌ถนน: ' || r.road];
    if r.coord is not null then
      v_lines := v_lines || array['      พิกัด: ' || line_map_link(r.coord)];
    end if;
  end loop;

  if v_site <> '' then
    v_lines := v_lines || array['ติดตามได้ที่นี่' || v_site];
  end if;

  return array_to_string(v_lines, chr(10));
end;
$fn$;

-- ==========================================================
-- 3  สรุปผู้เสียชีวิตรอบเดือน  ตอบคีย์เวิร์ด ac-m
-- ==========================================================
-- คู่กรณีสร้างจากยานพาหนะสองฝ่ายในตาราง accidents
-- ของเดิมเขียนด้วยมือว่า ชนท้าย ซึ่งเป็นรายละเอียดที่ข้อมูลไม่มี
-- จึงเขียนว่า ชนกับ ซึ่งเป็นสิ่งที่ยืนยันได้จากข้อมูลจริง

create or replace function line_msg_ac_m()
returns text
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_first date := date_trunc('month', line_today())::date;
  v_lines text[];
  v_site text := coalesce((select val #>> array[]::text[] from bs_settings where key='publicSiteUrl'), '');
  v_n int;
  r record;
begin
  select count(*) into v_n from deaths
   where incident_datetime >= timezone('Asia/Bangkok', v_first::timestamp);

  v_lines := array[
    '📊 สรุปอุบัติเหตุเสียชีวิตรอบเดือน',
    line_thai_dm(v_first) || ' ' || line_thai_year(v_first) || ' – ปัจจุบัน',
    '🚑 เสียชีวิต ' || v_n || ' ราย'
  ];

  for r in
    select d.incident_datetime as t,
           line_road_full(d.road_name) as road,
           nullif(btrim(d.coordinates), '') as coord,
           a.party1->>'vehicle' as v1,
           a.party2->>'vehicle' as v2,
           nullif(btrim(d.vehicle_type), '') as dv
    from deaths d
    left join accidents a on a.incident_datetime = d.incident_datetime
    where d.incident_datetime >= timezone('Asia/Bangkok', v_first::timestamp)
    order by d.incident_datetime
  loop
    v_lines := v_lines || array[
      '🚨วันที่ ' || to_char(r.t at time zone 'Asia/Bangkok', 'DD/MM/') ||
        (extract(year from r.t at time zone 'Asia/Bangkok')::int + 543) ||
        ' เวลา ' || to_char(r.t at time zone 'Asia/Bangkok', 'HH24:MI') || ' น.'
    ];

    -- เขียนคู่กรณีเมื่อรู้ทั้งสองฝ่าย ถ้ารู้ฝ่ายเดียวก็เขียนเท่าที่รู้
    if r.v1 is not null and r.v2 is not null then
      v_lines := v_lines || array['       ' || r.v1 || ' ชนกับ ' || r.v2];
    elsif coalesce(r.v1, r.dv) is not null then
      v_lines := v_lines || array['       ' || coalesce(r.v1, r.dv)];
    end if;

    v_lines := v_lines || array['       ถนน : ' || r.road];
    if r.coord is not null then
      v_lines := v_lines || array['       พิกัด: ' || line_map_link(r.coord)];
    end if;
  end loop;

  if v_site <> '' then
    v_lines := v_lines || array['ติดตามได้ที่นี่' || v_site];
  end if;

  return array_to_string(v_lines, chr(10));
end;
$fn$;

-- ==========================================================
-- 4  สรุปผู้เสียชีวิตรอบปี  ตอบคีย์เวิร์ด ac-y
-- ==========================================================
-- ตัวเลขที่เลือกมาแสดง เป็นตัวที่ชี้ไปที่การป้องกันได้
-- ไม่สวมหมวกนิรภัยคือตัวที่แก้ได้ทันทีด้วยตัวเอง จึงต้องอยู่ในนั้นเสมอ

create or replace function line_msg_ac_y()
returns text
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_first date := date_trunc('year', line_today())::date;
  v_from timestamptz := timezone('Asia/Bangkok', v_first::timestamp);
  v_acc int;
  v_dead int;
  v_male int;
  v_female int;
  v_veh text;
  v_nohelmet int;
  v_road text;
  v_auth text;
  v_lines text[];
  v_site text := coalesce((select val #>> array[]::text[] from bs_settings where key='publicSiteUrl'), '');
begin
  select count(*) into v_dead from deaths where incident_datetime >= v_from;

  -- นับอุบัติเหตุที่มีผู้เสียชีวิต ไม่ใช่อุบัติเหตุทั้งหมด
  select count(distinct date_trunc('minute', incident_datetime)) into v_acc
    from deaths where incident_datetime >= v_from;

  select count(*) filter (where gender = 'ชาย'),
         count(*) filter (where gender in ('หญิง', 'ผู้หญิง')),
         count(*) filter (where safety_equipment ilike '%ไม่สวมหมวก%')
    into v_male, v_female, v_nohelmet
    from deaths where incident_datetime >= v_from;

  select nullif(btrim(vehicle_type), '') || ' ' || count(*) || ' ราย' into v_veh
    from deaths where incident_datetime >= v_from and nullif(btrim(vehicle_type), '') is not null
   group by nullif(btrim(vehicle_type), '') order by count(*) desc, 1 limit 1;

  select line_road_full(nullif(btrim(road_name), '')) || ' ' || count(*) || ' ราย' into v_road
    from deaths where incident_datetime >= v_from and nullif(btrim(road_name), '') is not null
   group by nullif(btrim(road_name), '') order by count(*) desc, 1 limit 1;

  select nullif(btrim(a.local_authority), '') || ' ' || count(*) || ' ราย' into v_auth
    from deaths d join accidents a on a.incident_datetime = d.incident_datetime
   where d.incident_datetime >= v_from and nullif(btrim(a.local_authority), '') is not null
   group by nullif(btrim(a.local_authority), '') order by count(*) desc, 1 limit 1;

  v_lines := array[
    '📊 สรุปอุบัติเหตุเสียชีวิตรอบปี',
    line_thai_dm(v_first) || ' ' || line_thai_year(v_first) || ' – ปัจจุบัน',
    '• อุบัติเหตุ ' || v_acc || ' ครั้ง  เสียชีวิต ' || v_dead || ' ราย',
    '       เพศ: 👨 ' || v_male || ' ราย 👩 ' || v_female || ' ราย'
  ];

  if v_veh is not null then
    v_lines := v_lines || array['       ยานพาหนะ: ' || v_veh];
  end if;
  v_lines := v_lines || array['      ไม่สวมหมวกนิรภัย: ' || v_nohelmet || ' ราย'];
  if v_road is not null then
    v_lines := v_lines || array['       ถนน : ' || v_road];
  end if;
  if v_auth is not null then
    v_lines := v_lines || array['       อปท.: ' || v_auth];
  end if;

  v_lines := v_lines || array[
    'งานจราจร สภ.เมืองนครสวรรค์',
    'ขอแสดงความเสียใจมา ณ ที่นี้',
    'ติดตามรายละเอียดเพิ่มเติม ได้ที่นี่'
  ];
  if v_site <> '' then
    v_lines := v_lines || array[v_site];
  end if;
  v_lines := v_lines || array['การสัญจรปลอดภัย คือความห่วงใยของเรา ❤️'];

  return array_to_string(v_lines, chr(10));
end;
$fn$;

-- ==========================================================
-- 5  ตัวจับคีย์เวิร์ด อยู่ในไฟล์ line_pub_3_hotspot.sql
-- ==========================================================
-- เดิมไฟล์นี้สร้าง line_pub_answer ด้วย ทำให้เมื่อรันทีหลังไฟล์ 3
-- มันไปสร้างทับฉบับที่รู้จัก ac-r กับ help แล้วสองคีย์เวิร์ดนั้นเงียบไป
-- เกิดขึ้นจริงเมื่อ 28 ส.ค. 2569
--
-- ตัวจับคีย์เวิร์ดจึงต้องมีที่เดียว คืออยู่ในไฟล์ 3 เท่านั้น
-- ไฟล์นี้เหลือหน้าที่สร้างข้อความอย่างเดียว รันสลับลำดับกันได้โดยไม่พัง

-- ==========================================================
-- 6  ตอบเฉพาะแชทส่วนตัวกับบัญชีทางการ ไม่ตอบในกลุ่ม
-- ==========================================================
-- กลุ่มมีสมาชิก 208 คน ถ้าใครพิมพ์คีย์เวิร์ดในกลุ่ม ทุกคนจะได้รับข้อความนั้น
-- คนที่ไม่ได้ถามจะรู้สึกว่าถูกรบกวน แล้วออกจากกลุ่ม
-- บอทที่พูดในกลุ่มบ่อยเกินไปคือบอทที่ถูกเตะออกจากกลุ่ม
--
-- ตรรกะกิจกรรมแจกหมวกใน line_reply กันเรื่องนี้ไว้อยู่แล้ว
-- ส่วนคีย์เวิร์ดสถิติเพิ่งเพิ่มเข้ามา จึงต้องกันด้วยเงื่อนไขเดียวกัน
--
-- แก้บรรทัดเดียวในโค้ดที่ติดตั้งอยู่ ไม่พิมพ์ line_reply ใหม่ทั้งตัว

do $fn$
declare
  v_src text;
  v_a   text;
  v_n   int;
begin
  select pg_get_functiondef(p.oid) into v_src
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'line_reply';

  if v_src is null then
    raise exception 'ไม่พบ line_reply';
  end if;

  if position('case when coalesce(p_source_type' in v_src) > 0 then
    raise notice 'กันไว้แล้ว ไม่ต้องทำซ้ำ';
    return;
  end if;

  v_a := '  v_pub := line_pub_answer(v_q);';
  v_n := (length(v_src) - length(replace(v_src, v_a, ''))) / length(v_a);
  if v_n <> 1 then
    raise exception 'จุดยึดพบ % แห่ง ไม่ใช่ 1 แห่ง จึงไม่แก้ ให้รัน line_pub_1_answer.sql ก่อน', v_n;
  end if;

  v_src := replace(v_src, v_a,
    '  v_pub := case when coalesce(p_source_type, ''user'') = ''user''' ||
    chr(13) || chr(10) ||
    '                 then line_pub_answer(v_q) else null end;');

  execute v_src;
  raise notice 'กันไม่ให้ตอบในกลุ่มแล้ว';
end;
$fn$;

-- ==========================================================
-- ตรวจผล  คำสั่งสุดท้ายคำสั่งเดียวที่จะแสดงผล
-- ==========================================================
-- เอาของจริงออกมาอ่านเทียบกับของเดิมทีละบรรทัดก่อนปิดของเดิมในระบบไลน์

select 'ac-w  สรุปรอบสัปดาห์' as คีย์เวิร์ด, line_msg_ac_w() as คำตอบ
union all
select 'ac-m  เสียชีวิตรอบเดือน', line_msg_ac_m()
union all
select 'ac-y  เสียชีวิตรอบปี', line_msg_ac_y()
union all
select 'ต่อเข้ากับบอทแล้วไหม',
       coalesce((select case when prosrc like '%line_pub_answer%' then 'ต่อแล้ว' else 'ยังไม่ต่อ ให้รัน line_pub_1_answer.sql ส่วนท้ายก่อน' end
                 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
                 where n.nspname='public' and p.proname='line_reply'), 'ไม่พบ');
