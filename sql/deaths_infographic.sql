-- เพิ่มภาพอินโฟกราฟิกในการบันทึกข้อมูลผู้เสียชีวิต หนึ่งภาพ ไม่บังคับ
-- ถ้ามีอักขระแปลกปลอมต่อท้ายบรรทัดสุดท้าย ให้ลบออกก่อนกด Run
-- รันไฟล์นี้ก่อน แล้วค่อยลาก site.zip
--
-- ------------------------------------------------------------
-- เก็บที่อยู่ของภาพ ไม่ได้เก็บตัวภาพ
-- ------------------------------------------------------------
-- ภาพขึ้นไปอยู่ในที่เก็บไฟล์ของ Supabase ถังชื่อ risk-images เหมือนภาพอื่นในระบบ
-- ตารางเก็บแค่ที่อยู่สาธารณะเป็นข้อความ ซึ่งเป็นวิธีเดียวกับภาพอุบัติเหตุ
--
-- ------------------------------------------------------------
-- ต้องลบฟังก์ชันเดิมก่อนสร้างใหม่ ห้ามสร้างทับเฉย ๆ
-- ------------------------------------------------------------
-- PostgREST เลือกฟังก์ชันจากชุดพารามิเตอร์ที่ตรงกันเป๊ะ
-- การเพิ่มพารามิเตอร์ทำให้มีสองตัวให้เลือก แล้วการเรียกจะกำกวม
-- ระบบจะตอบว่าหาฟังก์ชันไม่เจอ ทั้งที่มีอยู่สองตัว
--
-- ลบด้วยการไล่หาทุกรุ่นที่มีอยู่จริง แทนการพิมพ์ชุดพารามิเตอร์เอง
-- เพราะพิมพ์เองพลาดง่าย และถ้าพลาดจะเหลือรุ่นเก่าค้างไว้โดยไม่รู้ตัว

-- ==========================================================
-- 1  ช่องใหม่ในตาราง
-- ==========================================================

alter table deaths add column if not exists infographic_url text;

-- ==========================================================
-- 2  ลบฟังก์ชันเดิมทุกรุ่น
-- ==========================================================

do $fn$
declare r record;
begin
  for r in
    select p.oid::regprocedure as sig
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('admin_add_death', 'admin_update_death')
  loop
    execute 'drop function ' || r.sig;
    raise notice 'ลบแล้ว %', r.sig;
  end loop;
end;
$fn$;

-- ==========================================================
-- 3  สร้างใหม่พร้อมช่องภาพ
-- ==========================================================
-- คนเดินเท้าไม่มีรถของตัวเอง ล้างค่าที่นี่อีกชั้นเหมือนเดิม
-- หน้าเว็บซ่อนช่องให้แล้ว แต่หน้าเว็บแก้ได้ด้วยเครื่องมือนักพัฒนา

create or replace function admin_add_death(
  p_token text, p_datetime timestamptz, p_age int, p_gender text, p_status text,
  p_vehicle text, p_cp_vehicle text, p_safety text, p_injury text, p_body text, p_license text,
  p_road_type text, p_cause text, p_highway_type text, p_road_name text,
  p_subdistrict text, p_coordinates text, p_domicile text, p_infographic text
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
    subdistrict, coordinates, domicile, infographic_url)
  values (p_datetime, p_age, nullif(trim(p_gender), ''), nullif(trim(p_status), ''),
    v_veh, nullif(trim(coalesce(p_cp_vehicle, '')), ''),
    nullif(trim(p_safety), ''), nullif(trim(p_injury), ''), nullif(trim(p_body), ''),
    nullif(trim(p_license), ''), nullif(trim(p_road_type), ''), nullif(trim(p_cause), ''),
    nullif(trim(p_highway_type), ''), nullif(trim(p_road_name), ''), nullif(trim(p_subdistrict), ''),
    nullif(trim(p_coordinates), ''), nullif(trim(p_domicile), ''),
    nullif(trim(coalesce(p_infographic, '')), ''));

  return jsonb_build_object('success', true, 'message', 'บันทึกข้อมูลผู้เสียชีวิตเรียบร้อย');
end $fn$;

create or replace function admin_update_death(
  p_token text, p_id bigint, p_datetime timestamptz, p_age int, p_gender text, p_status text,
  p_vehicle text, p_cp_vehicle text, p_safety text, p_injury text, p_body text, p_license text,
  p_road_type text, p_cause text, p_highway_type text, p_road_name text,
  p_subdistrict text, p_coordinates text, p_domicile text, p_infographic text
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
    domicile            = nullif(trim(p_domicile), ''),
    infographic_url     = nullif(trim(coalesce(p_infographic, '')), '')
  where id = p_id;

  if not found then
    return jsonb_build_object('success', false, 'message', 'ไม่พบรายการที่จะแก้ไข');
  end if;
  return jsonb_build_object('success', true, 'message', 'แก้ไขข้อมูลผู้เสียชีวิตเรียบร้อย');
end $fn$;

-- ==========================================================
-- ตรวจผล  คำสั่งสุดท้ายคำสั่งเดียวที่จะแสดงผล
-- ==========================================================

select 'ช่องภาพในตาราง' as รายการ,
       case when exists (select 1 from information_schema.columns
                          where table_schema='public' and table_name='deaths'
                            and column_name='infographic_url')
            then 'มีแล้ว' else 'ไม่มี' end as ผล
union all
select 'จำนวนรุ่นของ admin_add_death',
       (select count(*)::text from pg_proc p join pg_namespace n on n.oid=p.pronamespace
         where n.nspname='public' and p.proname='admin_add_death') || '   ต้องเป็น 1'
union all
select 'จำนวนรุ่นของ admin_update_death',
       (select count(*)::text from pg_proc p join pg_namespace n on n.oid=p.pronamespace
         where n.nspname='public' and p.proname='admin_update_death') || '   ต้องเป็น 1'
union all
select 'ขั้นต่อไป', 'ลาก site.zip ขึ้นเว็บ แล้วลองบันทึกพร้อมแนบภาพหนึ่งภาพ';
