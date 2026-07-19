-- ============================================================
-- 1) เพิ่ม ส.ต.ท. ธนนธ เฮียงโฮม (ปนพ.6155) เป็นผู้ดูแลระบบอีกคน
-- 2) RPC บันทึก/แก้ไข/ลบ ข้อมูลผู้เสียชีวิต สำหรับหน้า admin
-- รันหลัง sql/admin.sql
-- ============================================================

insert into officers(rank, first_name, last_name, phone, national_id, police_code, status, approved_at, is_admin)
values ('ส.ต.ท.', 'ธนนธ', 'เฮียงโฮม', '0953511090', '1103702460290', '6155', 'อนุมัติสิทธิ์', now(), true)
on conflict (national_id) do update
  set is_admin = true,
      status = 'อนุมัติสิทธิ์',
      approved_at = coalesce(officers.approved_at, now());

-- ตัวช่วยภายใน: ตรวจสิทธิ์ผู้ดูแล
create or replace function admin_check_(p_token text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_user jsonb;
begin
  v_user := officer_session_user(p_token);
  if v_user is null then
    return jsonb_build_object('success',false,'code','AUTH_REQUIRED','message','เซสชันหมดอายุ');
  end if;
  if not coalesce((v_user->>'isAdmin')::boolean, false) then
    return jsonb_build_object('success',false,'message','เมนูนี้สำหรับผู้ดูแลระบบเท่านั้น');
  end if;
  return null; -- ผ่าน
end $$;

-- เพิ่มข้อมูลผู้เสียชีวิต
create or replace function admin_add_death(
  p_token text, p_datetime timestamptz, p_age int, p_gender text, p_status text,
  p_vehicle text, p_safety text, p_injury text, p_body text, p_license text,
  p_road_type text, p_cause text, p_highway_type text, p_road_name text,
  p_subdistrict text, p_coordinates text, p_domicile text
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  if p_datetime is null then
    return jsonb_build_object('success',false,'message','กรุณาระบุวันที่และเวลาเกิดเหตุ');
  end if;
  insert into deaths(incident_datetime, age, gender, status, vehicle_type, safety_equipment,
    col_g, col_h, license, road_type, cause, col_l, road_name, subdistrict, coordinates, domicile)
  values (p_datetime, p_age, nullif(trim(p_gender),''), nullif(trim(p_status),''),
    nullif(trim(p_vehicle),''), nullif(trim(p_safety),''), nullif(trim(p_injury),''), nullif(trim(p_body),''),
    nullif(trim(p_license),''), nullif(trim(p_road_type),''), nullif(trim(p_cause),''),
    nullif(trim(p_highway_type),''), nullif(trim(p_road_name),''), nullif(trim(p_subdistrict),''),
    nullif(trim(p_coordinates),''), nullif(trim(p_domicile),''));
  return jsonb_build_object('success',true,'message','บันทึกข้อมูลผู้เสียชีวิตเรียบร้อย');
end $$;

-- แก้ไขข้อมูลผู้เสียชีวิตที่ลงผิด
create or replace function admin_update_death(
  p_token text, p_id bigint, p_datetime timestamptz, p_age int, p_gender text, p_status text,
  p_vehicle text, p_safety text, p_injury text, p_body text, p_license text,
  p_road_type text, p_cause text, p_highway_type text, p_road_name text,
  p_subdistrict text, p_coordinates text, p_domicile text
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  if p_datetime is null then
    return jsonb_build_object('success',false,'message','กรุณาระบุวันที่และเวลาเกิดเหตุ');
  end if;
  update deaths set
    incident_datetime = p_datetime, age = p_age,
    gender = nullif(trim(p_gender),''), status = nullif(trim(p_status),''),
    vehicle_type = nullif(trim(p_vehicle),''), safety_equipment = nullif(trim(p_safety),''),
    col_g = nullif(trim(p_injury),''), col_h = nullif(trim(p_body),''),
    license = nullif(trim(p_license),''), road_type = nullif(trim(p_road_type),''),
    cause = nullif(trim(p_cause),''), col_l = nullif(trim(p_highway_type),''),
    road_name = nullif(trim(p_road_name),''), subdistrict = nullif(trim(p_subdistrict),''),
    coordinates = nullif(trim(p_coordinates),''), domicile = nullif(trim(p_domicile),'')
  where id = p_id;
  if not found then
    return jsonb_build_object('success',false,'message','ไม่พบข้อมูลรายการนี้');
  end if;
  return jsonb_build_object('success',true,'message','แก้ไขข้อมูลเรียบร้อย');
end $$;

-- ลบข้อมูลผู้เสียชีวิตที่ลงผิด
create or replace function admin_delete_death(p_token text, p_id bigint) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  delete from deaths where id = p_id;
  if not found then
    return jsonb_build_object('success',false,'message','ไม่พบข้อมูลรายการนี้');
  end if;
  return jsonb_build_object('success',true,'message','ลบข้อมูลเรียบร้อย');
end $$;
