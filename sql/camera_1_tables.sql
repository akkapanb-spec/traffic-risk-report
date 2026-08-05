-- ============================================================
-- กล้องวงจรปิดของหน่วย
-- ============================================================
-- ต้องมี admin_check_ จาก deaths_admin.sql และ officer_session_user จาก officer.sql
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
--
-- ตารางนี้เก็บแค่ "ที่อยู่ของสตรีม" ไม่ได้เก็บภาพและไม่ได้เก็บรหัสกล้อง
-- รหัสผ่านกล้องอยู่ในไฟล์ mediamtx.yml บนเครื่องเกตเวย์เท่านั้น
-- เพราะหน้าเว็บเป็นไฟล์เปิด ใครกด View Source ก็อ่านได้
--
-- ปิดการอ่านสาธารณะทั้งหมด เข้าถึงได้ผ่าน RPC ที่ตรวจ session แล้วเท่านั้น
-- ภาพกล้องเห็นหน้าคนและทะเบียนรถ ไม่ใช่ข้อมูลที่เปิดให้ใครก็ได้
-- ============================================================

set search_path = public, extensions;

create table if not exists cam_sources (
  id           bigserial primary key,
  name         text not null,                  -- ชื่อที่เจ้าหน้าที่เรียก เช่น แยกสวรรค์วิถี
  place        text,                           -- คำอธิบายตำแหน่งเพิ่มเติม
  subdistrict  text,
  latitude     double precision,
  longitude    double precision,
  gateway_url  text not null,                  -- https://โดเมนเกตเวย์:8888  ไม่ต้องมี / ปิดท้าย
  path_wide    text not null,                  -- ชื่อ path ใน mediamtx.yml เช่น cam1_wide
  path_zoom    text,                           -- เลนส์ที่สอง ถ้าเป็นกล้องเลนส์เดียวเว้นว่าง
  active       boolean not null default true,
  sort_order   int not null default 0,
  note         text,
  updated_at   timestamptz not null default now()
);

create index if not exists cam_sources_order_idx on cam_sources (sort_order, id);

alter table cam_sources enable row level security;
-- ตั้งใจไม่สร้าง policy ใด ๆ  anon อ่านตรงไม่ได้ทุกทาง

-- ============================================================
-- อ่านรายการกล้อง - เจ้าหน้าที่ที่ล็อกอินแล้วทุกคน
-- ============================================================
create or replace function cam_list(p_token text)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare v_user jsonb;
begin
  v_user := officer_session_user(p_token);
  if v_user is null then
    return jsonb_build_object('success', false, 'code', 'AUTH_REQUIRED', 'message', 'กรุณาเข้าสู่ระบบใหม่');
  end if;

  return jsonb_build_object('success', true,
    'isAdmin', coalesce((v_user->>'isAdmin')::boolean, false),
    'cameras', coalesce((select jsonb_agg(to_jsonb(x) order by x.sort_order, x.id)
      from (select id, name, place, subdistrict, latitude, longitude,
                   gateway_url, path_wide, path_zoom, active, sort_order, note
            from cam_sources
            where active or coalesce((v_user->>'isAdmin')::boolean, false)) x), '[]'::jsonb));
end $$;

-- ============================================================
-- เพิ่ม/แก้กล้อง - ผู้ดูแลเท่านั้น
-- ============================================================
create or replace function cam_save(p_token text, p_id bigint, p_row jsonb)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare v_err jsonb; v_id bigint; v_gw text;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;

  if nullif(btrim(coalesce(p_row->>'name','')), '') is null then
    return jsonb_build_object('success', false, 'message', 'ยังไม่ได้ใส่ชื่อกล้อง');
  end if;
  if nullif(btrim(coalesce(p_row->>'path_wide','')), '') is null then
    return jsonb_build_object('success', false, 'message', 'ยังไม่ได้ใส่ชื่อสตรีม');
  end if;

  -- ตัด / ปิดท้ายทิ้ง ไม่งั้นต่อ URL แล้วได้ // ซึ่งเกตเวย์บางตัวไม่รับ
  v_gw := regexp_replace(btrim(coalesce(p_row->>'gateway_url','')), '/+$', '');
  if v_gw !~ '^https://' then
    -- หน้าเว็บอยู่บน https สตรีม http จะถูกเบราว์เซอร์บล็อกทิ้งเงียบ ๆ
    -- กันไว้ตั้งแต่ตอนบันทึก ดีกว่าให้ไปงงตอนเปิดแล้วเจอจอดำ
    return jsonb_build_object('success', false,
      'message', 'ที่อยู่เกตเวย์ต้องขึ้นต้นด้วย https:// ไม่งั้นเบราว์เซอร์จะบล็อกภาพทิ้ง');
  end if;

  if p_id is null then
    insert into cam_sources (name, place, subdistrict, latitude, longitude,
                             gateway_url, path_wide, path_zoom, active, sort_order, note)
    values (p_row->>'name', p_row->>'place', p_row->>'subdistrict',
            nullif(p_row->>'latitude','')::double precision,
            nullif(p_row->>'longitude','')::double precision,
            v_gw, p_row->>'path_wide', nullif(p_row->>'path_zoom',''),
            coalesce((p_row->>'active')::boolean, true),
            coalesce((p_row->>'sort_order')::int, 0), p_row->>'note')
    returning id into v_id;
  else
    update cam_sources set
      name = p_row->>'name', place = p_row->>'place', subdistrict = p_row->>'subdistrict',
      latitude = nullif(p_row->>'latitude','')::double precision,
      longitude = nullif(p_row->>'longitude','')::double precision,
      gateway_url = v_gw, path_wide = p_row->>'path_wide',
      path_zoom = nullif(p_row->>'path_zoom',''),
      active = coalesce((p_row->>'active')::boolean, true),
      sort_order = coalesce((p_row->>'sort_order')::int, 0),
      note = p_row->>'note', updated_at = now()
    where id = p_id
    returning id into v_id;
    if v_id is null then
      return jsonb_build_object('success', false, 'message', 'ไม่พบกล้องนี้');
    end if;
  end if;

  return jsonb_build_object('success', true, 'message', 'บันทึกแล้ว', 'id', v_id);
end $$;

create or replace function cam_delete(p_token text, p_id bigint)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare v_err jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;

  -- ต้องมี where เสมอ Supabase เปิด sql_safe_updates ไว้ delete ทั้งตารางจะถูกบล็อก
  delete from cam_sources where id = p_id;
  return jsonb_build_object('success', true, 'message', 'ลบแล้ว');
end $$;

grant execute on function cam_list(text)               to anon, authenticated;
grant execute on function cam_save(text, bigint, jsonb) to anon, authenticated;
grant execute on function cam_delete(text, bigint)      to anon, authenticated;

-- ============================================================
-- ตรวจผลหลังรัน
-- ============================================================
-- select cam_list('ใส่ token ของเจ้าหน้าที่');   -- ต้องได้ success true และ cameras เป็น []
