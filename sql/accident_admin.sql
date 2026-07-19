-- ============================================================
-- 1) แก้ไข/ลบเคสอุบัติเหตุ (admin) — ตารางผู้บาดเจ็บที่ระบบสร้างไว้ปรับตามอัตโนมัติ
--    * ทะเบียนผู้เสียชีวิตไม่ถูกแตะเด็ดขาด (จัดการแยกในหน้า "บันทึกข้อมูลผู้เสียชีวิต")
-- 2) แก้เนื้อหาการแจ้งจุดเสี่ยงของประชาชน (admin)
-- รันหลัง sql/deaths_admin.sql (ใช้ admin_check_ ร่วมกัน)
-- ============================================================

-- ตัวช่วยภายใน: สร้างรายชื่อบุคคลจาก payload (ตรรกะเดียวกับตอนบันทึกเคส)
create or replace function accident_persons_(p_payload jsonb) returns jsonb
language plpgsql immutable as $$
declare v_persons jsonb := '[]'::jsonb; v_p jsonb; v_pass jsonb; v_vehicle text; i int;
begin
  v_p := coalesce(p_payload->'party1','{}'::jsonb);
  v_vehicle := case when v_p->>'vehicle' = 'อื่นๆ' and coalesce(v_p->>'vehicleOther','') <> ''
                    then v_p->>'vehicleOther' else coalesce(v_p->>'vehicle','') end;
  v_persons := v_persons || jsonb_build_array(jsonb_build_object(
    'party','ฝ่ายที่1','type',coalesce(v_p->>'status','ผู้ขับขี่'),'gender',v_p->>'gender',
    'age',v_p->>'age','injury',v_p->>'injury','safety',v_p->>'safety','vehicle',v_vehicle));
  i := 0;
  for v_pass in select value from jsonb_array_elements(coalesce(v_p->'passengers','[]'::jsonb)) loop
    i := i + 1;
    v_persons := v_persons || jsonb_build_array(jsonb_build_object(
      'party','ฝ่ายที่1','type','ผู้โดยสารที่'||i,'gender',v_pass->>'gender',
      'age',v_pass->>'age','injury',v_pass->>'injury','safety',v_pass->>'safety','vehicle',v_vehicle));
  end loop;
  v_p := coalesce(p_payload->'party2','{}'::jsonb);
  if coalesce(v_p->>'status','ไม่มี') <> 'ไม่มี' then
    v_vehicle := case when v_p->>'vehicle' = 'อื่นๆ' and coalesce(v_p->>'vehicleOther','') <> ''
                      then v_p->>'vehicleOther' else coalesce(v_p->>'vehicle','') end;
    v_persons := v_persons || jsonb_build_array(jsonb_build_object(
      'party','ฝ่ายที่2','type',coalesce(v_p->>'status','ผู้ขับขี่'),'gender',v_p->>'gender',
      'age',v_p->>'age','injury',v_p->>'injury','safety',v_p->>'safety','vehicle',v_vehicle));
    i := 0;
    for v_pass in select value from jsonb_array_elements(coalesce(v_p->'passengers','[]'::jsonb)) loop
      i := i + 1;
      v_persons := v_persons || jsonb_build_array(jsonb_build_object(
        'party','ฝ่ายที่2','type','ผู้โดยสารที่'||i,'gender',v_pass->>'gender',
        'age',v_pass->>'age','injury',v_pass->>'injury','safety',v_pass->>'safety','vehicle',v_vehicle));
    end loop;
  end if;
  return v_persons;
end $$;

-- แก้ไขเคสอุบัติเหตุ
create or replace function admin_update_accident(p_token text, p_id bigint, p_payload jsonb, p_images jsonb)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_err jsonb; v_old accidents%rowtype; v_occurred timestamptz; v_loc jsonb;
  v_persons jsonb; v_pass jsonb; v_injury text;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;

  select * into v_old from accidents where id = p_id;
  if not found then
    return jsonb_build_object('success',false,'message','ไม่พบเคสอุบัติเหตุนี้');
  end if;

  v_occurred := (p_payload->>'occurredAt')::timestamptz;
  if v_occurred is null then
    return jsonb_build_object('success',false,'message','วันที่และเวลาเกิดเหตุไม่ถูกต้อง');
  end if;
  v_loc := coalesce(p_payload->'location','{}'::jsonb);

  update accidents set
    incident_datetime = v_occurred,
    party1 = coalesce(p_payload->'party1','{}'::jsonb),
    party2 = coalesce(p_payload->'party2','{}'::jsonb),
    place = v_loc->>'place', road_character = v_loc->>'roadCharacter',
    road_character_other = v_loc->>'roadCharacterOther', road = v_loc->>'road',
    local_authority = v_loc->>'localAuthority', subdistrict = v_loc->>'subdistrict',
    district = coalesce(v_loc->>'district','เมืองนครสวรรค์'),
    province = coalesce(v_loc->>'province','นครสวรรค์'),
    cause = v_loc->>'cause',
    latitude = nullif(v_loc->>'latitude','')::double precision,
    longitude = nullif(v_loc->>'longitude','')::double precision,
    details = v_loc->>'details',
    images = coalesce(p_images,'[]'::jsonb)
  where id = p_id;

  -- ปรับตารางผู้บาดเจ็บให้ตรงข้อมูลใหม่:
  -- ลบของเดิมที่ผูกกับเคสนี้ (ตามรหัสเคส หรือรายการเก่าไม่มีรหัสแต่เวลาเกิดเหตุตรงกัน)
  delete from injuries
   where raw->>'acc_code' = v_old.accident_code
      or (coalesce(raw->>'acc_code','') = '' and incident_datetime = v_old.incident_datetime);

  v_persons := accident_persons_(p_payload);
  for v_pass in select value from jsonb_array_elements(v_persons) loop
    v_injury := coalesce(v_pass->>'injury','');
    if v_injury in ('หมดสติ','สาหัส','เล็กน้อย') then
      insert into injuries(incident_datetime, raw)
      values (v_occurred, jsonb_build_object(
        'severity', v_injury, 'gender', v_pass->>'gender', 'age', v_pass->>'age',
        'vehicle', v_pass->>'vehicle', 'safety', v_pass->>'safety',
        'person_type', v_pass->>'type', 'place', v_loc->>'place', 'road', v_loc->>'road',
        'subdistrict', v_loc->>'subdistrict', 'lat', v_loc->>'latitude', 'lng', v_loc->>'longitude',
        'acc_code', v_old.accident_code,
        'image_url', coalesce(p_images->>0,'')));
    end if;
    -- อาการ "เสียชีวิต": ไม่แตะทะเบียนผู้เสียชีวิต — จัดการในหน้าบันทึกข้อมูลผู้เสียชีวิตเท่านั้น
  end loop;

  return jsonb_build_object('success',true,'message','แก้ไขเคสเรียบร้อย','accidentId', v_old.accident_code);
end $$;

-- ลบเคสอุบัติเหตุ (ทะเบียนผู้เสียชีวิตไม่ถูกแตะ)
create or replace function admin_delete_accident(p_token text, p_id bigint) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb; v_old accidents%rowtype;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  select * into v_old from accidents where id = p_id;
  if not found then
    return jsonb_build_object('success',false,'message','ไม่พบเคสอุบัติเหตุนี้');
  end if;
  delete from injuries
   where raw->>'acc_code' = v_old.accident_code
      or (coalesce(raw->>'acc_code','') = '' and incident_datetime = v_old.incident_datetime);
  delete from accidents where id = p_id;
  return jsonb_build_object('success',true,'message','ลบเคสเรียบร้อย');
end $$;

-- แก้เนื้อหาการแจ้งจุดเสี่ยงของประชาชน (อัปเดตชื่อสถานที่ในประวัติการดำเนินการให้ตรงกันด้วย)
create or replace function admin_update_risk_report(
  p_token text, p_id bigint,
  p_location text, p_road text, p_village text, p_subdistrict text,
  p_coordinates text, p_details text, p_image1 text default null, p_image2 text default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  if coalesce(trim(p_location),'') = '' then
    return jsonb_build_object('success',false,'message','กรุณากรอกสถานที่');
  end if;
  update risk_points set
    location = trim(p_location), road = nullif(trim(coalesce(p_road,'')),''),
    village = nullif(trim(coalesce(p_village,'')),''), subdistrict = nullif(trim(coalesce(p_subdistrict,'')),''),
    coordinates = nullif(trim(coalesce(p_coordinates,'')),''), additional_details = nullif(trim(coalesce(p_details,'')),''),
    image1_url = nullif(trim(coalesce(p_image1,'')),''), image2_url = nullif(trim(coalesce(p_image2,'')),'')
  where id = p_id;
  if not found then
    return jsonb_build_object('success',false,'message','ไม่พบจุดเสี่ยงรายการนี้');
  end if;
  -- ให้ชื่อสถานที่/ถนนในประวัติการดำเนินการตรงกับที่แก้ใหม่
  update risk_actions set location = trim(p_location), road = nullif(trim(coalesce(p_road,'')),'')
   where risk_id = p_id;
  return jsonb_build_object('success',true,'message','แก้ไขข้อมูลการแจ้งเรียบร้อย');
end $$;
