-- ใส่รหัสกลุ่มที่ได้จากการพิมพ์ #id ในกลุ่ม
-- รันเมื่อไหร่ก็ได้ ไม่ต้องรอ camp_3
-- ถ้ามี $0 ต่อท้ายไฟล์ ให้ลบออกก่อนกด Run
--
-- รหัสนี้ได้มาจากบันทึก webhook เมื่อ 21/08 เวลา 13:05 น.
-- เป็นกลุ่มเดียวกับที่ลงทะเบียนไว้ใน line_targets อยู่แล้ว

update bs_settings
   set val = to_jsonb('C81363b18be5a1b0fcf5cd4d7d868e782'::text)
 where key = 'campGroupId';

-- ปิดคีย์เวิร์ด id กลับ ได้รหัสกลุ่มมาแล้วจึงไม่ต้องเปิดค้างไว้
-- ถ้าวันหน้าต้องหารหัสห้องอีก เปิดใหม่ด้วยคำสั่ง
--   update line_keywords set enabled = true where action = 'id';

update line_keywords set enabled = false where action = 'id';

-- ตรวจผล  คำสั่งสุดท้ายคำสั่งเดียวที่จะแสดงผล
select 'รหัสกลุ่มที่ตั้งไว้' as รายการ,
       camp_cfg('campGroupId', 'ยังว่าง') as ผล
union all
select 'ตรงกับกลุ่มที่รับแจ้งเตือนอยู่ไหม',
       coalesce((select case when target_id = camp_cfg('campGroupId', '')
                             then 'ตรงกัน เป็นกลุ่มเดียวกัน' else 'คนละกลุ่ม' end
                 from line_targets where target_type = 'group' limit 1), 'ไม่พบกลุ่ม')
union all
select 'กลุ่มนี้รับข่าวผู้เสียชีวิตอัตโนมัติอยู่หรือไม่',
       coalesce((select case when want_death then 'รับอยู่' else 'ไม่รับ' end
                 from line_targets where target_type = 'group' limit 1), '-')
union all
select 'คีย์เวิร์ด id',
       coalesce((select string_agg(keyword || ' = ' || enabled::text, ', ')
                 from line_keywords where action = 'id'), 'ไม่พบ');
