-- ============================================================
-- โครงข่ายถนน - สถานที่ข้างทางและการนับ (ส่วนที่ 3 ของ 3)
-- ============================================================
-- ต้องรัน roadnet_1_tables.sql และ roadnet_2_rpc.sql ก่อน
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
-- ถ้าบรรทัดแรกเป็นข้อความไทยลอย ๆ แปลว่า paste ขาดหัว ให้วางใหม่
-- ============================================================

set search_path = public, extensions;

-- ============================================================
-- สถานที่ข้างทาง - บันทึก ลบ นำเข้า
-- ============================================================
create or replace function rn_place_save(p_token text, p_id bigint, p_row jsonb) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare v_err jsonb; v_user jsonb; v_id bigint;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  v_user := officer_session_user(p_token);

  if coalesce(p_row->>'name','') = '' or coalesce(p_row->>'kind','') = '' then
    return jsonb_build_object('success', false, 'message', 'กรุณากรอกประเภทและชื่อสถานที่');
  end if;
  if nullif(p_row->>'latitude','') is null or nullif(p_row->>'longitude','') is null then
    return jsonb_build_object('success', false, 'message', 'กรุณาระบุพิกัด');
  end if;

  if p_id is null then
    insert into rn_places(kind, name, road_id, segment_id, subdistrict, in_municipality,
      latitude, longitude, side, risk_level, open_hours, student_count, note, created_by)
    values (p_row->>'kind', p_row->>'name',
      nullif(p_row->>'road_id','')::bigint, nullif(p_row->>'segment_id','')::bigint,
      nullif(p_row->>'subdistrict',''), coalesce((p_row->>'in_municipality')::boolean, false),
      (p_row->>'latitude')::float8, (p_row->>'longitude')::float8,
      nullif(p_row->>'side',''), coalesce(nullif(p_row->>'risk_level',''), 'ปกติ'),
      nullif(p_row->>'open_hours',''), nullif(p_row->>'student_count','')::int,
      nullif(p_row->>'note',''),
      (v_user->>'rank') || ' ' || (v_user->>'firstName') || ' ' || (v_user->>'lastName'))
    returning id into v_id;
  else
    update rn_places set
      kind = p_row->>'kind', name = p_row->>'name',
      road_id = nullif(p_row->>'road_id','')::bigint,
      segment_id = nullif(p_row->>'segment_id','')::bigint,
      subdistrict = nullif(p_row->>'subdistrict',''),
      in_municipality = coalesce((p_row->>'in_municipality')::boolean, false),
      latitude = (p_row->>'latitude')::float8, longitude = (p_row->>'longitude')::float8,
      side = nullif(p_row->>'side',''),
      risk_level = coalesce(nullif(p_row->>'risk_level',''), 'ปกติ'),
      open_hours = nullif(p_row->>'open_hours',''),
      student_count = nullif(p_row->>'student_count','')::int,
      note = nullif(p_row->>'note',''), updated_at = now()
     where id = p_id
    returning id into v_id;
    if v_id is null then return jsonb_build_object('success', false, 'message', 'ไม่พบสถานที่ที่ต้องการแก้ไข'); end if;
  end if;

  return jsonb_build_object('success', true, 'id', v_id, 'message', 'บันทึกสถานที่แล้ว');
end $$;

create or replace function rn_place_delete(p_token text, p_id bigint) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare v_err jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  delete from rn_places where id = p_id;
  return jsonb_build_object('success', true, 'message', 'ลบสถานที่แล้ว');
end $$;

create or replace function rn_places_import(p_token text, p_rows jsonb, p_replace boolean) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare v_err jsonb; v_user jsonb; r jsonb; v_n int := 0; v_skip int := 0;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  v_user := officer_session_user(p_token);

  -- where id is not null จำเป็น Supabase เปิด sql_safe_updates ไว้ delete ทั้งตารางจะถูกบล็อก
  if coalesce(p_replace, false) then delete from rn_places where id is not null; end if;

  for r in select value from jsonb_array_elements(coalesce(p_rows, '[]'::jsonb))
  loop
    if coalesce(r->>'name','') = '' or nullif(r->>'latitude','') is null then
      v_skip := v_skip + 1;
      continue;
    end if;
    insert into rn_places(kind, name, road_id, subdistrict, in_municipality, latitude, longitude,
      side, risk_level, open_hours, student_count, note, created_by)
    values (coalesce(nullif(r->>'kind',''), 'อื่นๆ'), r->>'name',
      nullif(r->>'road_id','')::bigint, nullif(r->>'subdistrict',''),
      coalesce((r->>'in_municipality')::boolean, false),
      (r->>'latitude')::float8, (r->>'longitude')::float8,
      nullif(r->>'side',''), coalesce(nullif(r->>'risk_level',''), 'ปกติ'),
      nullif(r->>'open_hours',''), nullif(r->>'student_count','')::int, nullif(r->>'note',''),
      (v_user->>'rank') || ' ' || (v_user->>'firstName') || ' ' || (v_user->>'lastName'));
    v_n := v_n + 1;
  end loop;

  return jsonb_build_object('success', true, 'inserted', v_n, 'skipped', v_skip,
    'message', 'นำเข้าสถานที่ ' || v_n || ' แห่ง' || case when v_skip > 0 then ' (ข้าม ' || v_skip || ' แถวที่ข้อมูลไม่ครบ)' else '' end);
end $$;

-- ============================================================
-- นับอุบัติเหตุลงช่วงถนน - ใช้ระบายสีแผนที่และเรียงลำดับความเสี่ยง
-- ============================================================
create or replace function rn_refresh_counts(p_token text, p_months int) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare v_err jsonb; v_radius numeric; v_from timestamptz; v_touched int;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;

  v_radius := coalesce((select (val#>>'{}')::numeric from bs_settings where key = 'snapRadiusM'), 60);
  v_from := now() - make_interval(months => coalesce(p_months, 12));

  update rn_segments s set acc_count = 0, fatal_count = 0, drunk_count = 0 where id is not null;

  with pts as (
    select st_setsrid(st_makepoint(a.longitude, a.latitude), 4326)::geography g,
           (a.cause = 'เมาสุรา') as drunk,
           -- อ่านจากตัวแถวเอง ไม่ join ตาราง deaths เพราะจับคู่ด้วยเวลาอย่างเดียว
           -- จะพลาดเมื่อมีสองเหตุเวลาตรงกัน และวิธีนี้ครอบคลุมผู้โดยสารที่เสียชีวิตด้วย
           (a.party1::text like '%เสียชีวิต%' or a.party2::text like '%เสียชีวิต%') as fatal
      from accidents a
     where a.latitude is not null and a.longitude is not null
       and a.incident_datetime >= v_from
  ), hit as (
    select (select s.id from rn_segments s
             where st_dwithin(pts.g, s.geom, v_radius)
             order by s.geom <-> pts.g limit 1) sid,
           pts.drunk, pts.fatal
      from pts
  )
  update rn_segments s set
    acc_count   = t.n,
    fatal_count = t.nf,
    drunk_count = t.nd
    from (select sid, count(*) n, count(*) filter (where fatal) nf, count(*) filter (where drunk) nd
            from hit where sid is not null group by sid) t
   where s.id = t.sid;

  get diagnostics v_touched = row_count;
  return jsonb_build_object('success', true, 'segments', v_touched,
    'message', 'ปรับปรุงจำนวนอุบัติเหตุรายช่วงถนนแล้ว ' || v_touched || ' ช่วง (ย้อนหลัง ' || coalesce(p_months,12) || ' เดือน)');
end $$;

-- ============================================================
-- ปิดการเรียกตรงจากคนทั่วไป ทุกตัวตรวจ token อยู่แล้วแต่กันไว้อีกชั้น
-- ============================================================
-- ============================================================
-- ปิดการเรียกตรงจากคนทั่วไป
-- ============================================================
revoke execute on function rn_place_save(text, bigint, jsonb) from public;
revoke execute on function rn_place_delete(text, bigint) from public;
revoke execute on function rn_places_import(text, jsonb, boolean) from public;
revoke execute on function rn_refresh_counts(text, int) from public;

grant execute on function rn_place_save(text, bigint, jsonb) to anon, authenticated;
grant execute on function rn_place_delete(text, bigint) to anon, authenticated;
grant execute on function rn_places_import(text, jsonb, boolean) to anon, authenticated;
grant execute on function rn_refresh_counts(text, int) to anon, authenticated;
