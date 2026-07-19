-- ============================================================
-- อัปเกรดตัวเชื่อม 2 ตาราง: ใช้ "เลขที่การแจ้ง" (risk_points.id) แทนการจับคู่ชื่อสถานที่+ถนน
-- + RPC แก้ไข/ลบ สำหรับกรณีลงข้อมูลผิด
-- รันหลัง sql/risk_admin.sql
-- ============================================================

-- 1) เพิ่มคอลัมน์เลขที่การแจ้งในตารางการดำเนินการ (ลบจุดเสี่ยง = ประวัติของจุดนั้นถูกลบตาม)
alter table risk_actions add column if not exists risk_id bigint references risk_points(id) on delete cascade;
create index if not exists idx_risk_actions_risk_id on risk_actions(risk_id);

-- 2) เชื่อมข้อมูลเก่าที่มีอยู่ ด้วยการจับคู่ชื่อสถานที่+ถนนครั้งสุดท้าย (จากนี้ไปใช้เลขที่อย่างเดียว)
update risk_actions a set risk_id = p.id
  from risk_points p
 where a.risk_id is null
   and trim(coalesce(a.location,'')) = trim(coalesce(p.location,''))
   and trim(coalesce(a.road,''))     = trim(coalesce(p.road,''));

-- 3) บันทึกผลการดำเนินการ: ผูกกับเลขที่การแจ้งเสมอ
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
  insert into risk_actions(action_date, risk_id, location, road, image1_url, image2_url, detail)
  values (now(), p_risk_id, v_point.location, v_point.road, nullif(trim(p_image1),''), nullif(trim(p_image2),''), trim(p_detail));
  if p_status in ('ยังไม่ได้ดำเนินการ','อยู่ระหว่างดำเนินการ','ดำเนินการแก้ไขแล้ว') then
    update risk_points set status = p_status where id = p_risk_id;
  end if;
  return jsonb_build_object('success',true,'message','บันทึกผลการดำเนินการเรียบร้อย');
end $$;

-- 4) แก้ไขผลการดำเนินการที่ลงผิด
create or replace function admin_update_risk_action(
  p_token text, p_action_id bigint, p_detail text,
  p_image1 text default null, p_image2 text default null
) returns jsonb
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
  if coalesce(trim(p_detail),'') = '' then
    return jsonb_build_object('success',false,'message','กรุณากรอกรายละเอียดการดำเนินการ');
  end if;
  update risk_actions
     set detail = trim(p_detail),
         image1_url = nullif(trim(coalesce(p_image1,'')),''),
         image2_url = nullif(trim(coalesce(p_image2,'')),'')
   where id = p_action_id;
  if not found then
    return jsonb_build_object('success',false,'message','ไม่พบรายการดำเนินการนี้');
  end if;
  return jsonb_build_object('success',true,'message','แก้ไขเรียบร้อย');
end $$;

-- 5) ลบผลการดำเนินการที่ลงผิด
create or replace function admin_delete_risk_action(p_token text, p_action_id bigint) returns jsonb
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
  delete from risk_actions where id = p_action_id;
  if not found then
    return jsonb_build_object('success',false,'message','ไม่พบรายการดำเนินการนี้');
  end if;
  return jsonb_build_object('success',true,'message','ลบเรียบร้อย');
end $$;

-- 6) ลบจุดเสี่ยงที่แจ้งผิด/ข้อมูลขยะ (ประวัติการดำเนินการของจุดนั้นถูกลบตามอัตโนมัติ)
create or replace function admin_delete_risk_point(p_token text, p_id bigint) returns jsonb
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
  delete from risk_points where id = p_id;
  if not found then
    return jsonb_build_object('success',false,'message','ไม่พบจุดเสี่ยงรายการนี้');
  end if;
  return jsonb_build_object('success',true,'message','ลบจุดเสี่ยงเรียบร้อย');
end $$;
