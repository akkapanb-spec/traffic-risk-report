-- ============================================================
-- ระบบบันทึกข้อมูลอุบัติเหตุสำหรับเจ้าหน้าที่ (พอร์ตจาก GAS)
-- รันใน Supabase SQL Editor หลังจาก schema.sql
-- หลักการ: ตารางทั้งหมดปิดด้วย RLS การเข้าถึงทำผ่าน RPC
--          (SECURITY DEFINER) ที่ตรวจ session token ก่อนเสมอ
-- ============================================================

-- 1) ตารางเจ้าหน้าที่ (ชีทเดิม: ลงทะเบียน)
create table if not exists officers (
  id bigint generated always as identity primary key,
  registered_at timestamptz default now(),
  rank text not null,
  first_name text not null,
  last_name text not null,
  phone text,
  national_id text not null unique,
  police_code text,
  status text default 'รออนุมัติสิทธิ์',
  approved_at timestamptz
);

-- 2) session ของเจ้าหน้าที่ (เดิมใช้ CacheService 6 ชม.)
create table if not exists officer_sessions (
  token uuid primary key default gen_random_uuid(),
  national_id text not null,
  created_at timestamptz default now(),
  expires_at timestamptz not null
);

alter table officers enable row level security;
alter table officer_sessions enable row level security;
-- ไม่สร้าง policy = ปิดการเข้าถึงตรงจาก anon ทั้งหมด

-- 3) เพิ่มคอลัมน์โครงสร้างเต็มให้ตาราง accidents
alter table accidents
  add column if not exists recorded_at timestamptz,
  add column if not exists accident_code text,
  add column if not exists officer_rank text,
  add column if not exists officer_name text,
  add column if not exists officer_national_id text,
  add column if not exists officer_code text,
  add column if not exists party1 jsonb,
  add column if not exists party2 jsonb,
  add column if not exists place text,
  add column if not exists road_character text,
  add column if not exists road_character_other text,
  add column if not exists road text,
  add column if not exists local_authority text,
  add column if not exists subdistrict text,
  add column if not exists district text,
  add column if not exists province text,
  add column if not exists cause text,
  add column if not exists latitude double precision,
  add column if not exists longitude double precision,
  add column if not exists details text,
  add column if not exists images jsonb,
  add column if not exists verify_status text;

-- 4) ปิดการอ่านสาธารณะของ accidents (มี PII)
--    เว็บประชาชนนับจำนวนผ่าน view ที่เปิดเฉพาะวันที่เกิดเหตุ
drop policy if exists "public read" on accidents;
create or replace view accidents_public as
  select id, incident_datetime from accidents;
grant select on accidents_public to anon, authenticated;

-- ============================================================
-- RPC: ลงทะเบียน
-- ============================================================
create or replace function officer_register(
  p_rank text, p_first text, p_last text,
  p_phone text, p_national_id text, p_code text
) returns jsonb
language plpgsql security definer set search_path = public as $$
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
  insert into officers(rank, first_name, last_name, phone, national_id, police_code, status)
  values (trim(p_rank), trim(p_first), trim(p_last), trim(p_phone), p_national_id, trim(p_code), 'รออนุมัติสิทธิ์');
  return jsonb_build_object('success',true,'message','ลงทะเบียนสำเร็จ กรุณารอผู้ดูแลอนุมัติสิทธิ์');
end $$;

-- ============================================================
-- RPC: เข้าสู่ระบบ (username = เลข 13 หลัก, password = เลข 4 ตัวท้าย)
-- ============================================================
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
      'phone',v.phone,'nationalId',v.national_id,'policeCode',v.police_code),
    'message','ยินดีต้อนรับ '||v.rank||' '||v.first_name||' '||v.last_name);
end $$;

-- ============================================================
-- ตัวช่วยภายใน: ตรวจ session + ต่ออายุ
-- ============================================================
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
    'phone',v.phone,'nationalId',v.national_id,'policeCode',v.police_code);
exception when others then return null;
end $$;

create or replace function officer_check_session(p_token text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_user jsonb;
begin
  v_user := officer_session_user(p_token);
  if v_user is null then
    return jsonb_build_object('success',false,'code','AUTH_REQUIRED','message','เซสชันหมดอายุ');
  end if;
  return jsonb_build_object('success',true,'user',v_user);
end $$;

create or replace function officer_logout(p_token text) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  begin
    delete from officer_sessions where token = p_token::uuid;
  exception when others then null;
  end;
  return jsonb_build_object('success',true,'message','ออกจากระบบแล้ว');
end $$;

-- ============================================================
-- RPC: ดึงข้อมูลอุบัติเหตุทั้งหมด (เฉพาะเจ้าหน้าที่ที่ login)
-- ============================================================
create or replace function officer_get_accidents(p_token text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_user jsonb; v_data jsonb;
begin
  v_user := officer_session_user(p_token);
  if v_user is null then
    return jsonb_build_object('success',false,'code','AUTH_REQUIRED','message','เซสชันหมดอายุ');
  end if;
  select coalesce(jsonb_agg(to_jsonb(a) order by a.incident_datetime), '[]'::jsonb)
    into v_data from accidents a;
  return jsonb_build_object('success',true,'data',v_data);
end $$;

-- ============================================================
-- RPC: บันทึกอุบัติเหตุ + แยกผู้เสียชีวิต/บาดเจ็บอัตโนมัติ
-- ============================================================
create or replace function officer_save_accident(p_token text, p_payload jsonb, p_images jsonb)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_user jsonb;
  v_code text;
  v_occurred timestamptz;
  v_loc jsonb;
  v_persons jsonb := '[]'::jsonb;
  v_p jsonb;
  v_pass jsonb;
  v_vehicle text;
  v_injury text;
  i int;
begin
  v_user := officer_session_user(p_token);
  if v_user is null then
    return jsonb_build_object('success',false,'code','AUTH_REQUIRED','message','เซสชันหมดอายุ กรุณาเข้าสู่ระบบอีกครั้ง');
  end if;

  v_occurred := (p_payload->>'occurredAt')::timestamptz;
  if v_occurred is null then
    return jsonb_build_object('success',false,'message','วันที่และเวลาเกิดเหตุไม่ถูกต้อง');
  end if;
  v_loc := coalesce(p_payload->'location','{}'::jsonb);
  v_code := 'ACC-'||to_char(now() at time zone 'Asia/Bangkok','YYYYMMDD-HH24MISS')
            ||'-'||lpad(floor(random()*9000+1000)::text, 4, '0');

  insert into accidents(
    incident_datetime, recorded_at, accident_code,
    officer_rank, officer_name, officer_national_id, officer_code,
    party1, party2,
    place, road_character, road_character_other, road, local_authority,
    subdistrict, district, province, cause, latitude, longitude, details,
    images, verify_status
  ) values (
    v_occurred, now(), v_code,
    v_user->>'rank', (v_user->>'firstName')||' '||(v_user->>'lastName'),
    v_user->>'nationalId', v_user->>'policeCode',
    coalesce(p_payload->'party1','{}'::jsonb), coalesce(p_payload->'party2','{}'::jsonb),
    v_loc->>'place', v_loc->>'roadCharacter', v_loc->>'roadCharacterOther',
    v_loc->>'road', v_loc->>'localAuthority', v_loc->>'subdistrict',
    coalesce(v_loc->>'district','เมืองนครสวรรค์'), coalesce(v_loc->>'province','นครสวรรค์'),
    v_loc->>'cause', nullif(v_loc->>'latitude','')::double precision,
    nullif(v_loc->>'longitude','')::double precision, v_loc->>'details',
    coalesce(p_images,'[]'::jsonb), 'รอตรวจสอบ'
  );

  -- รวมรายชื่อบุคคลทั้งหมด (ฝ่าย 1 + ผู้โดยสาร, ฝ่าย 2 + ผู้โดยสาร)
  v_p := coalesce(p_payload->'party1','{}'::jsonb);
  v_vehicle := case when v_p->>'vehicle' = 'อื่นๆ' and coalesce(v_p->>'vehicleOther','') <> ''
                    then v_p->>'vehicleOther' else coalesce(v_p->>'vehicle','') end;
  v_persons := v_persons || jsonb_build_array(jsonb_build_object(
    'party','ฝ่ายที่1','type',coalesce(v_p->>'status','ผู้ขับขี่'),'gender',v_p->>'gender',
    'age',v_p->>'age','injury',v_p->>'injury','safety',v_p->>'safety','vehicle',v_vehicle));
  i := 0;
  for v_pass in select value from jsonb_array_elements(coalesce(v_p->'passengers','[]'::jsonb))
  loop
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
    for v_pass in select value from jsonb_array_elements(coalesce(v_p->'passengers','[]'::jsonb))
    loop
      i := i + 1;
      v_persons := v_persons || jsonb_build_array(jsonb_build_object(
        'party','ฝ่ายที่2','type','ผู้โดยสารที่'||i,'gender',v_pass->>'gender',
        'age',v_pass->>'age','injury',v_pass->>'injury','safety',v_pass->>'safety','vehicle',v_vehicle));
    end loop;
  end if;

  -- แยกลงตาราง deaths / injuries
  for v_pass in select value from jsonb_array_elements(v_persons)
  loop
    v_injury := coalesce(v_pass->>'injury','');
    if v_injury = 'เสียชีวิต' then
      insert into deaths(incident_datetime, age, gender, status, vehicle_type,
        safety_equipment, road_name, subdistrict, coordinates, cause)
      values (v_occurred, nullif(v_pass->>'age','')::int, v_pass->>'gender', v_pass->>'type',
        v_pass->>'vehicle', v_pass->>'safety', v_loc->>'road', v_loc->>'subdistrict',
        coalesce(v_loc->>'latitude','')||', '||coalesce(v_loc->>'longitude',''), v_loc->>'cause');
    elsif v_injury in ('หมดสติ','สาหัส','เล็กน้อย') then
      insert into injuries(incident_datetime, raw)
      values (v_occurred, jsonb_build_object(
        'severity', v_injury, 'gender', v_pass->>'gender', 'age', v_pass->>'age',
        'vehicle', v_pass->>'vehicle', 'safety', v_pass->>'safety',
        'person_type', v_pass->>'type', 'place', v_loc->>'place', 'road', v_loc->>'road',
        'subdistrict', v_loc->>'subdistrict', 'lat', v_loc->>'latitude', 'lng', v_loc->>'longitude',
        'acc_code', v_code,
        'image_url', coalesce(p_images->>0,'')));
    end if;
  end loop;

  return jsonb_build_object('success',true,'message','บันทึกข้อมูลอุบัติเหตุสำเร็จ',
    'accidentId', v_code, 'imageUrls', coalesce(p_images,'[]'::jsonb));
end $$;

-- ============================================================
-- อนุมัติสิทธิ์เจ้าหน้าที่ (รันเองใน SQL Editor):
-- select officer_approve('เลขบัตร13หลัก');
-- ============================================================
create or replace function officer_approve(p_national_id text) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  update officers set status = 'อนุมัติสิทธิ์', approved_at = now()
   where national_id = p_national_id;
  if not found then return jsonb_build_object('success',false,'message','ไม่พบผู้ใช้'); end if;
  return jsonb_build_object('success',true,'message','อนุมัติสิทธิ์สำเร็จ');
end $$;
-- ป้องกันคนทั่วไปเรียกอนุมัติเอง
revoke execute on function officer_approve(text) from public, anon, authenticated;
