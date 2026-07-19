-- ============================================================
-- หน้าอนุมัติสิทธิ์: แก้ไข / ลบ ข้อมูลเจ้าหน้าที่ (แทนการแก้ใน Google Sheet ยุคเดิม)
-- รันหลัง sql/deaths_admin.sql (ใช้ admin_check_ ร่วมกัน)
-- ============================================================

-- แก้ไขข้อมูลเจ้าหน้าที่ (เปลี่ยนเลขบัตรได้ = รหัสผ่านเปลี่ยนเป็นเลข 4 ตัวท้ายใหม่)
create or replace function admin_update_officer(
  p_token text, p_national_id text,
  p_rank text, p_first text, p_last text, p_phone text, p_code text,
  p_new_national_id text default null, p_is_admin boolean default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb; v_user jsonb; v_phone text; v_new_id text;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  v_user := officer_session_user(p_token);

  if not exists (select 1 from officers where national_id = p_national_id) then
    return jsonb_build_object('success',false,'message','ไม่พบเจ้าหน้าที่รายนี้');
  end if;
  if coalesce(p_rank,'')='' or coalesce(p_first,'')='' or coalesce(p_last,'')='' then
    return jsonb_build_object('success',false,'message','กรุณากรอกยศ ชื่อ และนามสกุล');
  end if;

  v_phone := trim(coalesce(p_phone,''));
  if v_phone <> '' and v_phone !~ '^\d{9,10}$' then
    return jsonb_build_object('success',false,'message','หมายเลขโทรศัพท์ไม่ถูกต้อง');
  end if;
  if v_phone ~ '^[1-9][0-9]{8}$' then v_phone := '0' || v_phone; end if;

  v_new_id := nullif(trim(coalesce(p_new_national_id,'')),'');
  if v_new_id is not null and v_new_id <> p_national_id then
    if v_new_id !~ '^\d{13}$' then
      return jsonb_build_object('success',false,'message','เลขประจำตัวประชาชนต้องเป็นตัวเลข 13 หลัก');
    end if;
    if exists (select 1 from officers where national_id = v_new_id) then
      return jsonb_build_object('success',false,'message','เลขประจำตัวประชาชนใหม่ซ้ำกับที่มีอยู่ในระบบ');
    end if;
  else
    v_new_id := p_national_id;
  end if;

  -- กันถอดสิทธิ์ผู้ดูแลของตนเอง (จะล็อกตัวเองออกจากเมนู admin)
  if (v_user->>'nationalId') = p_national_id and p_is_admin is not null and p_is_admin = false then
    return jsonb_build_object('success',false,'message','ไม่สามารถถอดสิทธิ์ผู้ดูแลของตนเองได้');
  end if;

  update officers set
    rank = trim(p_rank), first_name = trim(p_first), last_name = trim(p_last),
    phone = nullif(v_phone,''), police_code = nullif(trim(coalesce(p_code,'')),''),
    national_id = v_new_id,
    is_admin = coalesce(p_is_admin, is_admin)
  where national_id = p_national_id;

  -- ถ้าเปลี่ยนเลขบัตร เซสชันเดิมของคนนั้นใช้ไม่ได้แล้ว (ต้อง login ใหม่ด้วยรหัสใหม่)
  if v_new_id <> p_national_id then
    delete from officer_sessions where national_id = p_national_id;
  end if;

  return jsonb_build_object('success',true,'message','บันทึกการแก้ไขเรียบร้อย');
end $$;

-- ลบเจ้าหน้าที่ (ประวัติเคสที่เคยบันทึกไว้ยังอยู่ครบ เพราะบันทึกชื่อ-เลขบัตรไว้ในเคสแล้ว)
create or replace function admin_delete_officer(p_token text, p_national_id text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb; v_user jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  v_user := officer_session_user(p_token);
  if (v_user->>'nationalId') = p_national_id then
    return jsonb_build_object('success',false,'message','ไม่สามารถลบบัญชีของตนเองได้');
  end if;
  delete from officer_sessions where national_id = p_national_id;
  delete from officers where national_id = p_national_id;
  if not found then
    return jsonb_build_object('success',false,'message','ไม่พบเจ้าหน้าที่รายนี้');
  end if;
  return jsonb_build_object('success',true,'message','ลบเจ้าหน้าที่เรียบร้อย');
end $$;
