-- ตั้งรัศมีจับกลุ่มจุดเสี่ยงซ้ำเป็น 100 เมตร
-- ถ้ามีอักขระแปลกปลอมต่อท้ายบรรทัดสุดท้าย ให้ลบออกก่อนกด Run
--
-- ทำไมเป็น 100
--   เท่ากับความกว้างช่องตารางเดิมพอดี จึงเทียบกับของเก่าได้ตรง ๆ
--   วัดจริงเมื่อ 26 ส.ค. 2569 ด้วยข้อมูล 30 วัน
--     100 เมตร  ได้ 7 จุด  กลุ่มยาวสุด 183 เมตร
--     120 เมตร  ได้ 8 จุด  กลุ่มยาวสุด 246 เมตร
--     150 เมตร  ได้ 9 จุด  กลุ่มยาวสุด 423 เมตร  เริ่มลามเกินจุดเดียว
--   ต่างกันจุดเดียว แต่ 100 ให้กลุ่มกระชับกว่ามาก
--
-- ค่านี้ถูกใช้สองที่ และขยับตามกันเอง
--   รัศมีจับกลุ่มของ line_send_hotspots
--   ระยะกรองก่อนถาม Longdo ซึ่งเป็นค่านี้คูณ 1.25 เท่ากับ 125 เมตร

update bs_settings set val = to_jsonb(100) where key = 'hotspotClusterMetres';

insert into bs_settings (key, val)
select 'hotspotClusterMetres', to_jsonb(100)
where not exists (select 1 from bs_settings where key = 'hotspotClusterMetres');

-- ==========================================================
-- ตรวจผล  คำสั่งสุดท้ายคำสั่งเดียวที่จะแสดงผล
-- ==========================================================

select 'รัศมีจับกลุ่ม' as รายการ,
       coalesce((select (val #>> array[]::text[]) || ' เมตร' from bs_settings
                 where key = 'hotspotClusterMetres'), 'ไม่พบ') as ค่า
union all
select 'ระยะกรองก่อนถาม Longdo',
       coalesce((select ((val #>> array[]::text[])::numeric * 1.25)::text || ' เมตร'
                 from bs_settings where key = 'hotspotClusterMetres'), '-')
union all
select 'ขั้นต่อไป', 'ลาก line_hotspot_11_node.sql แล้วส่งผลมาให้ดู';
