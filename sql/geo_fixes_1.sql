-- ============================================================
-- แก้ 2 จุดที่เจอหลังรันจริง
-- ============================================================
-- ต้องรัน density_1_rpc.sql และ geocode_1..3 มาก่อน
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
--
-- 1) geo_density ล้มด้วย "Operation on mixed SRID geometries"
-- 2) geo_audit_names รายงานชื่อตำบลที่ถูกต้องว่าแปลงไม่ได้
-- ============================================================

set search_path = public, extensions;

-- ============================================================
-- 1) geo_density - ตะแกรงหกเหลี่ยมไม่มีระบบพิกัดติดมาด้วย
-- ============================================================
-- st_extent() คืนค่าเป็น box2d ซึ่งไม่เก็บ SRID ไว้ พอ cast เป็น geometry
-- จึงได้ SRID 0 แล้ว st_hexagongrid สร้างหกเหลี่ยมที่ SRID 0 ตามไปด้วย
-- ตอนเอาไปตัดกับจุดที่เป็น 32647 จึงล้มทั้งฟังก์ชัน
-- แก้โดยยัด SRID กลับเข้าไปที่กรอบก่อนส่งให้ st_hexagongrid
create or replace function geo_density(
  p_token  text        default null,
  p_from   timestamptz default null,
  p_to     timestamptz default null,
  p_edge_m int         default 250
) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_user   jsonb;
  v_min    int;
  v_from   timestamptz;
  v_to     timestamptz;
  v_edge   int;
  v_bounds geometry;
  v_cells  jsonb;
  v_total  int;
  v_shown  int;
  v_max    int;
begin
  if p_token is not null and p_token <> '' then
    v_user := officer_session_user(p_token);
  end if;
  v_min := case when v_user is null then 2 else 1 end;

  v_edge := greatest(80, least(2000, coalesce(p_edge_m, 250)));
  v_to   := coalesce(p_to, now());
  v_from := coalesce(p_from, v_to - interval '12 months');

  create temporary table if not exists tmp_geo_pt (g geometry) on commit drop;
  truncate tmp_geo_pt;

  insert into tmp_geo_pt (g)
  select st_transform(st_setsrid(st_makepoint(a.longitude, a.latitude), 4326), 32647)
  from accidents a
  where a.latitude is not null and a.longitude is not null
    and a.latitude between 14 and 17 and a.longitude between 99 and 101
    and a.incident_datetime >= v_from and a.incident_datetime < v_to;

  select count(*) into v_total from tmp_geo_pt;
  if v_total = 0 then
    return jsonb_build_object('success', true, 'cells', '[]'::jsonb, 'total', 0, 'shown', 0,
      'max_n', 0, 'edge_m', v_edge, 'min_per_cell', v_min,
      'period_start', v_from, 'period_end', v_to);
  end if;

  -- ตรงนี้คือจุดที่แก้ ต้อง st_setsrid ครอบไว้ ไม่งั้นได้กรอบ SRID 0
  select st_setsrid(st_expand(st_extent(g)::geometry, v_edge * 2), 32647)
    into v_bounds from tmp_geo_pt;

  with cells as (
    select h.geom from st_hexagongrid(v_edge::float8, v_bounds) h
  ),
  agg as (
    select c.geom, count(*)::int as n
    from cells c
    join tmp_geo_pt p on st_intersects(c.geom, p.g)
    group by c.geom
    having count(*) >= v_min
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'n', a.n,
           'polygon', (select jsonb_agg(jsonb_build_array(st_y(dp.geom), st_x(dp.geom)) order by dp.path[1])
                       from st_dumppoints(st_transform(a.geom, 4326)) dp)
         ) order by a.n desc), '[]'::jsonb),
         coalesce(sum(a.n), 0)::int,
         coalesce(max(a.n), 0)::int
    into v_cells, v_shown, v_max
  from agg a;

  return jsonb_build_object(
    'success', true, 'cells', v_cells, 'total', v_total, 'shown', v_shown,
    'max_n', v_max, 'edge_m', v_edge, 'min_per_cell', v_min,
    'period_start', v_from, 'period_end', v_to);
end $$;

grant execute on function geo_density(text, timestamptz, timestamptz, int) to anon, authenticated;

-- ============================================================
-- 2) geo_audit_names - ชื่อตำบลที่ถูกต้องถูกรายงานว่าแปลงไม่ได้
-- ============================================================
-- geo_resolve_sub ตั้งใจคืน null เมื่อชื่อซ้ำกันหลายที่และไม่ได้บอกอำเภอมาด้วย
-- ซึ่งถูกแล้วสำหรับการใช้งานทั่วไป แต่พอเอามาใช้ในหน้าตรวจสอบกลับให้ผลผิด
--
-- ของจริงที่เจอ: "หนองกรด" มีทั้งใน อ.เมืองนครสวรรค์ (600114)
-- และ อ.บรรพตพิสัย (600510) ในตาราง deaths มี 12 แถวใช้ชื่อนี้
-- หน้าตรวจสอบจึงขึ้นว่าแปลงไม่ได้ แล้วชวนให้ไปผูกชื่อพ้องทั้งที่เป็นชื่อทางการอยู่แล้ว
--
-- ข้อมูลของหน่วยอยู่ในเขต อ.เมืองนครสวรรค์ จึงลองหาในอำเภอนี้ก่อน
-- ไม่เจอค่อยถอยไปหาทั้งจังหวัดตามเดิม
create or replace function geo_audit_names(p_token text)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_err  jsonb;
  v_out  jsonb := '[]'::jsonb;
  v_rows jsonb;
  v_home text := 'เมืองนครสวรรค์';   -- อำเภอที่หน่วยรับผิดชอบ
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
                 'name', v, 'rows', c,
                 'sub_code', coalesce(geo_resolve_sub(v, %L), geo_resolve_sub(v))
               ) order by coalesce(geo_resolve_sub(v, %L), geo_resolve_sub(v)) nulls first, c desc), '[]'::jsonb)
        from (select nullif(btrim(%I), '') v, count(*) c
              from %I
              where nullif(btrim(%I), '') is not null
              group by 1) q
      $q$, v_home, v_home, v_src[i+1], v_src[i], v_src[i+1]) into v_rows;

      v_out := v_out || jsonb_build_array(jsonb_build_object(
        'table', v_src[i], 'label', v_src[i+2], 'values', v_rows));
    end if;
    i := i + 3;
  end loop;

  return jsonb_build_object(
    'success', true,
    'sources', v_out,
    'tambon', coalesce((select jsonb_agg(jsonb_build_object(
                'code', sub_code, 'name', sub_name, 'dist', dist_name) order by sub_code)
              from geo_codes where prov_code = 60), '[]'::jsonb),
    'aliases', coalesce((select jsonb_agg(jsonb_build_object(
                'alias', a.alias, 'sub_code', a.sub_code,
                'sub_name', g.sub_name, 'note', a.note) order by a.alias)
              from geo_aliases a join geo_codes g on g.sub_code = a.sub_code), '[]'::jsonb)
  );
end $$;

grant execute on function geo_audit_names(text) to anon, authenticated;

-- ============================================================
-- ตรวจผลหลังรัน
-- ============================================================
-- select jsonb_array_length(geo_density(null, null, null, 250)->'cells') as ช่องที่ได้;
-- select geo_resolve_sub('หนองกรด', 'เมืองนครสวรรค์') as ควรได้_600114;
