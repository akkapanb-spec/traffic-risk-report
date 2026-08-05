-- ============================================================
-- ตรวจสอบชื่อตำบลในระบบ เทียบกับรหัสทางการ (ส่วนที่ 3)
-- ============================================================
-- ต้องรัน geocode_1_tables.sql และ geocode_2_nakhonsawan.sql ก่อน
-- และต้องมี admin_check_ จาก deaths_admin.sql
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
--
-- ไฟล์ที่แล้วสร้างรหัสกับตัวแปลชื่อไว้ ไฟล์นี้เอามาใช้จริง
-- คือไล่ดูว่าชื่อตำบลที่พิมพ์ไว้ในแต่ละตาราง แปลกลับเป็นรหัสได้หรือไม่
-- ชื่อที่แปลไม่ได้คือชื่อที่จะหายไปเงียบ ๆ ตอนเทียบข้อมูลกับแหล่งอื่น
-- ============================================================

set search_path = public, extensions;

-- ============================================================
-- 1) รายงานชื่อตำบลที่ใช้อยู่จริง พร้อมผลการแปลงเป็นรหัส
-- ============================================================
-- ตารางบางตัวมาจากไฟล์ที่อาจยังไม่ได้รัน จึงเช็ค to_regclass ก่อนทุกครั้ง
-- ไม่งั้นเจ้าหน้าที่ที่ยังไม่ได้ติดตั้งครบจะเปิดหน้านี้ไม่ได้เลย
create or replace function geo_audit_names(p_token text)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_err  jsonb;
  v_out  jsonb := '[]'::jsonb;
  v_rows jsonb;
  v_src  text[] := array[
    'accidents',      'subdistrict', 'ข้อมูลอุบัติเหตุ',
    'deaths',         'subdistrict', 'ผู้เสียชีวิต',
    'bs_features',    'subdistrict', 'ลักษณะทางกายภาพ',
    'rn_roads',       'subdistrict', 'โครงข่ายถนน',
    'cp_checkpoints', 'subdistrict', 'จุดตรวจ'
  ];
  i int;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;

  i := 1;
  while i <= array_length(v_src, 1) loop
    if to_regclass(v_src[i]) is not null then
      execute format($q$
        select coalesce(jsonb_agg(jsonb_build_object(
                 'name', v, 'rows', c, 'sub_code', geo_resolve_sub(v)
               ) order by geo_resolve_sub(v) nulls first, c desc), '[]'::jsonb)
        from (select nullif(btrim(%I), '') v, count(*) c
              from %I
              where nullif(btrim(%I), '') is not null
              group by 1) q
      $q$, v_src[i+1], v_src[i], v_src[i+1]) into v_rows;

      v_out := v_out || jsonb_build_array(jsonb_build_object(
        'table', v_src[i], 'label', v_src[i+2], 'values', v_rows));
    end if;
    i := i + 3;
  end loop;

  return jsonb_build_object(
    'success', true,
    'sources', v_out,
    -- รายชื่อตำบลทางการไว้ให้เลือกตอนผูกชื่อพ้อง
    'tambon', coalesce((select jsonb_agg(jsonb_build_object(
                'code', sub_code, 'name', sub_name, 'dist', dist_name) order by sub_code)
              from geo_codes where prov_code = 60), '[]'::jsonb),
    'aliases', coalesce((select jsonb_agg(jsonb_build_object(
                'alias', a.alias, 'sub_code', a.sub_code,
                'sub_name', g.sub_name, 'note', a.note) order by a.alias)
              from geo_aliases a join geo_codes g on g.sub_code = a.sub_code), '[]'::jsonb)
  );
end $$;

-- ============================================================
-- 2) ผูกชื่อที่ใช้จริง เข้ากับรหัสตำบลทางการ
-- ============================================================
create or replace function geo_alias_save(p_token text, p_alias text, p_sub_code int)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare v_err jsonb; v_alias text;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;

  -- เก็บชื่อแบบล้างคำนำหน้าแล้ว เพราะ geo_resolve_sub ล้างก่อนค้นเสมอ
  -- ถ้าเก็บ "ต.วัดไทรย์" ไว้ดิบ ๆ จะค้นไม่เจอตลอดกาล
  v_alias := geo_norm(p_alias);
  if v_alias is null then
    return jsonb_build_object('success', false, 'message', 'ยังไม่ได้ใส่ชื่อ');
  end if;
  if not exists (select 1 from geo_codes where sub_code = p_sub_code) then
    return jsonb_build_object('success', false, 'message', 'ไม่พบรหัสตำบลนี้');
  end if;
  if exists (select 1 from geo_codes where sub_name = v_alias) then
    return jsonb_build_object('success', false,
      'message', v_alias || ' เป็นชื่อทางการอยู่แล้ว ไม่ต้องผูกชื่อพ้อง');
  end if;

  insert into geo_aliases (alias, sub_code, note)
  values (v_alias, p_sub_code, 'ผูกจากหน้าตรวจสอบชื่อตำบล')
  on conflict (alias) do update set sub_code = excluded.sub_code;

  return jsonb_build_object('success', true, 'message', 'ผูก ' || v_alias || ' เรียบร้อย');
end $$;

create or replace function geo_alias_delete(p_token text, p_alias text)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare v_err jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;

  -- ต้องมี where เสมอ Supabase เปิด sql_safe_updates ไว้ delete ทั้งตารางจะถูกบล็อก
  delete from geo_aliases where alias = geo_norm(p_alias);
  return jsonb_build_object('success', true, 'message', 'ลบแล้ว');
end $$;

grant execute on function geo_audit_names(text)          to anon, authenticated;
grant execute on function geo_alias_save(text, text, int) to anon, authenticated;
grant execute on function geo_alias_delete(text, text)    to anon, authenticated;

-- ============================================================
-- ตรวจผลหลังรัน
-- ============================================================
-- ต้องเห็น deaths มีชื่อ วัดไทรย์ 9 แถว และ sub_code เป็น 600113 เพราะผูกชื่อพ้องไว้แล้ว
-- select jsonb_pretty(geo_audit_names('ใส่ token ของผู้ดูแล'));
