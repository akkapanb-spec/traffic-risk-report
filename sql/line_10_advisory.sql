-- ============================================================
-- LINE Bot — แจ้งเหตุ "ควรเลี่ยงเส้นทาง" เข้าไลน์
-- ============================================================
-- ไฟล์ที่ 10  ต้องรัน line_1 ถึง line_5 และ avoid_admin.sql มาก่อน
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
--
-- ทำอะไร
--   1) เพิ่มช่อง "ผลกระทบการจราจร" ในตารางประกาศจุดหลีกเลี่ยง
--   2) เพิ่มชนิดเหตุการณ์ accident (อุบัติเหตุ) — เป็นแค่ค่าใน text ไม่ต้องแก้ schema
--   3) สร้างข้อความไลน์จากประกาศหนึ่งใบ
--   4) ให้แอดมินกดส่งเข้าไลน์ได้จากหน้าประกาศ
--
-- ทำไมใช้ฟอร์มประกาศจุดหลีกเลี่ยงเดิม ไม่สร้างฟอร์มใหม่
--   ตกลงกันไว้ว่าเอาแบบง่ายที่สุด เพราะเมนูแอดมินเริ่มเยอะแล้ว
--   ประกาศอุบัติเหตุกับประกาศปิดถนนใช้ข้อมูลชุดเดียวกันหมด
--   คือ ที่ไหน เมื่อไหร่ เลี่ยงทางไหน ต่างกันแค่สาเหตุ
--
-- ทำไมแยกปุ่มส่งไลน์ออกจากปุ่มบันทึก
--   ประกาศบางใบเป็นงานล่วงหน้า เช่น ซ่อมถนนอีกสองสัปดาห์ ยังไม่ต้องแจ้งใคร
--   และถ้าไลน์ล่ม การบันทึกประกาศต้องไม่ล้มตามไปด้วย
--   แยกกันแล้วกดส่งซ้ำทีหลังได้ด้วยถ้ารอบแรกไม่ผ่าน
-- ============================================================

set search_path = public, extensions;

-- ============================================================
-- 1) ช่องผลกระทบการจราจร
-- ============================================================
-- เก็บเป็น text ไม่ใช่ enum เพราะรายการตัวเลือกจะปรับตามหน้างานได้เรื่อย ๆ
-- โดยไม่ต้องมาแก้ schema ทุกครั้ง หน้าเว็บเป็นคนคุมว่ามีตัวเลือกอะไรบ้าง
alter table traffic_advisories add column if not exists impact text;

-- ============================================================
-- 2) ข้อความไลน์ของประกาศหนึ่งใบ
-- ============================================================
-- คืน null ถ้าไม่พบประกาศ ผู้เรียกต้องเช็คก่อนส่ง
create or replace function line_msg_advisory(p_id bigint)
returns text
language plpgsql stable security definer set search_path = public, extensions as $line_msg_advisory$
declare
  r record;
  v_kind text;
  v_lines text[];
begin
  select * into r from traffic_advisories where id = p_id;
  if not found then return null; end if;

  v_kind := case r.kind
    when 'accident' then 'อุบัติเหตุ'
    when 'work'     then 'ก่อสร้าง/ซ่อมทาง'
    when 'close'    then 'ปิดถนน'
    when 'event'    then 'ขบวน/กิจกรรม'
    when 'flood'    then 'น้ำท่วม'
    else 'อื่นๆ' end;

  v_lines := array[
    '⚠️ แจ้งเหตุ ควรเลี่ยงเส้นทาง',
    '',
    '[' || v_kind || '] ' || r.title,
    '📍 ' || r.place
  ];

  if coalesce(btrim(r.impact), '') <> '' then
    v_lines := v_lines || ('🚦 ผลกระทบ: ' || r.impact);
  end if;

  -- ช่วงเวลาเขียนแบบอ่านออกทันที ไม่ต้องเปิดปฏิทินคิดต่อ
  v_lines := v_lines || ('🕐 ' || line_thai_date(r.starts_at, true) || ' ถึง ' || line_thai_date(r.ends_at, true));

  if coalesce(btrim(r.reroute), '') <> '' then
    v_lines := v_lines || ('↩️ เลี่ยงทาง: ' || r.reroute);
  end if;

  if coalesce(btrim(r.detail), '') <> '' then
    v_lines := v_lines || '' || r.detail;
  end if;

  -- ลิงก์แผนที่ชี้ไป Google Maps ไม่ใช่เว็บของเรา
  -- เพราะที่อยู่เว็บเราเปลี่ยนได้ (ย้ายโฮสต์) แต่ข้อความที่ส่งไปแล้วแก้ไม่ได้
  if r.latitude is not null and r.longitude is not null then
    v_lines := v_lines || '' ||
      ('🗺️ https://www.google.com/maps?q=' || r.latitude || ',' || r.longitude);
  end if;

  return array_to_string(v_lines, chr(10));
end $line_msg_advisory$;

-- ============================================================
-- 3) ให้แอดมินกดส่งประกาศเข้าไลน์
-- ============================================================
-- line_broadcast กันส่งซ้ำให้อยู่แล้วด้วย unique index (kind, ref_id, target_id)
-- กดปุ่มซ้ำจึงไม่ทำให้กลุ่มได้ข้อความสองรอบ — จะคืนจำนวนที่ส่งได้จริงเป็น 0
create or replace function advisory_notify(p_token text, p_id bigint)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $advisory_notify$
declare v_err jsonb; v_text text; v_n int;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;

  v_text := line_msg_advisory(p_id);
  if v_text is null then
    return jsonb_build_object('success', false, 'message', 'ไม่พบประกาศนี้');
  end if;

  v_n := line_broadcast('advisory', v_text, p_id::text);

  if v_n = 0 then
    return jsonb_build_object('success', true, 'sent', 0,
      'message', 'ประกาศนี้เคยส่งเข้าไลน์ไปแล้ว หรือยังไม่ได้ตั้งปลายทาง');
  end if;
  return jsonb_build_object('success', true, 'sent', v_n,
    'message', 'ส่งเข้าไลน์แล้ว ' || v_n || ' ปลายทาง');
end $advisory_notify$;

grant execute on function advisory_notify(text, bigint) to anon, authenticated;
-- ตัวสร้างข้อความไม่ต้องเปิดให้ใครเรียกตรง — เรียกผ่าน advisory_notify เท่านั้น
revoke execute on function line_msg_advisory(bigint) from public, anon, authenticated;

-- ============================================================
-- 4) บันทึกประกาศ — เพิ่มช่องผลกระทบ
-- ============================================================
-- ทิ้งตัวเดิม 12 พารามิเตอร์ก่อน ไม่งั้นจะมีสองตัวชื่อเดียวกันในฐานข้อมูล
-- แล้ว PostgREST เลือกไม่ถูกว่าจะเรียกตัวไหน
drop function if exists advisory_save(text, bigint, text, text, text, text, text,
  double precision, double precision, timestamptz, timestamptz, jsonb);

create or replace function advisory_save(
  p_token text, p_id bigint, p_kind text, p_title text, p_place text,
  p_detail text, p_reroute text, p_lat double precision, p_lng double precision,
  p_starts timestamptz, p_ends timestamptz, p_images jsonb, p_impact text
) returns jsonb
language plpgsql security definer set search_path = public as $advisory_save$
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
    insert into traffic_advisories(kind, title, place, detail, reroute, latitude, longitude,
      starts_at, ends_at, images, impact, created_by)
    values (coalesce(nullif(trim(p_kind),''),'other'), trim(p_title), trim(p_place),
      nullif(trim(p_detail),''), nullif(trim(p_reroute),''), p_lat, p_lng, p_starts, p_ends,
      coalesce(p_images,'[]'::jsonb), nullif(trim(p_impact),''),
      coalesce(v_user->>'rank','') || ' ' || coalesce(v_user->>'firstName','') || ' ' || coalesce(v_user->>'lastName',''))
    returning id into v_id;
    return jsonb_build_object('success',true,'id',v_id,'message','ประกาศขึ้นหน้าเว็บแล้ว');
  else
    update traffic_advisories set
      kind = coalesce(nullif(trim(p_kind),''),'other'), title = trim(p_title), place = trim(p_place),
      detail = nullif(trim(p_detail),''), reroute = nullif(trim(p_reroute),''),
      latitude = p_lat, longitude = p_lng, starts_at = p_starts, ends_at = p_ends,
      images = coalesce(p_images,'[]'::jsonb), impact = nullif(trim(p_impact),''), closed_at = null
    where id = p_id;
    if not found then return jsonb_build_object('success',false,'message','ไม่พบประกาศนี้'); end if;
    return jsonb_build_object('success',true,'id',p_id,'message','แก้ไขประกาศเรียบร้อย');
  end if;
end $advisory_save$;

grant execute on function advisory_save(text, bigint, text, text, text, text, text,
  double precision, double precision, timestamptz, timestamptz, jsonb, text) to anon, authenticated;

-- ============================================================
-- ตรวจผลหลังรัน
-- ============================================================
-- ต้องมีคอลัมน์ impact
--   select column_name from information_schema.columns
--    where table_name = 'traffic_advisories' and column_name = 'impact';
--
-- ต้องเหลือ advisory_save ตัวเดียว (13 พารามิเตอร์)
--   select pg_get_function_identity_arguments(oid)
--     from pg_proc where proname = 'advisory_save';
--
-- ลองสร้างข้อความจากประกาศที่มีอยู่ (ยังไม่ส่งออกไลน์)
--   select line_msg_advisory(id) from traffic_advisories order by id desc limit 1;
--
-- ดูว่าเคยส่งอะไรไปแล้วบ้าง
--   select ref_id, target_id, ok, sent_at from line_sent
--    where kind = 'advisory' order by sent_at desc;
