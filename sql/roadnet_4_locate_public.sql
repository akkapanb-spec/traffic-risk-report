-- ============================================================
-- หาข้อมูลถนนจากพิกัด สำหรับเติมช่องในฟอร์มอัตโนมัติ
-- ============================================================
-- ต้องรัน roadnet_1_tables.sql และ roadnet_2_rpc.sql มาก่อน
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
--
-- ทำไมต้องมีตัวใหม่ ทั้งที่มี rn_locate อยู่แล้ว
--   rn_locate ต้องใช้ token ของเจ้าหน้าที่ และคืนแค่ชื่อถนนกับระยะ
--   แต่หน้าแจ้งจุดเสี่ยงของประชาชนไม่มี token และฟอร์มต่าง ๆ ยังต้องการ
--   ตำบล อปท. และธงในเขตเทศบาล ซึ่ง rn_roads เก็บไว้อยู่แล้วในแถวเดียวกัน
--
-- เปิดให้เรียกโดยไม่ต้องล็อกอินได้ เพราะคืนแค่ข้อมูลถนนสาธารณะ
--   ชื่อถนน รหัสทางหลวง ตำบล อปท. — ไม่มีข้อมูลอุบัติเหตุหรือข้อมูลบุคคลใด ๆ
--
-- ระยะสูงสุด 120 ม. ถ้าไกลกว่านั้นถือว่าไม่ได้อยู่บนถนนสายที่วาดไว้
--   เดาให้แล้วผิดจะแย่กว่าไม่เดา เพราะคนกรอกจะเชื่อค่าที่ระบบเติมให้
-- ============================================================

set search_path = public, extensions;

create or replace function rn_locate_public(p_lat float8, p_lng float8, p_max_m int default 120)
returns jsonb
language plpgsql stable security definer set search_path = public, extensions as $$
declare
  v_pt geography;
  v_max int := greatest(10, least(1000, coalesce(p_max_m, 120)));
  v_road record;
begin
  if p_lat is null or p_lng is null then
    return jsonb_build_object('success', false, 'message', 'ไม่ได้ส่งพิกัดมา');
  end if;

  v_pt := st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography;

  select r.id, r.name, r.code, r.subdistrict, r.local_authority, r.in_municipality,
         round(st_distance(r.center_line, v_pt))::int as dist_m,
         round(st_length(
           st_linesubstring(r.center_line::geometry, 0,
             st_linelocatepoint(r.center_line::geometry, v_pt::geometry))::geography))::int as offset_m
    into v_road
  from rn_roads r
  where r.center_line is not null
    and st_dwithin(r.center_line, v_pt, v_max)
  order by st_distance(r.center_line, v_pt)
  limit 1;

  if v_road.id is null then
    return jsonb_build_object('success', true, 'found', false);
  end if;

  return jsonb_build_object('success', true, 'found', true,
    'road_id', v_road.id, 'road_name', v_road.name, 'road_code', v_road.code,
    'subdistrict', v_road.subdistrict, 'local_authority', v_road.local_authority,
    'in_municipality', v_road.in_municipality,
    'dist_m', v_road.dist_m, 'offset_m', v_road.offset_m);
end $$;

grant execute on function rn_locate_public(float8, float8, int) to anon, authenticated;

-- ============================================================
-- ตรวจผลหลังรัน
-- ============================================================
-- select jsonb_pretty(rn_locate_public(15.7051, 100.1372));   -- กลางเมือง ควรเจอถนน
-- select jsonb_pretty(rn_locate_public(15.0, 100.0));         -- ไกลมาก ควรได้ found=false
