-- ทำให้ช่องภาพอินโฟกราฟิกเป็นช่องที่ไม่ส่งมาก็ได้  ฉบับตรงไปตรงมา
-- ถ้ามีอักขระแปลกปลอมต่อท้ายบรรทัดสุดท้าย ให้ลบออกก่อนกด Run
-- ใช้แทน deaths_infographic_default.sql ซึ่งไม่ทำงาน
--
-- ------------------------------------------------------------
-- ทำไมต้องมีฉบับที่สอง
-- ------------------------------------------------------------
-- ฉบับแรกอ่านนิยามที่ติดตั้งอยู่มาเติมค่าเริ่มต้นด้วยคำสั่งไดนามิก
-- ตรวจแล้วพบว่าค่าเริ่มต้นไม่ได้เข้าไป ทั้งที่จุดยึดมีอยู่จริงหนึ่งแห่งพอดี
-- แปลว่ามีบางอย่างทำให้ทั้งไฟล์ถูกยกเลิก และตัวแก้ไขรันทั้งไฟล์เป็นรายการเดียว
-- พอมีคำสั่งใดคำสั่งหนึ่งพลาด ทุกอย่างในไฟล์จึงย้อนกลับหมด
--
-- ฉบับนี้ไม่มีลูป ไม่มีคำสั่งไดนามิก ไม่มีบล็อกที่ต้องตีความ
-- มีแค่สองคำสั่งที่อ่านแล้วรู้ทันทีว่าทำอะไร ถ้าพลาดจะชี้ได้ว่าพลาดบรรทัดไหน
--
-- เนื้อในทั้งสองฟังก์ชันคัดลอกมาจากที่ติดตั้งอยู่จริงในฐานข้อมูล
-- ตรวจเทียบแล้วตรงกันทุกตัวอักษร จึงไม่มีอะไรเปลี่ยนนอกจากค่าเริ่มต้น
--
-- ------------------------------------------------------------
-- ค่าเริ่มต้นแก้ปัญหาอะไร
-- ------------------------------------------------------------
-- เมื่อพารามิเตอร์มีค่าเริ่มต้น ผู้เรียกจะไม่ส่งมาก็ได้
--   หน้าเว็บที่ให้บริการอยู่ ส่ง 18 ช่อง  เรียกได้ ภาพเป็นค่าว่าง
--   หน้าเว็บรุ่นใหม่ที่ยังขึ้นไม่ได้ ส่ง 19 ช่อง  เรียกได้เช่นกัน
-- ยังเป็นฟังก์ชันตัวเดียว ไม่ใช่สองตัว จึงไม่กำกวม

-- ==========================================================
-- 1  บันทึกผู้เสียชีวิตรายใหม่
-- ==========================================================

create or replace function admin_add_death(
  p_token text, p_datetime timestamptz, p_age int, p_gender text, p_status text,
  p_vehicle text, p_cp_vehicle text, p_safety text, p_injury text, p_body text, p_license text,
  p_road_type text, p_cause text, p_highway_type text, p_road_name text,
  p_subdistrict text, p_coordinates text, p_domicile text,
  p_infographic text default null
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

-- ==========================================================
-- 2  แก้ไขรายการเดิม
-- ==========================================================
-- หมายเหตุที่ต้องรู้
-- หน้าเว็บรุ่นเก่าไม่ส่งช่องภาพมา ค่าเริ่มต้นจึงเป็น null
-- และบรรทัดล่างจะเขียนทับ infographic_url ให้เป็นค่าว่าง
-- แปลว่าถ้าแก้ไขรายการที่เคยมีภาพ ด้วยหน้าเว็บรุ่นเก่า ภาพจะหลุด
--
-- ยอมรับผลนี้ได้ เพราะตอนนี้ยังไม่มีรายการไหนมีภาพเลยสักรายการ
-- และเมื่อหน้าเว็บรุ่นใหม่ขึ้นได้ ปัญหานี้จะหายไปเอง
-- เขียนไว้ตรงนี้เพื่อไม่ให้ใครไปเจอเองแล้วงงทีหลัง

create or replace function admin_update_death(
  p_token text, p_id bigint, p_datetime timestamptz, p_age int, p_gender text, p_status text,
  p_vehicle text, p_cp_vehicle text, p_safety text, p_injury text, p_body text, p_license text,
  p_road_type text, p_cause text, p_highway_type text, p_road_name text,
  p_subdistrict text, p_coordinates text, p_domicile text,
  p_infographic text default null
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
-- ตัวเลขที่ต้องดูคือช่องที่มีค่าเริ่มต้น ต้องเป็น 1 ทั้งสองบรรทัด
-- ถ้ายังเป็น 0 แปลว่าไฟล์นี้ไม่ได้ทำงาน ให้ดูข้อความแดงในตัวแก้ไข

select p.proname as ฟังก์ชัน,
       p.pronargs as "จำนวนช่องทั้งหมด",
       p.pronargdefaults as "ช่องที่มีค่าเริ่มต้น  ต้องเป็น 1",
       case when p.pronargdefaults = 1 then 'ใช้ได้แล้ว' else 'ยังไม่ได้ ให้บอกผม' end as สรุป
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('admin_add_death', 'admin_update_death')
order by p.proname;
