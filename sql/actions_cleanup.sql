-- ============================================================
-- 1) ลบข้อมูลการดำเนินการที่ import ซ้ำ 2 รอบ (เก็บชุดแรกไว้)
-- 2) เก็บ "สถานะ ณ ตอนบันทึก" ในแต่ละรายการ เพื่อแสดงใน timeline ว่าครั้งไหนปิดงาน
-- รันหลัง sql/risk_link.sql
-- ============================================================

-- ลบแถวซ้ำ (เนื้อหาเหมือนกันทุกช่อง เก็บ id ต่ำสุดของแต่ละกลุ่ม)
delete from risk_actions a
 using risk_actions b
 where a.id > b.id
   and coalesce(a.action_date, 'epoch'::timestamptz) = coalesce(b.action_date, 'epoch'::timestamptz)
   and coalesce(a.location,'') = coalesce(b.location,'')
   and coalesce(a.road,'')     = coalesce(b.road,'')
   and coalesce(a.detail,'')   = coalesce(b.detail,'')
   and coalesce(a.image1_url,'') = coalesce(b.image1_url,'')
   and coalesce(a.image2_url,'') = coalesce(b.image2_url,'');

-- เก็บสถานะ ณ ตอนบันทึกของแต่ละรายการ
alter table risk_actions add column if not exists status text;

-- บันทึกผลการดำเนินการ: เก็บสถานะที่เลือกไว้ในรายการนั้นด้วย
create or replace function admin_add_risk_action(
  p_token text, p_risk_id bigint, p_detail text,
  p_image1 text default null, p_image2 text default null, p_status text default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_user jsonb; v_point risk_points%rowtype; v_status text;
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
  v_status := case when p_status in ('ยังไม่ได้ดำเนินการ','อยู่ระหว่างดำเนินการ','ดำเนินการแก้ไขแล้ว') then p_status else null end;
  insert into risk_actions(action_date, risk_id, location, road, image1_url, image2_url, detail, status)
  values (now(), p_risk_id, v_point.location, v_point.road, nullif(trim(p_image1),''), nullif(trim(p_image2),''), trim(p_detail), v_status);
  if v_status is not null then
    update risk_points set status = v_status where id = p_risk_id;
  end if;
  return jsonb_build_object('success',true,'message','บันทึกผลการดำเนินการเรียบร้อย');
end $$;
