-- เพิ่มช่องประเภทรถคู่กรณี ในการบันทึกข้อมูลผู้เสียชีวิต
-- ถ้ามีอักขระแปลกปลอมต่อท้ายบรรทัดสุดท้าย ให้ลบออกก่อนกด Run
--
-- ------------------------------------------------------------
-- ทำไมต้องมีช่องนี้
-- ------------------------------------------------------------
-- เดิมบันทึกได้แต่ประเภทรถของผู้เสียชีวิต ไม่รู้ว่าชนกับอะไร
-- ข้อความแจ้งเตือนรายเดือนจึงต้องไปดึงคู่กรณีจากตาราง accidents
-- ซึ่งจับคู่ด้วยเวลาเกิดเหตุ และพลาดเมื่อเวลาไม่ตรงกันเป๊ะ
-- เหตุวันที่ 19 ส.ค. 2569 จับคู่ไม่ได้ ข้อความจึงขาดบรรทัดคู่กรณีไป
--
-- และเมื่อผู้เสียชีวิตเป็นคนเดินเท้า ประเภทรถของตัวเองไม่มีความหมาย
-- สิ่งที่ต้องรู้คือรถที่ชน ซึ่งไม่มีที่เก็บมาก่อน
--
-- ------------------------------------------------------------
-- ต้องลบฟังก์ชันเดิมทิ้งก่อน ห้ามสร้างทับเฉย ๆ
-- ------------------------------------------------------------
-- PostgREST เลือกฟังก์ชันจากชุดพารามิเตอร์ที่ตรงกันเป๊ะ
-- ถ้าปล่อยตัวเดิมที่ไม่มี p_cp_vehicle ไว้ จะมีสองตัวให้เลือก
-- แล้วการเรียกจะกำกวม ระบบตอบว่าหาฟังก์ชันไม่เจอ ทั้งที่มีอยู่สองตัว
-- บทเรียนเดียวกับตอนแก้ line_reply ในกิจกรรมแจกหมวก

-- ==========================================================
-- 1  ช่องใหม่ในตาราง
-- ==========================================================

alter table deaths add column if not exists counterpart_vehicle text;

-- ==========================================================
-- 2  ลบฟังก์ชันเดิม
-- ==========================================================

drop function if exists admin_add_death(
  text, timestamptz, int, text, text, text, text, text, text, text,
  text, text, text, text, text, text, text);

drop function if exists admin_update_death(
  text, bigint, timestamptz, int, text, text, text, text, text, text, text,
  text, text, text, text, text, text, text);

-- ==========================================================
-- 3  สร้างใหม่พร้อมช่องคู่กรณี
-- ==========================================================
-- คนเดินเท้าไม่มีรถของตัวเอง ถ้าเผลอบันทึกมาก็ล้างทิ้งที่นี่
-- กันไว้ทั้งสองชั้น ทั้งหน้าเว็บและฐานข้อมูล
-- เพราะหน้าเว็บแก้ได้ด้วยเครื่องมือนักพัฒนา แต่ฐานข้อมูลแก้ไม่ได้

create or replace function admin_add_death(
  p_token text, p_datetime timestamptz, p_age int, p_gender text, p_status text,
  p_vehicle text, p_cp_vehicle text, p_safety text, p_injury text, p_body text, p_license text,
  p_road_type text, p_cause text, p_highway_type text, p_road_name text,
  p_subdistrict text, p_coordinates text, p_domicile text
) returns jsonb
language plpgsql security definer set search_path = public as $fn$
declare
  v_err jsonb;
  v_veh text := nullif(trim(coalesce(p_vehicle, '')), '');
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  if p_datetime is null then
    return jsonb_build_object('success', false, 'message', 'กรุณาระบุวันที่และเวลาเกิดเหตุ');
  end if;

  if trim(coalesce(p_status, '')) = 'คนเดินเท้า' then
    v_veh := null;
  end if;

  insert into deaths(incident_datetime, age, gender, status, vehicle_type, counterpart_vehicle,
    safety_equipment, col_g, col_h, license, road_type, cause, col_l, road_name,
    subdistrict, coordinates, domicile)
  values (p_datetime, p_age, nullif(trim(p_gender), ''), nullif(trim(p_status), ''),
    v_veh, nullif(trim(coalesce(p_cp_vehicle, '')), ''),
    nullif(trim(p_safety), ''), nullif(trim(p_injury), ''), nullif(trim(p_body), ''),
    nullif(trim(p_license), ''), nullif(trim(p_road_type), ''), nullif(trim(p_cause), ''),
    nullif(trim(p_highway_type), ''), nullif(trim(p_road_name), ''), nullif(trim(p_subdistrict), ''),
    nullif(trim(p_coordinates), ''), nullif(trim(p_domicile), ''));

  return jsonb_build_object('success', true, 'message', 'บันทึกข้อมูลผู้เสียชีวิตเรียบร้อย');
end $fn$;

create or replace function admin_update_death(
  p_token text, p_id bigint, p_datetime timestamptz, p_age int, p_gender text, p_status text,
  p_vehicle text, p_cp_vehicle text, p_safety text, p_injury text, p_body text, p_license text,
  p_road_type text, p_cause text, p_highway_type text, p_road_name text,
  p_subdistrict text, p_coordinates text, p_domicile text
) returns jsonb
language plpgsql security definer set search_path = public as $fn$
declare
  v_err jsonb;
  v_veh text := nullif(trim(coalesce(p_vehicle, '')), '');
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  if p_id is null then
    return jsonb_build_object('success', false, 'message', 'ไม่พบรายการที่จะแก้ไข');
  end if;

  if trim(coalesce(p_status, '')) = 'คนเดินเท้า' then
    v_veh := null;
  end if;

  update deaths set
    incident_datetime   = coalesce(p_datetime, incident_datetime),
    age                 = p_age,
    gender              = nullif(trim(p_gender), ''),
    status              = nullif(trim(p_status), ''),
    vehicle_type        = v_veh,
    counterpart_vehicle = nullif(trim(coalesce(p_cp_vehicle, '')), ''),
    safety_equipment    = nullif(trim(p_safety), ''),
    col_g               = nullif(trim(p_injury), ''),
    col_h               = nullif(trim(p_body), ''),
    license             = nullif(trim(p_license), ''),
    road_type           = nullif(trim(p_road_type), ''),
    cause               = nullif(trim(p_cause), ''),
    col_l               = nullif(trim(p_highway_type), ''),
    road_name           = nullif(trim(p_road_name), ''),
    subdistrict         = nullif(trim(p_subdistrict), ''),
    coordinates         = nullif(trim(p_coordinates), ''),
    domicile            = nullif(trim(p_domicile), '')
  where id = p_id;

  if not found then
    return jsonb_build_object('success', false, 'message', 'ไม่พบรายการที่จะแก้ไข');
  end if;
  return jsonb_build_object('success', true, 'message', 'แก้ไขข้อมูลผู้เสียชีวิตเรียบร้อย');
end $fn$;

-- ==========================================================
-- 4  ให้ข้อความรายเดือนใช้คู่กรณีจากตารางนี้ก่อน
-- ==========================================================
-- เดิมดึงคู่กรณีจากตาราง accidents โดยจับคู่ด้วยเวลาเกิดเหตุ
-- ซึ่งพลาดเมื่อเวลาไม่ตรงกันเป๊ะ ตอนนี้มีข้อมูลในตาราง deaths เองแล้ว
-- จึงใช้ของตัวเองก่อน แล้วค่อยถอยไปใช้ของ accidents เมื่อยังไม่ได้กรอก

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
  v_pair text;
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
           nullif(btrim(d.vehicle_type), '') as dv,
           nullif(btrim(d.counterpart_vehicle), '') as cp,
           nullif(btrim(d.status), '') as st,
           a.party1->>'vehicle' as v1,
           a.party2->>'vehicle' as v2
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

    -- คนเดินเท้าไม่มีรถของตัวเอง เขียนว่าถูกรถอะไรชน
    if r.st = 'คนเดินเท้า' then
      v_pair := case when r.cp is not null then 'คนเดินเท้า ถูก ' || r.cp || ' ชน'
                     else 'คนเดินเท้า' end;
    elsif r.dv is not null and r.cp is not null then
      v_pair := r.dv || ' ชนกับ ' || r.cp;
    elsif r.v1 is not null and r.v2 is not null then
      v_pair := r.v1 || ' ชนกับ ' || r.v2;
    else
      v_pair := coalesce(r.dv, r.v1);
    end if;

    if v_pair is not null then
      v_lines := v_lines || array['       ' || v_pair];
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
-- ตรวจผล  คำสั่งสุดท้ายคำสั่งเดียวที่จะแสดงผล
-- ==========================================================

select 'ช่องใหม่ในตาราง' as รายการ,
       case when exists (select 1 from information_schema.columns
                          where table_schema='public' and table_name='deaths'
                            and column_name='counterpart_vehicle')
            then 'มีแล้ว' else 'ไม่มี' end as ผล
union all
select 'จำนวนฟังก์ชัน admin_add_death',
       (select count(*)::text from pg_proc p join pg_namespace n on n.oid=p.pronamespace
         where n.nspname='public' and p.proname='admin_add_death')
       || '   ต้องเป็น 1 เท่านั้น'
union all
select 'จำนวนฟังก์ชัน admin_update_death',
       (select count(*)::text from pg_proc p join pg_namespace n on n.oid=p.pronamespace
         where n.nspname='public' and p.proname='admin_update_death')
       || '   ต้องเป็น 1 เท่านั้น'
union all
select 'ตัวอย่างข้อความรอบเดือน', line_msg_ac_m();
