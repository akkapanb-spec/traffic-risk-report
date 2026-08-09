-- ============================================================
-- รายชื่อถนนแบบย่อ ไว้ให้ทุกหน้าเรียกใช้
-- ============================================================
-- ต้องรัน roadnet_1_tables.sql มาก่อน
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
--
-- ทำไมต้องมีตัวนี้ ทั้งที่มี rn_admin_data อยู่แล้ว
--   rn_admin_data ต้องเป็นแอดมิน และคืนแนวเส้นของถนนทุกสายมาด้วย
--   ซึ่งหนักเกินไปสำหรับงานที่ต้องการแค่ "ถนนสายนี้ชื่ออะไร รหัสอะไร"
--   เช่นเติมตัวเลือกในช่องถนน หรือค้นหาด้วยรหัสทางหลวง
--
--   ผลที่ตามมาของการไม่มีตัวนี้: หน้าจุดตรวจกับหน้าสถานที่เรียก
--   rnFillRoadSelects() ซึ่งอ่านรายชื่อถนนที่โหลดไว้ตอนเปิดหน้าโครงข่ายถนน
--   ถ้าเข้าหน้าจุดตรวจตรง ๆ โดยไม่แวะหน้าโครงข่ายก่อน ช่องถนนจะว่างเปล่า
--
-- เปิดให้เรียกโดยไม่ต้องล็อกอิน ด้วยเหตุผลเดียวกับ rn_locate_public
--   ชื่อถนนกับหมายเลขทางหลวงเป็นข้อมูลสาธารณะ ไม่มีข้อมูลอุบัติเหตุหรือบุคคล
-- ============================================================

set search_path = public, extensions;

create or replace function rn_road_index()
returns jsonb
language sql stable security definer set search_path = public, extensions as $$
  select jsonb_build_object('success', true,
    'roads', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', r.id, 'name', r.name, 'code', r.code,
               'subdistrict', r.subdistrict, 'local_authority', r.local_authority,
               'in_municipality', r.in_municipality, 'highway_type', r.highway_type)
             order by r.name)
      from rn_roads r), '[]'::jsonb));
$$;

grant execute on function rn_road_index() to anon, authenticated;

-- ============================================================
-- ตรวจผลหลังรัน
-- ============================================================
-- ต้องเห็นถนนพร้อมรหัส เช่น ถนนพหลโยธิน คู่กับ ทล.1
-- select jsonb_pretty(rn_road_index());
