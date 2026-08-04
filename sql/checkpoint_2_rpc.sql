-- ============================================================
-- จุดตรวจกวดขันวินัยจราจร และชุดตรวจวัดแอลกอฮอล์ - RPC (2 ของ 2)
-- ============================================================
-- ต้องรัน checkpoint_1_tables.sql ก่อน และต้องมี admin_check_ จาก deaths_admin.sql
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
-- ถ้าบรรทัดแรกเป็นข้อความไทยลอย ๆ แปลว่า paste ขาดหัว ให้วางใหม่
-- ============================================================

-- ============================================================
-- โหลดรายการจุดตรวจตามช่วงวันที่ พร้อมรายชื่อผู้ถูกจับ
--   เจ้าหน้าที่ทุกคนดูได้ ไม่ต้องเป็น admin
-- ============================================================
create or replace function cp_list(p_token text, p_from date, p_to date) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_user jsonb;
begin
  v_user := officer_session_user(p_token);
  if v_user is null then
    return jsonb_build_object('success', false, 'code', 'AUTH_REQUIRED', 'message', 'กรุณาเข้าสู่ระบบใหม่');
  end if;

  return jsonb_build_object('success', true,
    'charges', coalesce((select jsonb_agg(to_jsonb(x) order by x.sort_order, x.name)
      from (select name, grp, sort_order from cp_charges where active) x), '[]'::jsonb),
    'rows', coalesce((select jsonb_agg(to_jsonb(x) order by x.duty_date desc, x.id desc)
      from (
        select c.id, c.kind, c.duty_date, c.start_time, c.end_time, c.place,
               c.road_id, c.road_name, c.subdistrict, c.in_municipality,
               c.latitude, c.longitude, c.commander, c.officer_count,
               c.vehicles_checked, c.breath_tested, c.arrest_count, c.note,
               coalesce((select jsonb_agg(to_jsonb(a) order by a.id)
                 from (select id, person_ref, gender, age, vehicle, charge, charge_group,
                              alcohol_mg, fine_amount, note
                         from cp_arrests where checkpoint_id = c.id) a), '[]'::jsonb) as arrests
          from cp_checkpoints c
         where (p_from is null or c.duty_date >= p_from)
           and (p_to   is null or c.duty_date <= p_to)
      ) x), '[]'::jsonb));
end $$;

-- ============================================================
-- บันทึกจุดตรวจ พร้อมรายชื่อผู้ถูกจับทั้งชุดในครั้งเดียว
--   p_row.arrests เป็น array ระบบลบของเดิมแล้วใส่ชุดใหม่ทั้งหมด
--   ทำแบบนี้เพราะฟอร์มฝั่งเว็บแก้ทั้งตารางพร้อมกัน ไม่ได้แก้ทีละแถว
-- ============================================================
create or replace function cp_save(p_token text, p_id bigint, p_row jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb; v_user jsonb; v_id bigint; a jsonb; v_n int := 0;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  v_user := officer_session_user(p_token);

  if coalesce(p_row->>'kind','') = '' then
    return jsonb_build_object('success', false, 'message', 'กรุณาเลือกประเภทจุดตรวจ');
  end if;
  if nullif(p_row->>'duty_date','') is null then
    return jsonb_build_object('success', false, 'message', 'กรุณาระบุวันที่ตั้งจุดตรวจ');
  end if;

  if p_id is null then
    insert into cp_checkpoints(kind, duty_date, start_time, end_time, place, road_id, road_name,
      subdistrict, in_municipality, latitude, longitude, commander, officer_count,
      vehicles_checked, breath_tested, note, created_by)
    values (p_row->>'kind', (p_row->>'duty_date')::date,
      nullif(p_row->>'start_time','')::time, nullif(p_row->>'end_time','')::time,
      nullif(p_row->>'place',''), nullif(p_row->>'road_id','')::bigint, nullif(p_row->>'road_name',''),
      nullif(p_row->>'subdistrict',''), coalesce((p_row->>'in_municipality')::boolean, false),
      nullif(p_row->>'latitude','')::float8, nullif(p_row->>'longitude','')::float8,
      nullif(p_row->>'commander',''), nullif(p_row->>'officer_count','')::int,
      nullif(p_row->>'vehicles_checked','')::int, nullif(p_row->>'breath_tested','')::int,
      nullif(p_row->>'note',''),
      (v_user->>'rank') || ' ' || (v_user->>'firstName') || ' ' || (v_user->>'lastName'))
    returning id into v_id;
  else
    update cp_checkpoints set
      kind = p_row->>'kind', duty_date = (p_row->>'duty_date')::date,
      start_time = nullif(p_row->>'start_time','')::time,
      end_time = nullif(p_row->>'end_time','')::time,
      place = nullif(p_row->>'place',''), road_id = nullif(p_row->>'road_id','')::bigint,
      road_name = nullif(p_row->>'road_name',''), subdistrict = nullif(p_row->>'subdistrict',''),
      in_municipality = coalesce((p_row->>'in_municipality')::boolean, false),
      latitude = nullif(p_row->>'latitude','')::float8,
      longitude = nullif(p_row->>'longitude','')::float8,
      commander = nullif(p_row->>'commander',''),
      officer_count = nullif(p_row->>'officer_count','')::int,
      vehicles_checked = nullif(p_row->>'vehicles_checked','')::int,
      breath_tested = nullif(p_row->>'breath_tested','')::int,
      note = nullif(p_row->>'note',''), updated_at = now()
     where id = p_id
    returning id into v_id;
    if v_id is null then return jsonb_build_object('success', false, 'message', 'ไม่พบจุดตรวจที่ต้องการแก้ไข'); end if;
  end if;

  -- ชุดผู้ถูกจับถูกแทนที่ทั้งหมด ต้องมี where เสมอ Supabase เปิด sql_safe_updates ไว้
  delete from cp_arrests where checkpoint_id = v_id;

  for a in select value from jsonb_array_elements(coalesce(p_row->'arrests', '[]'::jsonb))
  loop
    if coalesce(a->>'charge','') = '' then continue; end if;
    insert into cp_arrests(checkpoint_id, person_ref, gender, age, vehicle, charge, charge_group,
      alcohol_mg, fine_amount, note)
    values (v_id, nullif(a->>'person_ref',''), nullif(a->>'gender',''),
      nullif(a->>'age','')::int, nullif(a->>'vehicle',''), a->>'charge',
      coalesce(nullif(a->>'charge_group',''),
               (select grp from cp_charges where name = a->>'charge'), 'อื่นๆ'),
      nullif(a->>'alcohol_mg','')::numeric, nullif(a->>'fine_amount','')::numeric,
      nullif(a->>'note',''));
    v_n := v_n + 1;
  end loop;

  return jsonb_build_object('success', true, 'id', v_id, 'arrests', v_n,
    'message', 'บันทึกจุดตรวจแล้ว · ผู้ถูกจับ ' || v_n || ' รายการ');
end $$;

create or replace function cp_delete(p_token text, p_id bigint) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  delete from cp_checkpoints where id = p_id;
  return jsonb_build_object('success', true, 'message', 'ลบจุดตรวจและรายชื่อผู้ถูกจับของจุดนี้แล้ว');
end $$;

-- ============================================================
-- นำเข้าจุดตรวจจากไฟล์ - หนึ่งแถวคือหนึ่งจุดตรวจ ยังไม่รวมผู้ถูกจับ
-- ============================================================
create or replace function cp_import(p_token text, p_rows jsonb, p_replace boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb; v_user jsonb; r jsonb; v_n int := 0; v_skip int := 0;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  v_user := officer_session_user(p_token);

  -- where id is not null จำเป็น Supabase เปิด sql_safe_updates ไว้ delete ทั้งตารางจะถูกบล็อก
  if coalesce(p_replace, false) then delete from cp_checkpoints where id is not null; end if;

  for r in select value from jsonb_array_elements(coalesce(p_rows, '[]'::jsonb))
  loop
    if coalesce(r->>'kind','') = '' or nullif(r->>'duty_date','') is null then
      v_skip := v_skip + 1;
      continue;
    end if;
    insert into cp_checkpoints(kind, duty_date, start_time, end_time, place, road_name,
      subdistrict, in_municipality, latitude, longitude, commander, officer_count,
      vehicles_checked, breath_tested, note, created_by)
    values (r->>'kind', (r->>'duty_date')::date,
      nullif(r->>'start_time','')::time, nullif(r->>'end_time','')::time,
      nullif(r->>'place',''), nullif(r->>'road_name',''), nullif(r->>'subdistrict',''),
      coalesce((r->>'in_municipality')::boolean, false),
      nullif(r->>'latitude','')::float8, nullif(r->>'longitude','')::float8,
      nullif(r->>'commander',''), nullif(r->>'officer_count','')::int,
      nullif(r->>'vehicles_checked','')::int, nullif(r->>'breath_tested','')::int,
      nullif(r->>'note',''),
      (v_user->>'rank') || ' ' || (v_user->>'firstName') || ' ' || (v_user->>'lastName'));
    v_n := v_n + 1;
  end loop;

  return jsonb_build_object('success', true, 'inserted', v_n, 'skipped', v_skip,
    'message', 'นำเข้าจุดตรวจ ' || v_n || ' จุด' || case when v_skip > 0 then ' (ข้าม ' || v_skip || ' แถวที่ข้อมูลไม่ครบ)' else '' end);
end $$;

-- ============================================================
-- สรุปผลการกวดขัน ใช้ทำกราฟและรายงาน
-- ============================================================
create or replace function cp_summary(p_token text, p_from date, p_to date) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_user jsonb;
begin
  v_user := officer_session_user(p_token);
  if v_user is null then
    return jsonb_build_object('success', false, 'code', 'AUTH_REQUIRED', 'message', 'กรุณาเข้าสู่ระบบใหม่');
  end if;

  return jsonb_build_object('success', true,
    'totals', (select jsonb_build_object(
        'checkpoints', count(*),
        'vehicles', coalesce(sum(vehicles_checked), 0),
        'breath', coalesce(sum(breath_tested), 0),
        'arrests', coalesce(sum(arrest_count), 0))
      from cp_checkpoints c
      where (p_from is null or c.duty_date >= p_from) and (p_to is null or c.duty_date <= p_to)),
    'byKind', coalesce((select jsonb_object_agg(kind, n) from (
        select c.kind, count(*) n from cp_checkpoints c
         where (p_from is null or c.duty_date >= p_from) and (p_to is null or c.duty_date <= p_to)
         group by c.kind) t), '{}'::jsonb),
    'byCharge', coalesce((select jsonb_agg(to_jsonb(t) order by t.n desc) from (
        select a.charge, a.charge_group, count(*) n
          from cp_arrests a join cp_checkpoints c on c.id = a.checkpoint_id
         where (p_from is null or c.duty_date >= p_from) and (p_to is null or c.duty_date <= p_to)
         group by a.charge, a.charge_group) t), '[]'::jsonb));
end $$;

-- ============================================================
-- ปิดการเรียกตรงจากคนทั่วไป
-- ============================================================
revoke execute on function cp_save(text, bigint, jsonb) from public;
revoke execute on function cp_delete(text, bigint) from public;
revoke execute on function cp_import(text, jsonb, boolean) from public;

grant execute on function cp_list(text, date, date) to anon, authenticated;
grant execute on function cp_save(text, bigint, jsonb) to anon, authenticated;
grant execute on function cp_delete(text, bigint) to anon, authenticated;
grant execute on function cp_import(text, jsonb, boolean) to anon, authenticated;
grant execute on function cp_summary(text, date, date) to anon, authenticated;
