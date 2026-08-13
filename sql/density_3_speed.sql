-- ============================================================
-- ความหนาแน่นอุบัติเหตุ — ทำให้ช่องเล็กใช้งานได้จริง
-- ============================================================
-- ต้องรัน density_1_rpc.sql มาก่อน  ไฟล์นี้เขียนทับ geo_density ตัวเดิม
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
--
-- ปัญหาที่เจอ
--   geo_density บีบค่าด้านต่ำสุดไว้ที่ 80 ม. แต่พอเรียกด้วย 80 หรือ 87 จริง ๆ
--   กลับได้ "canceling statement due to statement timeout" ทุกครั้ง
--   แปลว่าขอบล่างที่เขียนไว้ในโค้ดใช้ไม่ได้มาตั้งแต่ต้น — ค่าที่ระบบยอมรับ
--   กับค่าที่ระบบทำไหว ไม่ใช่ช่วงเดียวกัน  วัดจริงที่ด้าน 144 ม. ใช้ 1.3 วิ
--   ด้าน 116 ม. ใช้ 1.9 วิ ด้าน 100 ม. ใช้ 2.4 วิ แล้วพังที่ 87 ม.
--
-- ทำไมถึงช้าแบบทวีคูณ
--   ท่าเดิมคือสร้างตารางหกเหลี่ยมคลุมกรอบทั้งอำเภอก่อน แล้วค่อยเอาไป join
--   กับจุดอุบัติเหตุด้วย st_intersects โดยไม่มี index อยู่เลยสักฝั่ง
--   ทุกช่องจึงต้องไล่เทียบกับทุกจุด  จำนวนช่องโตแบบผกผันกับด้านยกกำลังสอง
--   ลดด้านครึ่งหนึ่ง = ช่องเพิ่มสี่เท่า = งานเพิ่มสี่เท่า
--
-- ทางแก้: ใส่ index ให้ตารางจุดชั่วคราว
--   จุดมีแค่หลักพัน สร้าง index ครั้งเดียวถูกมาก
--   จากนั้นแต่ละช่องแค่ถามผ่าน index ว่ามีจุดไหนอยู่ในกรอบตัวเองบ้าง
--   ไม่ต้องไล่ทีละจุดอีก
--   analyze ด้วย เพราะตารางชั่วคราวเพิ่งสร้าง ยังไม่มีสถิติให้ตัวเลือกแผนใช้
--   ถ้าไม่ทำ planner จะเดาว่าตารางว่างแล้วเลือกไล่เทียบทีละแถวเหมือนเดิม
--
-- แล้วค่อยลดขอบล่างจาก 80 เหลือ 55 ม. (ช่องกว้างราว 95 ม.)
--   เพื่อให้หน้าเจ้าหน้าที่เลือก "ช่องกว้าง 100 ม." ได้จริง
--   ไม่ลดต่ำกว่านี้ เพราะกรอบทั้งอำเภอจะแตกเป็นแสนช่องและเริ่มไม่คุ้ม
-- ============================================================

set search_path = public, extensions;

create or replace function geo_density(
  p_token  text        default null,
  p_from   timestamptz default null,
  p_to     timestamptz default null,
  p_edge_m int         default 250
) returns jsonb
language plpgsql security definer set search_path = public, extensions as $geo_density$
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

  -- ขอบล่าง 55 ม. = ช่องกว้างราว 95 ม. ต่ำกว่านี้กรอบทั้งอำเภอแตกเป็นแสนช่อง
  -- ขอบบน 2 กม. ขึ้นไปก็เหมารวมทั้งอำเภอจนไม่เหลือความต่างให้ดู
  v_edge := greatest(55, least(2000, coalesce(p_edge_m, 250)));
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

  -- หัวใจของการแก้รอบนี้ — ไม่มีสองบรรทัดนี้ ช่องเล็กจะ timeout เหมือนเดิม
  create index if not exists tmp_geo_pt_gix on tmp_geo_pt using gist (g);
  analyze tmp_geo_pt;

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
    'edge_m', v_edge,                 -- ด้านที่ใช้จริงหลังบีบค่า หน้าเว็บต้องอ่านค่านี้ไปทำป้าย
    'min_per_cell', v_min,
    'period_start', v_from,
    'period_end', v_to
  );
end $geo_density$;

grant execute on function geo_density(text, timestamptz, timestamptz, int) to anon, authenticated;

-- ============================================================
-- ตรวจผลหลังรัน
-- ============================================================
-- ค่าที่เคย timeout ต้องผ่านหมดแล้ว และควรเร็วกว่าเดิมทุกขนาด
--
-- select r->>'edge_m' as ด้าน, jsonb_array_length(r->'cells') as ช่อง, r->>'max_n' as หนาสุด
-- from (select geo_density(null, '2026-01-01', now(), 58) r) q;
--
-- ทีละขนาดพร้อมเวลา (เปิด Timing ใน SQL Editor หรือดูที่ผลลัพธ์ด้านล่าง)
-- select e as ด้าน,
--        jsonb_array_length(geo_density(null, '2026-01-01', now(), e)->'cells') as ช่อง
-- from unnest(array[58, 87, 116, 144, 289, 578]) e;
--
-- ค่าด้าน 58 ม. คือช่องกว้างราว 100 ม. — เดิมพังตรงนี้
