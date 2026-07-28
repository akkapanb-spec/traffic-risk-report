-- ============================================================
-- ประกาศจุดจราจรที่ควรหลีกเลี่ยง (traffic advisories)
-- รันใน Supabase Dashboard → SQL Editor → New query → Run
--
-- - เจ้าหน้าที่ admin เป็นผู้ประกาศจากแอปเจ้าหน้าที่ (ผ่าน RPC ตรวจ token)
-- - หน้าประชาชนอ่านตรงจากตาราง เห็นเฉพาะประกาศที่ยังไม่หมดเวลาและไม่ถูกปิด
-- - หมดเวลา (ends_at ผ่านไปแล้ว) หายจากหน้าประชาชนเอง ไม่ต้องมีใครมาลบ
-- ============================================================

create table if not exists traffic_advisories (
  id bigint generated always as identity primary key,
  kind text not null default 'other',          -- work / close / event / flood / other
  title text not null,
  place text not null,
  detail text,
  reroute text,                                -- เส้นทางเลี่ยงที่แนะนำ
  latitude double precision,
  longitude double precision,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  images jsonb not null default '[]'::jsonb,   -- URL รูปแนบ (หนังสือแจ้ง/หน้างาน/ผังเบี่ยง) สูงสุด 4
  created_by text,                             -- ชื่อ-รหัส ปนพ. ผู้ประกาศ
  created_at timestamptz not null default now(),
  closed_at timestamptz                        -- admin กดปิดก่อนเวลา
);

alter table traffic_advisories enable row level security;

-- ประชาชน (anon) อ่านได้ทุกแถวรวมประวัติ — หน้าเว็บกรองเองว่าโซนหลักโชว์เฉพาะ active
-- ส่วน "ประวัติ" เป็นข้อมูลสาธารณะชุดเดียวกับตอนที่มันเคยขึ้นหน้าเว็บ ไม่มี PII
drop policy if exists "public read active advisories" on traffic_advisories;
drop policy if exists "public read advisories" on traffic_advisories;
create policy "public read advisories" on traffic_advisories
  for select using (true);

-- ============================================================
-- RPC ฝั่ง admin (ใช้ admin_check_ จาก deaths_admin.sql)
-- ============================================================

-- รายการทั้งหมดสำหรับหน้า admin (รวมหมดเวลา/ปิดแล้ว)
create or replace function advisory_admin_list(p_token text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb; v_rows jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  select coalesce(jsonb_agg(to_jsonb(t) order by t.starts_at desc), '[]'::jsonb)
    into v_rows
    from traffic_advisories t;
  return jsonb_build_object('success',true,'rows',v_rows);
end $$;

-- เพิ่ม/แก้ไขประกาศ (p_id = null คือเพิ่มใหม่)
create or replace function advisory_save(
  p_token text, p_id bigint, p_kind text, p_title text, p_place text,
  p_detail text, p_reroute text, p_lat double precision, p_lng double precision,
  p_starts timestamptz, p_ends timestamptz, p_images jsonb
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb; v_user jsonb; v_id bigint;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  if coalesce(trim(p_title),'') = '' or coalesce(trim(p_place),'') = '' then
    return jsonb_build_object('success',false,'message','กรุณากรอกหัวข้อและสถานที่');
  end if;
  if p_starts is null or p_ends is null or p_ends <= p_starts then
    return jsonb_build_object('success',false,'message','ช่วงวันเวลาไม่ถูกต้อง (สิ้นสุดต้องอยู่หลังเริ่ม)');
  end if;
  v_user := officer_session_user(p_token);
  if p_id is null then
    insert into traffic_advisories(kind, title, place, detail, reroute, latitude, longitude, starts_at, ends_at, images, created_by)
    values (coalesce(nullif(trim(p_kind),''),'other'), trim(p_title), trim(p_place),
      nullif(trim(p_detail),''), nullif(trim(p_reroute),''), p_lat, p_lng, p_starts, p_ends,
      coalesce(p_images,'[]'::jsonb),
      coalesce(v_user->>'rank','') || ' ' || coalesce(v_user->>'firstName','') || ' ' || coalesce(v_user->>'lastName',''))
    returning id into v_id;
    return jsonb_build_object('success',true,'id',v_id,'message','ประกาศขึ้นหน้าเว็บแล้ว');
  else
    update traffic_advisories set
      kind = coalesce(nullif(trim(p_kind),''),'other'), title = trim(p_title), place = trim(p_place),
      detail = nullif(trim(p_detail),''), reroute = nullif(trim(p_reroute),''),
      latitude = p_lat, longitude = p_lng, starts_at = p_starts, ends_at = p_ends,
      images = coalesce(p_images,'[]'::jsonb), closed_at = null
    where id = p_id;
    if not found then return jsonb_build_object('success',false,'message','ไม่พบประกาศนี้'); end if;
    return jsonb_build_object('success',true,'id',p_id,'message','แก้ไขประกาศเรียบร้อย');
  end if;
end $$;

-- ปิดประกาศก่อนเวลา (หายจากหน้าประชาชนทันที แต่ยังอยู่ในประวัติ)
create or replace function advisory_close(p_token text, p_id bigint) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  update traffic_advisories set closed_at = now() where id = p_id and closed_at is null;
  if not found then return jsonb_build_object('success',false,'message','ไม่พบประกาศ หรือถูกปิดไปแล้ว'); end if;
  return jsonb_build_object('success',true,'message','ปิดประกาศแล้ว');
end $$;

-- ลบประกาศถาวร (ใช้กับรายการที่ลงผิดหรือหมดเวลานานแล้ว)
create or replace function advisory_delete(p_token text, p_id bigint) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  delete from traffic_advisories where id = p_id;
  if not found then return jsonb_build_object('success',false,'message','ไม่พบประกาศนี้'); end if;
  return jsonb_build_object('success',true,'message','ลบประกาศแล้ว');
end $$;

-- ============================================================
-- ล้างข้อมูลตัวอย่างจากรอบทดสอบระบบ (ปลอดภัยต่อการรันซ้ำ —
-- ลบเฉพาะแถวที่ระบบใส่ให้ตอนติดตั้งครั้งแรก ไม่แตะประกาศจริงของเจ้าหน้าที่)
-- ============================================================
delete from traffic_advisories where created_by = 'ตัวอย่างระบบ';
