-- ============================================================
-- แผนที่ความหนาแน่นอุบัติเหตุ ด้วย PostGIS
-- ============================================================
-- ต้องรัน roadnet_1_tables.sql ก่อน เพราะไฟล์นั้นเป็นตัวเปิด extension postgis
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
-- ถ้าบรรทัดแรกเป็นข้อความไทยลอย ๆ แปลว่าวางไฟล์ขาดหัว ให้ลากวางใหม่
--
-- ทำไมให้ฐานข้อมูลคำนวณ ไม่วาดจุดดิบบนแผนที่
--   จุดอุบัติเหตุพันกว่าจุดวางทับกันจนอ่านไม่ออกว่าตรงไหนหนักกว่ากัน
--   ตามองเห็นแค่ "จุดเยอะ" แต่บอกไม่ได้ว่าเยอะกว่ากันกี่เท่า
--   การรวมเป็นช่องหกเหลี่ยมแล้วนับต่อช่อง ทำให้เทียบความหนาแน่นกันได้จริง
--
-- ทำไมหกเหลี่ยม ไม่ใช่สี่เหลี่ยม
--   ช่องสี่เหลี่ยมมีระยะจากจุดกลางถึงขอบไม่เท่ากัน มุมไกลกว่าด้าน 1.41 เท่า
--   กลุ่มจุดที่วางเฉียงจึงถูกหั่นคนละแบบกับกลุ่มที่วางตรง เกิดลายเส้นตารางปลอม
--   หกเหลี่ยมมีเพื่อนบ้าน 6 ช่องระยะเท่ากันหมด ความหนาแน่นที่ได้จึงไม่ขึ้นกับแนววาง
--
-- ระบบพิกัด: ตัดช่องบน EPSG:32647 (UTM 47N) หน่วยเป็นเมตรและเป็นระนาบ
--   ถ้าตัดบน 4326 ตรง ๆ หน่วยจะเป็นองศา ช่องจะบิดเพราะที่ละติจูด 15.7
--   หนึ่งองศาลองจิจูดสั้นกว่าหนึ่งองศาละติจูดราว 4%
-- ============================================================

set search_path = public, extensions;

-- ST_HexagonGrid มาใน PostGIS 3.1 (Supabase ใช้ 3.3) ถ้าไม่มีให้ล้มตรงนี้
-- พร้อมข้อความที่อ่านรู้เรื่อง ดีกว่าไปพังตอนผู้ใช้กดปุ่มบนหน้าเว็บ
do $$
begin
  if to_regprocedure('st_hexagongrid(float8, geometry)') is null then
    raise exception 'PostGIS รุ่นนี้ไม่มี ST_HexagonGrid ต้องใช้ 3.1 ขึ้นไป — ตรวจว่ารัน roadnet_1_tables.sql แล้วหรือยัง';
  end if;
end $$;

-- ============================================================
-- ความหนาแน่นอุบัติเหตุเป็นช่องหกเหลี่ยม
-- ============================================================
-- p_token  ใส่ = เจ้าหน้าที่เห็นทุกช่อง / ไม่ใส่ = ประชาชน ตัดช่องที่มีครั้งเดียวออก
-- p_edge_m ความยาวด้านของหกเหลี่ยมเป็นเมตร ไม่ใช่ความกว้างช่อง
-- ============================================================
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
  -- ช่องที่มีอุบัติเหตุครั้งเดียวชี้ตำแหน่งเหตุการณ์เดียวได้แคบเกินไปสำหรับหน้าสาธารณะ
  -- จึงกันไว้แบบเดียวกับที่สถิติสาธารณสุขกันช่องที่มีคนน้อยเกิน ไม่ใช่เพราะข้อมูลไม่ครบ
  if p_token is not null and p_token <> '' then
    v_user := officer_session_user(p_token);
  end if;
  v_min := case when v_user is null then 2 else 1 end;

  -- ด้านสั้นกว่า 80 ม. ได้ช่องหลายพันช่องจนเบราว์เซอร์วาดไม่ไหว ยาวเกิน 2 กม. ก็เหมารวมทั้งอำเภอ
  v_edge := greatest(80, least(2000, coalesce(p_edge_m, 250)));
  v_to   := coalesce(p_to, now());
  v_from := coalesce(p_from, v_to - interval '12 months');

  create temporary table if not exists tmp_geo_pt (g geometry) on commit drop;
  truncate tmp_geo_pt;

  insert into tmp_geo_pt (g)
  select st_transform(st_setsrid(st_makepoint(a.longitude, a.latitude), 4326), 32647)
  from accidents a
  where a.latitude is not null and a.longitude is not null
    and a.latitude between 14 and 17 and a.longitude between 99 and 101   -- กันพิกัดเพี้ยนที่กรอกผิด
    and a.incident_datetime >= v_from and a.incident_datetime < v_to;

  select count(*) into v_total from tmp_geo_pt;
  if v_total = 0 then
    return jsonb_build_object('success', true, 'cells', '[]'::jsonb, 'total', 0, 'shown', 0,
      'max_n', 0, 'edge_m', v_edge, 'min_per_cell', v_min,
      'period_start', v_from, 'period_end', v_to);
  end if;

  -- ขยายขอบออกหนึ่งช่อง ไม่งั้นจุดที่อยู่ริมสุดจะตกนอกตาราง
  select st_expand(st_extent(g)::geometry, v_edge * 2) into v_bounds from tmp_geo_pt;

  with cells as (
    select h.geom
    from st_hexagongrid(v_edge::float8, v_bounds) h
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
    'success', true,
    'cells', v_cells,
    'total', v_total,                 -- จุดทั้งหมดในช่วงเวลา
    'shown', v_shown,                 -- จุดที่อยู่ในช่องที่ส่งกลับ ต่างจาก total เมื่อมีการกันช่องเล็ก
    'max_n', v_max,
    'edge_m', v_edge,
    'min_per_cell', v_min,
    'period_start', v_from,
    'period_end', v_to
  );
end $$;

grant execute on function geo_density(text, timestamptz, timestamptz, int) to anon, authenticated;

-- ============================================================
-- ตรวจผลหลังรัน
-- ============================================================
-- select jsonb_build_object(
--   'ช่องที่ได้', jsonb_array_length(r->'cells'),
--   'จุดทั้งหมด', r->'total',
--   'จุดที่แสดง', r->'shown',
--   'ช่องหนาสุด',  r->'max_n')
-- from (select geo_density(null, now() - interval '12 months', now(), 250) r) q;
