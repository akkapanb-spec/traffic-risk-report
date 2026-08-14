-- ============================================================
-- รายงานเส้นทางเลี่ยง — เจ้าหน้าที่ที่เกิดเหตุแจ้ง แอดมินตรวจแล้วประกาศ
-- ============================================================
-- ต้องรัน officer.sql, avoid_admin.sql, line_1 ถึง line_5 และ line_11 มาก่อน
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
--
-- ทำไมแยกเป็นสองขั้น ไม่ให้ยิงเข้าไลน์ตรงจากที่เกิดเหตุ
--   คนกรอกคือเจ้าหน้าที่ที่อยู่หน้างาน กำลังวุ่นกับการจัดการจราจร
--   ข้อความที่ส่งเข้ากลุ่มแล้วเรียกคืนไม่ได้ และนี่เป็นเสียงของหน่วยงาน
--   จึงให้หน้างานกรอกเป็นร่างไว้ แล้วแอดมินอ่านทวนก่อนกดประกาศ
--
--   ผลพลอยได้คือหน้างานกรอกผิดก็แก้ได้ก่อนออก ไม่ต้องส่งข้อความแก้ตามหลัง
--
-- ใครทำอะไรได้
--   เจ้าหน้าที่ทุกคน  ส่งรายงานจากที่เกิดเหตุ (officer_session_user)
--   แอดมินเท่านั้น    ตรวจ แก้ ประกาศ หรือทิ้ง (admin_check_)
-- ============================================================

set search_path = public, extensions;

-- ============================================================
-- 1) ตาราง
-- ============================================================
create table if not exists avoid_reports (
  id           bigint generated always as identity primary key,
  occurred_at  timestamptz not null default now(),
  vehicle1     text,                               -- รถคันที่ 1 ชนกับ
  vehicle2     text,                               -- รถคันที่ 2
  road         text,                               -- ชื่อถนน ใส่เลขทางหลวงมาด้วยได้
  direction    text,                               -- ขาขึ้น / ขาล่อง / ขาเข้าเมือง / ขาออก
  lanes        int,                                -- ผ่านได้กี่ช่องจราจร
  reroute      text,                               -- เส้นทางเลี่ยงที่แนะนำ
  latitude     double precision,
  longitude    double precision,
  note         text,
  status       text not null default 'pending',    -- pending / published / rejected
  advisory_id  bigint,                             -- ผูกกับประกาศที่สร้างขึ้นตอนประกาศ
  created_by   text,
  created_at   timestamptz not null default now(),
  reviewed_by  text,
  reviewed_at  timestamptz
);

create index if not exists avoid_reports_pending_idx
  on avoid_reports (created_at desc) where status = 'pending';

-- ปิดหมด เข้าถึงผ่าน RPC เท่านั้น
-- ร่างที่ยังไม่ตรวจไม่ควรให้ใครอ่านได้ เพราะยังไม่ผ่านการทวนสอบ
alter table avoid_reports enable row level security;

-- ============================================================
-- 2) ข้อความที่จะส่งเข้าไลน์
-- ============================================================
-- รูปแบบตามที่กำหนดไว้ ช่องที่ไม่ได้กรอกจะถูกข้ามทั้งบรรทัด
-- ไม่ใส่คำว่า "ไม่ระบุ" ค้างไว้ให้รก
create or replace function line_msg_avoid_report(p_id bigint)
returns text
language plpgsql stable security definer set search_path = public, extensions as $line_msg_avoid_report$
declare
  r record;
  v text[];
  v_when timestamp;
  m text[] := array['ม.ค.','ก.พ.','มี.ค.','เม.ย.','พ.ค.','มิ.ย.','ก.ค.','ส.ค.','ก.ย.','ต.ค.','พ.ย.','ธ.ค.'];
begin
  select * into r from avoid_reports where id = p_id;
  if not found then return null; end if;

  v_when := timezone('Asia/Bangkok', r.occurred_at);

  v := array[
    '⚠️ ด่วน!! แจ้งเหตุ เส้นทางที่ควรเลี่ยง',
    '',
    '🕐 วันนี้ ' || to_char(v_when, 'FMDD') || ' ' || m[extract(month from v_when)::int] ||
      ' พ.ศ. ' || (extract(year from v_when)::int + 543)::text ||
      ' เวลา ' || to_char(v_when, 'HH24:MI') || ' น.'
  ];

  -- "[อุบัติเหตุ] รถ... กับรถ..." — คันที่สองไม่มีก็ได้ เช่นชนเดี่ยวหรือชนคนเดินเท้า
  if coalesce(btrim(r.vehicle1), '') <> '' then
    v := v || ('[อุบัติเหตุ] รถ' || btrim(r.vehicle1) ||
      case when coalesce(btrim(r.vehicle2), '') <> '' then ' กับรถ' || btrim(r.vehicle2) else '' end);
  end if;

  if coalesce(btrim(r.road), '') <> '' then
    v := v || ('📍 ' || btrim(r.road) ||
      case when coalesce(btrim(r.direction), '') <> '' then ' ' || btrim(r.direction) else '' end ||
      ' ขณะนี้เจ้าหน้าที่อำนวยการจราจร');
  end if;

  if r.lanes is not null then
    v := v || ('🚦 ผลกระทบ: สัญจรผ่าน ' || r.lanes || ' ช่องจราจร');
  end if;

  if coalesce(btrim(r.reroute), '') <> '' then
    v := v || ('↩️ เส้นทางเลี่ยง: ' || btrim(r.reroute));
  end if;

  if coalesce(btrim(r.note), '') <> '' then
    v := v || btrim(r.note);
  end if;

  -- พิกัดแปลงเป็นลิงก์ Google Maps กดแล้วนำทางได้เลย
  -- ไม่ลิงก์เว็บของเรา เพราะข้อความที่ส่งไปแล้วแก้ไม่ได้ ส่วนที่อยู่เว็บเปลี่ยนได้
  if r.latitude is not null and r.longitude is not null then
    v := v || ('🗺️ พิกัด: https://www.google.com/maps?q=' ||
      round(r.latitude::numeric, 6) || ',' || round(r.longitude::numeric, 6));
  end if;

  return array_to_string(v, chr(10));
end $line_msg_avoid_report$;

revoke execute on function line_msg_avoid_report(bigint) from public, anon, authenticated;

-- ============================================================
-- 3) เจ้าหน้าที่หน้างานส่งรายงาน
-- ============================================================
-- ไม่ใช้ admin_check_ เพราะคนที่อยู่ที่เกิดเหตุคือเจ้าหน้าที่ทั่วไป ไม่ใช่แอดมิน
create or replace function avoid_report_save(
  p_token text, p_id bigint, p_occurred timestamptz,
  p_vehicle1 text, p_vehicle2 text, p_road text, p_direction text,
  p_lanes int, p_reroute text, p_lat double precision, p_lng double precision, p_note text
) returns jsonb
language plpgsql security definer set search_path = public, extensions as $avoid_report_save$
declare v_user jsonb; v_id bigint; v_name text;
begin
  v_user := officer_session_user(p_token);
  if v_user is null then
    return jsonb_build_object('success', false, 'code', 'AUTH_REQUIRED', 'message', 'กรุณาเข้าสู่ระบบใหม่');
  end if;
  if coalesce(btrim(p_road), '') = '' then
    return jsonb_build_object('success', false, 'message', 'กรุณากรอกชื่อถนน');
  end if;

  v_name := btrim(coalesce(v_user->>'rank','') || ' ' || coalesce(v_user->>'firstName','') || ' ' || coalesce(v_user->>'lastName',''));

  if p_id is null then
    insert into avoid_reports(occurred_at, vehicle1, vehicle2, road, direction, lanes,
      reroute, latitude, longitude, note, created_by)
    values (coalesce(p_occurred, now()), nullif(btrim(p_vehicle1),''), nullif(btrim(p_vehicle2),''),
      btrim(p_road), nullif(btrim(p_direction),''), p_lanes, nullif(btrim(p_reroute),''),
      p_lat, p_lng, nullif(btrim(p_note),''), v_name)
    returning id into v_id;
    return jsonb_build_object('success', true, 'id', v_id,
      'message', 'ส่งรายงานแล้ว รอผู้ดูแลตรวจก่อนประกาศ');
  end if;

  -- แก้ได้เฉพาะร่างที่ยังไม่ประกาศ ประกาศไปแล้วต้องไปแก้ที่ตัวประกาศแทน
  update avoid_reports set
    occurred_at = coalesce(p_occurred, occurred_at),
    vehicle1 = nullif(btrim(p_vehicle1),''), vehicle2 = nullif(btrim(p_vehicle2),''),
    road = btrim(p_road), direction = nullif(btrim(p_direction),''), lanes = p_lanes,
    reroute = nullif(btrim(p_reroute),''), latitude = p_lat, longitude = p_lng,
    note = nullif(btrim(p_note),'')
  where id = p_id and status = 'pending';
  if not found then
    return jsonb_build_object('success', false, 'message', 'ไม่พบร่างนี้ หรือประกาศไปแล้ว');
  end if;
  return jsonb_build_object('success', true, 'id', p_id, 'message', 'แก้ไขร่างเรียบร้อย');
end $avoid_report_save$;

grant execute on function avoid_report_save(text, bigint, timestamptz, text, text, text, text,
  int, text, double precision, double precision, text) to anon, authenticated;

-- ============================================================
-- 4) รายการร่างที่รอตรวจ + จำนวนสำหรับจุดแดงบนเมนู
-- ============================================================
create or replace function avoid_report_list(p_token text)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $avoid_report_list$
declare v_err jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;

  return jsonb_build_object('success', true,
    'rows', coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at desc)
                        from avoid_reports x where x.status = 'pending'), '[]'::jsonb),
    'pending', (select count(*) from avoid_reports where status = 'pending'));
end $avoid_report_list$;

grant execute on function avoid_report_list(text) to anon, authenticated;

-- ============================================================
-- 5) ประกาศขึ้นหน้าเว็บ + แจ้งเข้าไลน์
-- ============================================================
-- ทำสองอย่างในคำสั่งเดียวเพราะเป็นการตัดสินใจเดียวกัน
-- ถ้าแยกปุ่ม จะเกิดสภาพประกาศขึ้นเว็บแล้วแต่ยังไม่แจ้ง ซึ่งไม่มีใครอยากได้
--
-- ไลน์ล้มไม่ทำให้ประกาศล้มตาม ประกาศขึ้นเว็บไปแล้วถือว่าสำเร็จ
-- แล้วบอกในข้อความตอบกลับว่าส่วนไลน์ไม่ผ่าน จะได้กดส่งซ้ำได้
create or replace function avoid_report_publish(p_token text, p_id bigint, p_hours int default 6)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $avoid_report_publish$
declare
  v_err jsonb; v_user jsonb; r record; v_adv bigint; v_txt text; v_sent int := 0;
  v_title text; v_impact text;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  v_user := officer_session_user(p_token);

  select * into r from avoid_reports where id = p_id and status = 'pending';
  if not found then
    return jsonb_build_object('success', false, 'message', 'ไม่พบร่างนี้ หรือประกาศไปแล้ว');
  end if;

  v_title := 'อุบัติเหตุ' ||
    case when coalesce(btrim(r.vehicle1),'') <> ''
         then ' รถ' || btrim(r.vehicle1) ||
              case when coalesce(btrim(r.vehicle2),'') <> '' then ' กับรถ' || btrim(r.vehicle2) else '' end
         else '' end;
  v_impact := case when r.lanes is not null then 'สัญจรผ่าน ' || r.lanes || ' ช่องจราจร' else null end;

  -- ขึ้นหน้าประชาชนผ่านตารางประกาศเดิม จะได้ใช้แผนที่ ประวัติ และการหมดอายุที่มีอยู่แล้ว
  insert into traffic_advisories(kind, title, place, detail, reroute, latitude, longitude,
    starts_at, ends_at, created_by)
  values ('accident', v_title,
    btrim(r.road) || case when coalesce(btrim(r.direction),'') <> '' then ' ' || btrim(r.direction) else '' end,
    coalesce(v_impact || case when coalesce(btrim(r.note),'') <> '' then ' · ' || btrim(r.note) else '' end,
             nullif(btrim(r.note),'')),
    nullif(btrim(r.reroute),''), r.latitude, r.longitude,
    r.occurred_at, r.occurred_at + make_interval(hours => greatest(1, coalesce(p_hours, 6))),
    btrim(coalesce(v_user->>'rank','') || ' ' || coalesce(v_user->>'firstName','') || ' ' || coalesce(v_user->>'lastName','')))
  returning id into v_adv;

  update avoid_reports
     set status = 'published', advisory_id = v_adv,
         reviewed_by = btrim(coalesce(v_user->>'rank','') || ' ' || coalesce(v_user->>'firstName','') || ' ' || coalesce(v_user->>'lastName','')),
         reviewed_at = now()
   where id = p_id;

  v_txt := line_msg_avoid_report(p_id);
  if v_txt is not null then
    begin
      v_sent := line_broadcast('avoid', v_txt, p_id::text);
    exception when others then
      v_sent := -1;   -- ไลน์ล้ม แต่ประกาศขึ้นเว็บไปแล้ว ถือว่าสำเร็จบางส่วน
    end;
  end if;

  return jsonb_build_object('success', true, 'advisory_id', v_adv, 'sent', v_sent,
    'message', case when v_sent > 0 then 'ประกาศขึ้นหน้าเว็บและแจ้งเข้าไลน์แล้ว'
                    when v_sent = 0 then 'ประกาศขึ้นหน้าเว็บแล้ว แต่ยังไม่มีกลุ่มปลายทางที่เปิดรับ'
                    else 'ประกาศขึ้นหน้าเว็บแล้ว แต่ส่งไลน์ไม่สำเร็จ' end);
end $avoid_report_publish$;

grant execute on function avoid_report_publish(text, bigint, int) to anon, authenticated;

-- ============================================================
-- 6) ทิ้งร่าง
-- ============================================================
create or replace function avoid_report_reject(p_token text, p_id bigint)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $avoid_report_reject$
declare v_err jsonb; v_user jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  v_user := officer_session_user(p_token);

  update avoid_reports
     set status = 'rejected',
         reviewed_by = btrim(coalesce(v_user->>'rank','') || ' ' || coalesce(v_user->>'firstName','') || ' ' || coalesce(v_user->>'lastName','')),
         reviewed_at = now()
   where id = p_id and status = 'pending';
  if not found then return jsonb_build_object('success', false, 'message', 'ไม่พบร่างนี้'); end if;
  -- ไม่ลบทิ้ง เก็บไว้ดูย้อนหลังได้ว่าหน้างานเคยแจ้งอะไรมาบ้างและทำไมไม่ประกาศ
  return jsonb_build_object('success', true, 'message', 'ทิ้งร่างแล้ว');
end $avoid_report_reject$;

grant execute on function avoid_report_reject(text, bigint) to anon, authenticated;

-- ============================================================
-- ตรวจผลหลังรัน
-- ============================================================
-- ตารางต้องมีและปิด RLS ไว้
--   select relname, relrowsecurity from pg_class where relname = 'avoid_reports';
--
-- ฟังก์ชันครบ 5 ตัว
--   select proname from pg_proc where proname like 'avoid_report%' or proname = 'line_msg_avoid_report';
--
-- ทดลองสร้างข้อความจากร่างที่มี (ยังไม่ส่งออกไลน์)
--   select line_msg_avoid_report(id) from avoid_reports order by id desc limit 1;
--
-- ร่างที่รอตรวจ
--   select id, road, lanes, status, created_by, created_at from avoid_reports order by id desc;
