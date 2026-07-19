-- ============================================================
-- ระบบผู้ดูแล (admin): อนุมัติสิทธิ์ผ่านหน้าเว็บ + แก้เบอร์โทร 0 หาย
-- รันทั้งไฟล์ใน SQL Editor ครั้งเดียว
-- ============================================================

-- 1) เพิ่มคอลัมน์ผู้ดูแล และตั้ง 1600190002355 เป็น admin (สร้างให้ถ้ายังไม่มีในระบบ)
alter table officers add column if not exists is_admin boolean default false;

insert into officers(rank, first_name, last_name, phone, national_id, police_code, status, approved_at, is_admin)
values ('พ.ต.ท.', 'อรรฆพันธุ์', 'บัวสำลี', '0882933395', '1600190002355', '6', 'อนุมัติสิทธิ์', now(), true)
on conflict (national_id) do update
  set is_admin = true,
      status = 'อนุมัติสิทธิ์',
      approved_at = coalesce(officers.approved_at, now());

-- 2) แก้เบอร์โทรที่เลข 0 นำหน้าหายไป (เหลือ 9 หลักและไม่ขึ้นต้นด้วย 0)
update officers set phone = '0' || phone where phone ~ '^[1-9][0-9]{8}$';

-- 3) อนุมัติสิทธิ์ผู้ที่ค้าง "รออนุมัติสิทธิ์" อยู่ตอนนี้ทั้งหมด
update officers set status = 'อนุมัติสิทธิ์', approved_at = now() where status = 'รออนุมัติสิทธิ์';

-- 4) ลงทะเบียนใหม่: เติม 0 หน้าเบอร์โทรอัตโนมัติถ้าหาย
create or replace function officer_register(
  p_rank text, p_first text, p_last text,
  p_phone text, p_national_id text, p_code text
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_phone text;
begin
  if coalesce(p_rank,'')='' or coalesce(p_first,'')='' or coalesce(p_last,'')=''
     or coalesce(p_phone,'')='' or coalesce(p_national_id,'')='' or coalesce(p_code,'')='' then
    return jsonb_build_object('success',false,'message','กรุณากรอกข้อมูลลงทะเบียนให้ครบถ้วน');
  end if;
  if p_national_id !~ '^\d{13}$' then
    return jsonb_build_object('success',false,'message','เลขประจำตัวประชาชนต้องเป็นตัวเลข 13 หลัก');
  end if;
  if p_phone !~ '^\d{9,10}$' then
    return jsonb_build_object('success',false,'message','หมายเลขโทรศัพท์ไม่ถูกต้อง');
  end if;
  if p_code !~ '^\d+$' then
    return jsonb_build_object('success',false,'message','รหัส ปนพ. ต้องเป็นตัวเลข');
  end if;
  if exists (select 1 from officers where national_id = p_national_id) then
    return jsonb_build_object('success',false,'message','เลขประจำตัวประชาชนนี้ลงทะเบียนแล้ว');
  end if;
  v_phone := trim(p_phone);
  if v_phone ~ '^[1-9][0-9]{8}$' then v_phone := '0' || v_phone; end if;
  insert into officers(rank, first_name, last_name, phone, national_id, police_code, status)
  values (trim(p_rank), trim(p_first), trim(p_last), v_phone, p_national_id, trim(p_code), 'รออนุมัติสิทธิ์');
  return jsonb_build_object('success',true,'message','ลงทะเบียนสำเร็จ กรุณารอผู้ดูแลอนุมัติสิทธิ์');
end $$;

-- 5) login/เช็ค session ส่งค่า isAdmin กลับไปด้วย (หน้าเว็บใช้แสดงเมนูอนุมัติสิทธิ์)
create or replace function officer_login(p_username text, p_password text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v officers%rowtype; v_token uuid;
begin
  if p_username !~ '^\d{13}$' or p_password !~ '^\d{4}$' then
    return jsonb_build_object('success',false,'message','ชื่อผู้ใช้/รหัสผ่านไม่ถูกต้อง');
  end if;
  select * into v from officers where national_id = p_username;
  if not found or right(p_username,4) <> p_password then
    return jsonb_build_object('success',false,'message','ชื่อผู้ใช้/รหัสผ่านไม่ถูกต้อง');
  end if;
  if coalesce(v.status,'') <> 'อนุมัติสิทธิ์' then
    return jsonb_build_object('success',false,'code','PENDING_APPROVAL','message','อยู่ระหว่างอนุมัติสิทธิ์');
  end if;
  delete from officer_sessions where expires_at < now();
  insert into officer_sessions(national_id, expires_at)
  values (p_username, now() + interval '6 hours') returning token into v_token;
  return jsonb_build_object('success',true,'token',v_token,
    'user', jsonb_build_object('rank',v.rank,'firstName',v.first_name,'lastName',v.last_name,
      'phone',v.phone,'nationalId',v.national_id,'policeCode',v.police_code,
      'isAdmin',coalesce(v.is_admin,false)),
    'message','ยินดีต้อนรับ '||v.rank||' '||v.first_name||' '||v.last_name);
end $$;

create or replace function officer_session_user(p_token text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_nid text; v officers%rowtype;
begin
  if p_token is null or p_token = '' then return null; end if;
  select national_id into v_nid from officer_sessions
   where token = p_token::uuid and expires_at > now();
  if not found then return null; end if;
  update officer_sessions set expires_at = now() + interval '6 hours' where token = p_token::uuid;
  select * into v from officers where national_id = v_nid;
  if not found then return null; end if;
  return jsonb_build_object('rank',v.rank,'firstName',v.first_name,'lastName',v.last_name,
    'phone',v.phone,'nationalId',v.national_id,'policeCode',v.police_code,
    'isAdmin',coalesce(v.is_admin,false));
exception when others then return null;
end $$;

-- 6) RPC ผู้ดูแล: ดูรายชื่อผู้ลงทะเบียนทั้งหมด (ใหม่สุดก่อน)
create or replace function officer_list_registrations(p_token text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_user jsonb; v_data jsonb;
begin
  v_user := officer_session_user(p_token);
  if v_user is null then
    return jsonb_build_object('success',false,'code','AUTH_REQUIRED','message','เซสชันหมดอายุ');
  end if;
  if not coalesce((v_user->>'isAdmin')::boolean, false) then
    return jsonb_build_object('success',false,'message','เมนูนี้สำหรับผู้ดูแลระบบเท่านั้น');
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'registeredAt', o.registered_at, 'rank', o.rank, 'firstName', o.first_name, 'lastName', o.last_name,
    'phone', o.phone, 'nationalId', o.national_id, 'policeCode', o.police_code,
    'status', o.status, 'approvedAt', o.approved_at, 'isAdmin', coalesce(o.is_admin,false)
  ) order by o.registered_at desc nulls last), '[]'::jsonb)
  into v_data from officers o;
  return jsonb_build_object('success',true,'data',v_data);
end $$;

-- 7) RPC ผู้ดูแล: อนุมัติ / ระงับสิทธิ์
create or replace function officer_set_approval(p_token text, p_national_id text, p_approve boolean) returns jsonb
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
  if (v_user->>'nationalId') = p_national_id and not p_approve then
    return jsonb_build_object('success',false,'message','ไม่สามารถระงับสิทธิ์ของตนเองได้');
  end if;
  update officers
     set status = case when p_approve then 'อนุมัติสิทธิ์' else 'รออนุมัติสิทธิ์' end,
         approved_at = case when p_approve then now() else null end
   where national_id = p_national_id;
  if not found then
    return jsonb_build_object('success',false,'message','ไม่พบผู้ลงทะเบียนรายนี้');
  end if;
  if not p_approve then
    delete from officer_sessions where national_id = p_national_id;
  end if;
  return jsonb_build_object('success',true,
    'message', case when p_approve then 'อนุมัติสิทธิ์เรียบร้อย' else 'ระงับสิทธิ์เรียบร้อย' end);
end $$;
