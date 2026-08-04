-- ============================================================
-- วิเคราะห์จุดเสี่ยงอุบัติเหตุ - RPC จัดการข้อมูล
-- ============================================================
-- ส่วนที่ 3 ของ 4 - รันเรียงตามลำดับใน Supabase SQL Editor
-- ต้องรันส่วนที่ 1-2 ก่อน และต้องมี admin_check_ จาก deaths_admin.sql
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
-- ถ้าบรรทัดแรกเป็นข้อความไทยลอย ๆ แปลว่า paste ขาดหัว ให้วางใหม่
-- ============================================================

-- ============================================================
-- RPC — ทั้งหมดตรวจสิทธิ์ admin ด้วย admin_check_ (จาก deaths_admin.sql)
-- ============================================================

-- ดึงข้อมูลทุกอย่างที่หน้า admin ต้องใช้ในครั้งเดียว
create or replace function bs_admin_data(p_token text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb; v_set jsonb; v_feat jsonb; v_inc jsonb; v_sites jsonb; v_zones jsonb; v_run jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;

  select coalesce(jsonb_object_agg(key, val), '{}'::jsonb) into v_set from bs_settings;
  select coalesce(jsonb_agg(to_jsonb(t) order by t.name), '[]'::jsonb) into v_feat from bs_features t;
  select coalesce(jsonb_agg(to_jsonb(t) order by t.occurred_at desc), '[]'::jsonb) into v_inc from bs_incidents t;
  select coalesce(jsonb_agg(to_jsonb(t) order by t.score desc nulls last), '[]'::jsonb) into v_sites from bs_sites t;
  select coalesce(jsonb_agg(to_jsonb(t) order by t.level, t.point_count desc), '[]'::jsonb) into v_zones from bs_zones t;
  select to_jsonb(t) into v_run from bs_runs t order by t.ran_at desc limit 1;

  return jsonb_build_object('success', true, 'settings', v_set, 'features', v_feat,
    'incidents', v_inc, 'sites', v_sites, 'zones', v_zones, 'lastRun', v_run);
end $$;

-- บันทึกค่าเกณฑ์ (ส่งมาเป็น object {key: number})
create or replace function bs_settings_save(p_token text, p_settings jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb; v_user jsonb; k text; v jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  v_user := officer_session_user(p_token);

  for k, v in select * from jsonb_each(coalesce(p_settings, '{}'::jsonb))
  loop
    insert into bs_settings(key, val, updated_at, updated_by)
    values (k, v, now(), v_user->>'policeCode')
    on conflict (key) do update set val = excluded.val, updated_at = now(), updated_by = excluded.updated_by;
  end loop;
  return jsonb_build_object('success', true, 'message', 'บันทึกค่าเกณฑ์แล้ว');
end $$;

-- เพิ่ม/แก้ไขจุดกายภาพเสี่ยง (p_id = null คือเพิ่มใหม่)
create or replace function bs_feature_save(p_token text, p_id bigint, p_row jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb; v_user jsonb; v_id bigint;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  v_user := officer_session_user(p_token);

  if coalesce(p_row->>'name','') = '' then
    return jsonb_build_object('success', false, 'message', 'กรุณากรอกชื่อจุด');
  end if;
  if p_row->>'latitude' is null or p_row->>'longitude' is null then
    return jsonb_build_object('success', false, 'message', 'กรุณาระบุพิกัด');
  end if;

  if p_id is null then
    insert into bs_features(kind, name, road, subdistrict, in_municipality, latitude, longitude, note, created_by)
    values (coalesce(p_row->>'kind','junction'), p_row->>'name', p_row->>'road', p_row->>'subdistrict',
            coalesce((p_row->>'in_municipality')::boolean, false),
            (p_row->>'latitude')::double precision, (p_row->>'longitude')::double precision,
            p_row->>'note', v_user->>'policeCode')
    returning id into v_id;
  else
    update bs_features set
      kind = coalesce(p_row->>'kind', kind),
      name = coalesce(p_row->>'name', name),
      road = p_row->>'road',
      subdistrict = p_row->>'subdistrict',
      in_municipality = coalesce((p_row->>'in_municipality')::boolean, in_municipality),
      latitude = (p_row->>'latitude')::double precision,
      longitude = (p_row->>'longitude')::double precision,
      note = p_row->>'note',
      updated_at = now()
     where id = p_id
    returning id into v_id;
    if v_id is null then return jsonb_build_object('success', false, 'message', 'ไม่พบจุดที่ต้องการแก้ไข'); end if;
  end if;

  return jsonb_build_object('success', true, 'id', v_id, 'message', 'บันทึกจุดกายภาพเสี่ยงแล้ว');
end $$;

create or replace function bs_feature_delete(p_token text, p_id bigint) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  delete from bs_features where id = p_id;
  if not found then return jsonb_build_object('success', false, 'message', 'ไม่พบข้อมูล'); end if;
  return jsonb_build_object('success', true, 'message', 'ลบแล้ว');
end $$;

-- นำเข้าจุดกายภาพเป็นชุด (p_replace = true คือล้างของเดิมก่อน)
create or replace function bs_features_import(p_token text, p_rows jsonb, p_replace boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb; v_user jsonb; r jsonb; v_n int := 0; v_skip int := 0;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  v_user := officer_session_user(p_token);

  -- where id is not null จำเป็น Supabase เปิด sql_safe_updates ไว้ delete ทั้งตารางจะถูกบล็อก
  if coalesce(p_replace, false) then delete from bs_features where id is not null; end if;

  for r in select value from jsonb_array_elements(coalesce(p_rows, '[]'::jsonb))
  loop
    if coalesce(r->>'name','') = '' or r->>'latitude' is null or r->>'longitude' is null then
      v_skip := v_skip + 1;
      continue;
    end if;
    insert into bs_features(kind, name, road, subdistrict, in_municipality, latitude, longitude, note, created_by)
    values (coalesce(r->>'kind','junction'), r->>'name', r->>'road', r->>'subdistrict',
            coalesce((r->>'in_municipality')::boolean, false),
            (r->>'latitude')::double precision, (r->>'longitude')::double precision,
            r->>'note', v_user->>'policeCode');
    v_n := v_n + 1;
  end loop;

  return jsonb_build_object('success', true, 'inserted', v_n, 'skipped', v_skip,
    'message', 'นำเข้าแล้ว ' || v_n || ' จุด' || case when v_skip > 0 then ' (ข้าม ' || v_skip || ' แถวที่ข้อมูลไม่ครบ)' else '' end);
end $$;

-- เพิ่ม/แก้ไขจุดเกิดเหตุเพิ่มเติม
create or replace function bs_incident_save(p_token text, p_id bigint, p_row jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb; v_user jsonb; v_id bigint;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  v_user := officer_session_user(p_token);

  if p_row->>'occurred_at' is null then
    return jsonb_build_object('success', false, 'message', 'กรุณาระบุวันเวลาเกิดเหตุ');
  end if;
  if p_row->>'latitude' is null or p_row->>'longitude' is null then
    return jsonb_build_object('success', false, 'message', 'กรุณาระบุพิกัด');
  end if;

  if p_id is null then
    insert into bs_incidents(occurred_at, latitude, longitude, place, road, subdistrict, in_municipality,
      direction, road_character, is_drunk, fatal_count, injury_count, cause, source, note, created_by)
    values ((p_row->>'occurred_at')::timestamptz,
            (p_row->>'latitude')::double precision, (p_row->>'longitude')::double precision,
            p_row->>'place', p_row->>'road', p_row->>'subdistrict',
            coalesce((p_row->>'in_municipality')::boolean, false),
            p_row->>'direction', p_row->>'road_character',
            coalesce((p_row->>'is_drunk')::boolean, false),
            coalesce((p_row->>'fatal_count')::int, 0), coalesce((p_row->>'injury_count')::int, 0),
            p_row->>'cause', p_row->>'source', p_row->>'note', v_user->>'policeCode')
    returning id into v_id;
  else
    update bs_incidents set
      occurred_at = (p_row->>'occurred_at')::timestamptz,
      latitude = (p_row->>'latitude')::double precision,
      longitude = (p_row->>'longitude')::double precision,
      place = p_row->>'place', road = p_row->>'road', subdistrict = p_row->>'subdistrict',
      in_municipality = coalesce((p_row->>'in_municipality')::boolean, in_municipality),
      direction = p_row->>'direction', road_character = p_row->>'road_character',
      is_drunk = coalesce((p_row->>'is_drunk')::boolean, is_drunk),
      fatal_count = coalesce((p_row->>'fatal_count')::int, 0),
      injury_count = coalesce((p_row->>'injury_count')::int, 0),
      cause = p_row->>'cause', source = p_row->>'source', note = p_row->>'note',
      updated_at = now()
     where id = p_id
    returning id into v_id;
    if v_id is null then return jsonb_build_object('success', false, 'message', 'ไม่พบข้อมูลที่ต้องการแก้ไข'); end if;
  end if;

  return jsonb_build_object('success', true, 'id', v_id, 'message', 'บันทึกข้อมูลจุดเกิดเหตุแล้ว');
end $$;

create or replace function bs_incident_delete(p_token text, p_id bigint) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  delete from bs_incidents where id = p_id;
  if not found then return jsonb_build_object('success', false, 'message', 'ไม่พบข้อมูล'); end if;
  return jsonb_build_object('success', true, 'message', 'ลบแล้ว');
end $$;

create or replace function bs_incidents_import(p_token text, p_rows jsonb, p_replace boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb; v_user jsonb; r jsonb; v_n int := 0; v_skip int := 0;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  v_user := officer_session_user(p_token);

  -- where id is not null จำเป็น Supabase เปิด sql_safe_updates ไว้ delete ทั้งตารางจะถูกบล็อก
  if coalesce(p_replace, false) then delete from bs_incidents where id is not null; end if;

  for r in select value from jsonb_array_elements(coalesce(p_rows, '[]'::jsonb))
  loop
    if r->>'occurred_at' is null or r->>'latitude' is null or r->>'longitude' is null then
      v_skip := v_skip + 1;
      continue;
    end if;
    begin
      insert into bs_incidents(occurred_at, latitude, longitude, place, road, subdistrict, in_municipality,
        direction, road_character, is_drunk, fatal_count, injury_count, cause, source, note, created_by)
      values ((r->>'occurred_at')::timestamptz,
              (r->>'latitude')::double precision, (r->>'longitude')::double precision,
              r->>'place', r->>'road', r->>'subdistrict',
              coalesce((r->>'in_municipality')::boolean, false),
              r->>'direction', r->>'road_character',
              coalesce((r->>'is_drunk')::boolean, false),
              coalesce((r->>'fatal_count')::int, 0), coalesce((r->>'injury_count')::int, 0),
              r->>'cause', r->>'source', r->>'note', v_user->>'policeCode');
      v_n := v_n + 1;
    exception when others then
      v_skip := v_skip + 1;   -- แถวที่แปลงวันที่/ตัวเลขไม่ผ่าน ข้ามไป ไม่ล้มทั้งชุด
    end;
  end loop;

  return jsonb_build_object('success', true, 'inserted', v_n, 'skipped', v_skip,
    'message', 'นำเข้าแล้ว ' || v_n || ' แถว' || case when v_skip > 0 then ' (ข้าม ' || v_skip || ' แถวที่ข้อมูลไม่ครบ/รูปแบบผิด)' else '' end);
end $$;

-- เพิ่ม/แก้ไขโซนที่ admin วาดเอง (source='manual')
create or replace function bs_zone_save(p_token text, p_id bigint, p_row jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb; v_user jsonb; v_id bigint;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  v_user := officer_session_user(p_token);

  if coalesce(p_row->>'title','') = '' then
    return jsonb_build_object('success', false, 'message', 'กรุณากรอกชื่อโซน');
  end if;
  if jsonb_array_length(coalesce(p_row->'polygon', '[]'::jsonb)) < 3 then
    return jsonb_build_object('success', false, 'message', 'ต้องวาดพื้นที่อย่างน้อย 3 จุด');
  end if;

  if p_id is null then
    insert into bs_zones(source, level, title, polygon, centroid_lat, centroid_lng, note,
                         area_km2, published, created_by)
    values ('manual', coalesce(p_row->>'level','red'), p_row->>'title', p_row->'polygon',
            (p_row->>'centroid_lat')::double precision, (p_row->>'centroid_lng')::double precision,
            p_row->>'note', (p_row->>'area_km2')::numeric,
            coalesce((p_row->>'published')::boolean, false), v_user->>'policeCode')
    returning id into v_id;
  else
    update bs_zones set
      level = coalesce(p_row->>'level', level),
      title = coalesce(p_row->>'title', title),
      polygon = coalesce(p_row->'polygon', polygon),
      centroid_lat = (p_row->>'centroid_lat')::double precision,
      centroid_lng = (p_row->>'centroid_lng')::double precision,
      note = p_row->>'note',
      area_km2 = (p_row->>'area_km2')::numeric,
      published = coalesce((p_row->>'published')::boolean, published),
      updated_at = now()
     where id = p_id and source = 'manual'
    returning id into v_id;
    if v_id is null then return jsonb_build_object('success', false, 'message', 'ไม่พบโซน หรือเป็นโซนที่ระบบสร้างอัตโนมัติ (แก้ไม่ได้)'); end if;
  end if;

  return jsonb_build_object('success', true, 'id', v_id, 'message', 'บันทึกโซนแล้ว');
end $$;

create or replace function bs_zone_delete(p_token text, p_id bigint) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  delete from bs_zones where id = p_id;
  if not found then return jsonb_build_object('success', false, 'message', 'ไม่พบข้อมูล'); end if;
  return jsonb_build_object('success', true, 'message', 'ลบแล้ว');
end $$;

-- เปิด/ปิดการเผยแพร่รายโซน (ใช้กับโซนที่วาดเอง)
create or replace function bs_zone_set_published(p_token text, p_id bigint, p_published boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  update bs_zones set published = coalesce(p_published, false), updated_at = now() where id = p_id;
  if not found then return jsonb_build_object('success', false, 'message', 'ไม่พบข้อมูล'); end if;
  return jsonb_build_object('success', true, 'message', case when p_published then 'เผยแพร่แล้ว' else 'ซ่อนจากหน้าประชาชนแล้ว' end);
end $$;
