-- ============================================================
-- ประชากร อัตราต่อแสนประชากร และตารางสอบทาน - RPC (2 ของ 2)
-- ============================================================
-- ต้องรัน population_1_tables.sql ก่อน และต้องมี admin_check_ จาก deaths_admin.sql
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
-- ถ้าบรรทัดแรกเป็นข้อความไทยลอย ๆ แปลว่า paste ขาดหัว ให้วางใหม่
-- ============================================================

-- ============================================================
-- นำเข้าประชากร - ฝั่งเว็บอ่านไฟล์แล้วส่งแถวที่แยกส่วนบน/ส่วนล่างมาแล้ว
--   นำเข้าซ้ำงวดเดิมได้ ระบบทับของเก่าให้ ไม่เกิดแถวซ้ำ
-- ============================================================
create or replace function pop_import(p_token text, p_year int, p_month int, p_rows jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb; v_user jsonb; r jsonb; v_n int := 0;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  v_user := officer_session_user(p_token);

  if p_year is null then return jsonb_build_object('success', false, 'message', 'กรุณาระบุปีของข้อมูล'); end if;

  -- ล้างงวดเดิมก่อน จะได้ไม่ปนกับข้อมูลชุดใหม่
  -- where ครบทุกคอลัมน์ที่ระบุงวด Supabase เปิด sql_safe_updates ไว้ delete ทั้งตารางจะถูกบล็อก
  delete from pop_rows where period_year = p_year and period_month is not distinct from p_month;

  for r in select value from jsonb_array_elements(coalesce(p_rows, '[]'::jsonb))
  loop
    if coalesce(r->>'area_name','') = '' then continue; end if;
    insert into pop_rows(period_year, period_month, area_name, parent_name, in_municipality,
      male, female, total, households, by_age, created_by)
    values (p_year, p_month, r->>'area_name', nullif(r->>'parent_name',''),
      coalesce((r->>'in_municipality')::boolean, false),
      coalesce((r->>'male')::int, 0), coalesce((r->>'female')::int, 0),
      coalesce((r->>'total')::int, 0), coalesce((r->>'households')::int, 0),
      r->'by_age',
      (v_user->>'rank') || ' ' || (v_user->>'firstName') || ' ' || (v_user->>'lastName'))
    on conflict (period_year, period_month, area_name, parent_name, in_municipality) do update
      set male = excluded.male, female = excluded.female, total = excluded.total,
          households = excluded.households, by_age = excluded.by_age;
    v_n := v_n + 1;
  end loop;

  return jsonb_build_object('success', true, 'rows', v_n,
    'message', 'นำเข้าประชากร ' || v_n || ' แถว งวด ' || p_year || coalesce('/' || p_month, ''));
end $$;

-- ============================================================
-- อัตราการเสียชีวิตต่อประชากรแสนคน
--   คิดสามแบบ เพราะแต่ละแบบตอบคนละคำถาม
--     สะสม     ตัวเลขจริง ณ วันนี้ ยังไม่ครบปี ห้ามเอาไปเทียบเป้ารายปีตรง ๆ
--     คาดการณ์ ยืดตามสัดส่วนวันที่ผ่านไป ใช้เทียบเป้าได้
--     ปีก่อน   ช่วงเวลาเดียวกันของปีก่อน ตัดผลของฤดูกาลทิ้ง เชื่อได้กว่าการคาดการณ์
-- ============================================================
create or replace function pop_rates(p_token text, p_year int) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_user jsonb; v_year int; v_pop int; v_target numeric;
  v_days int; v_elapsed int; v_deaths int; v_prev int; v_period int;
begin
  v_user := officer_session_user(p_token);
  if v_user is null then
    return jsonb_build_object('success', false, 'code', 'AUTH_REQUIRED', 'message', 'กรุณาเข้าสู่ระบบใหม่');
  end if;

  v_year := coalesce(p_year, extract(year from (now() at time zone 'Asia/Bangkok'))::int);
  v_target := coalesce((select (val#>>'{}')::numeric from bs_settings where key = 'deathRateTarget'), 12);

  -- ประชากรงวดล่าสุดที่มี รวมเฉพาะแถวที่จับคู่เข้าพื้นที่รับผิดชอบแล้ว
  select coalesce(sum(p.total), 0) into v_pop
    from pop_rows p
    join pop_area_map m on m.source_area = p.area_name and m.source_muni = p.in_municipality
   where (p.period_year, coalesce(p.period_month, 0)) =
         (select period_year, coalesce(period_month, 0) from pop_rows
           order by period_year desc, period_month desc nulls last limit 1);

  v_days := case when (v_year % 4 = 0 and v_year % 100 <> 0) or v_year % 400 = 0 then 366 else 365 end;
  v_elapsed := least(v_days, greatest(1,
    (date_part('doy', (now() at time zone 'Asia/Bangkok'))::int)));
  -- ปีที่ผ่านไปแล้วนับเต็มปี ไม่ต้องคาดการณ์
  if v_year < extract(year from (now() at time zone 'Asia/Bangkok'))::int then v_elapsed := v_days; end if;

  select count(*) into v_deaths from deaths d
   where extract(year from (d.incident_datetime at time zone 'Asia/Bangkok')) = v_year;

  -- ช่วงเวลาเดียวกันของปีก่อน ตัดปัจจัยฤดูกาลออก
  select count(*) into v_prev from deaths d
   where extract(year from (d.incident_datetime at time zone 'Asia/Bangkok')) = v_year - 1
     and date_part('doy', (d.incident_datetime at time zone 'Asia/Bangkok')) <= v_elapsed;

  return jsonb_build_object('success', true,
    'year', v_year, 'population', v_pop, 'target', v_target,
    'daysElapsed', v_elapsed, 'daysInYear', v_days,
    'deaths', v_deaths, 'deathsPrevSamePeriod', v_prev,
    'rateToDate',  case when v_pop > 0 then round(v_deaths::numeric * 100000 / v_pop, 2) end,
    'projected',   case when v_elapsed > 0 then round(v_deaths::numeric * v_days / v_elapsed, 1) end,
    'rateProjected', case when v_pop > 0 and v_elapsed > 0
        then round(v_deaths::numeric * v_days / v_elapsed * 100000 / v_pop, 2) end,
    'allowedDeaths', case when v_pop > 0 then round(v_pop * v_target / 100000, 1) end,
    -- คืนเฉพาะประชากรรายพื้นที่ ไม่นับผู้เสียชีวิตให้ที่นี่
    -- เพราะพื้นที่บนแผนที่ชื่อ "เทศบาลนครนครสวรรค์" ซึ่งไม่เคยปรากฏในช่อง subdistrict
    -- ของตาราง deaths (ที่นั่นเก็บชื่อตำบล) จับคู่ด้วยชื่อจึงได้ศูนย์เสมอ
    -- และตำบลเดียวกันมีทั้งส่วนในและนอกเขตเทศบาล แยกด้วยชื่อไม่ได้
    -- ต้องตัดสินจากพิกัดว่าจุดตกในรูปหลายเหลี่ยมไหน ซึ่งทำที่ฝั่งเว็บที่มีไฟล์ขอบเขตอยู่แล้ว
    'byArea', coalesce((select jsonb_agg(to_jsonb(t) order by t.population desc) from (
        select m.map_area, sum(p.total)::int as population, sum(p.households)::int as households
          from pop_area_map m
          join pop_rows p on p.area_name = m.source_area and p.in_municipality = m.source_muni
         where (p.period_year, coalesce(p.period_month, 0)) =
               (select period_year, coalesce(period_month, 0) from pop_rows
                 order by period_year desc, period_month desc nulls last limit 1)
         group by m.map_area) t), '[]'::jsonb));
end $$;

-- ============================================================
-- ตารางสอบทานกับแหล่งอื่น
-- ============================================================
create or replace function recon_save(p_token text, p_row jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb; v_user jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  v_user := officer_session_user(p_token);

  if coalesce(p_row->>'source','') = '' or nullif(p_row->>'period_year','') is null then
    return jsonb_build_object('success', false, 'message', 'กรุณาระบุแหล่งข้อมูลและปี');
  end if;

  insert into recon_counts(period_year, period_month, map_area, source, deaths, injuries, checked, finding, entered_by)
  values ((p_row->>'period_year')::int, nullif(p_row->>'period_month','')::int,
    nullif(p_row->>'map_area',''), p_row->>'source',
    coalesce((p_row->>'deaths')::int, 0), nullif(p_row->>'injuries','')::int,
    coalesce((p_row->>'checked')::boolean, false), nullif(p_row->>'finding',''),
    (v_user->>'rank') || ' ' || (v_user->>'firstName') || ' ' || (v_user->>'lastName'))
  on conflict (period_year, period_month, map_area, source) do update
    set deaths = excluded.deaths, injuries = excluded.injuries,
        checked = excluded.checked, finding = excluded.finding,
        entered_by = excluded.entered_by, updated_at = now();

  return jsonb_build_object('success', true, 'message', 'บันทึกตัวเลขสอบทานแล้ว');
end $$;

-- ============================================================
-- โหลดข้อมูลทั้งหมดของหน้าจัดการ พร้อมผลต่างที่คำนวณไว้แล้ว
-- ============================================================
create or replace function pop_admin_data(p_token text, p_year int) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb; v_year int;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  v_year := coalesce(p_year, extract(year from (now() at time zone 'Asia/Bangkok'))::int);

  return jsonb_build_object('success', true,
    'periods', coalesce((select jsonb_agg(distinct jsonb_build_object('year', period_year, 'month', period_month))
      from pop_rows), '[]'::jsonb),
    'rows', coalesce((select jsonb_agg(to_jsonb(x) order by x.in_municipality, x.area_name)
      from (select area_name, parent_name, in_municipality, male, female, total, households,
                   period_year, period_month
              from pop_rows
             where (period_year, coalesce(period_month, 0)) =
                   (select period_year, coalesce(period_month, 0) from pop_rows
                     order by period_year desc, period_month desc nulls last limit 1)) x), '[]'::jsonb),
    'areaMap', coalesce((select jsonb_agg(to_jsonb(m) order by m.map_area) from pop_area_map m), '[]'::jsonb),
    'recon', coalesce((select jsonb_agg(to_jsonb(r) order by r.source, r.map_area)
      from recon_counts r where r.period_year = v_year), '[]'::jsonb));
end $$;

-- ============================================================
-- ปิดการเรียกตรงจากคนทั่วไป
-- ============================================================
revoke execute on function pop_import(text, int, int, jsonb) from public;
revoke execute on function recon_save(text, jsonb) from public;

grant execute on function pop_import(text, int, int, jsonb) to anon, authenticated;
grant execute on function pop_rates(text, int) to anon, authenticated;
grant execute on function recon_save(text, jsonb) to anon, authenticated;
grant execute on function pop_admin_data(text, int) to anon, authenticated;
