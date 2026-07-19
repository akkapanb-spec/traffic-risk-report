-- ============================================================
-- จัดการจุดเสี่ยงที่ประชาชนแจ้ง (สำหรับผู้ดูแล)
-- อัปเดตสถานะ + บันทึกผลการดำเนินการ ผ่านหน้าเว็บแทนการเข้า Sheet
-- รันหลัง sql/admin.sql
-- ============================================================

-- อัปเดตสถานะจุดเสี่ยง
create or replace function admin_update_risk_status(p_token text, p_id bigint, p_status text) returns jsonb
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
  if p_status not in ('ยังไม่ได้ดำเนินการ','อยู่ระหว่างดำเนินการ','ดำเนินการแก้ไขแล้ว') then
    return jsonb_build_object('success',false,'message','สถานะไม่ถูกต้อง');
  end if;
  update risk_points set status = p_status where id = p_id;
  if not found then
    return jsonb_build_object('success',false,'message','ไม่พบจุดเสี่ยงรายการนี้');
  end if;
  return jsonb_build_object('success',true,'message','อัปเดตสถานะเรียบร้อย');
end $$;

-- บันทึกผลการดำเนินการ (แสดงใน popup ของหน้าประชาชน) + อัปเดตสถานะพร้อมกันได้
create or replace function admin_add_risk_action(
  p_token text, p_risk_id bigint, p_detail text,
  p_image1 text default null, p_image2 text default null, p_status text default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_user jsonb; v_point risk_points%rowtype;
begin
  v_user := officer_session_user(p_token);
  if v_user is null then
    return jsonb_build_object('success',false,'code','AUTH_REQUIRED','message','เซสชันหมดอายุ');
  end if;
  if not coalesce((v_user->>'isAdmin')::boolean, false) then
    return jsonb_build_object('success',false,'message','เมนูนี้สำหรับผู้ดูแลระบบเท่านั้น');
  end if;
  select * into v_point from risk_points where id = p_risk_id;
  if not found then
    return jsonb_build_object('success',false,'message','ไม่พบจุดเสี่ยงรายการนี้');
  end if;
  if coalesce(trim(p_detail),'') = '' then
    return jsonb_build_object('success',false,'message','กรุณากรอกรายละเอียดการดำเนินการ');
  end if;
  insert into risk_actions(action_date, location, road, image1_url, image2_url, detail)
  values (now(), v_point.location, v_point.road, nullif(trim(p_image1),''), nullif(trim(p_image2),''), trim(p_detail));
  if p_status in ('ยังไม่ได้ดำเนินการ','อยู่ระหว่างดำเนินการ','ดำเนินการแก้ไขแล้ว') then
    update risk_points set status = p_status where id = p_risk_id;
  end if;
  return jsonb_build_object('success',true,'message','บันทึกผลการดำเนินการเรียบร้อย');
end $$;
