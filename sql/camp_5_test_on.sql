-- เปิดกิจกรรมชั่วคราวเพื่อทดสอบ
-- ถ้ามี $0 ต่อท้ายไฟล์ ให้ลบออกก่อนกด Run
--
-- นี่คือการทดสอบเดียวที่พิสูจน์ได้จริงว่า Edge Function ตัวใหม่ทำงาน
-- เพราะถ้ามีแถวใน camp_members โผล่ขึ้นมาหลังทักบอท แปลว่า
--   1 Edge Function เรียกฐานข้อมูลได้จริง
--   2 มันส่ง p_user_id มาด้วยจริง
-- สองอย่างนี้ตัวตรวจสุขภาพบอกไม่ได้ เพราะมันวัดจากคีย์เวิร์ดที่ปิดอยู่
--
-- ปิดกลับเมื่อทดสอบเสร็จด้วย camp_5_test_off.sql

update bs_settings set val = to_jsonb(true) where key = 'campEnabled';

-- ตรวจผล  คำสั่งสุดท้ายคำสั่งเดียวที่จะแสดงผล
select 'สวิตช์กิจกรรม' as รายการ, camp_cfg('campEnabled', 'ไม่พบ') as ผล
union all
select 'รหัสกลุ่ม', case when camp_cfg('campGroupId','') = '' then 'ยังว่าง' else 'ตั้งแล้ว' end
union all
select 'ผู้เข้าร่วมตอนนี้', (select count(*)::text from camp_members) || ' คน'
union all
select 'ต่อไปทำอะไร',
       'ทักบอทในแชทส่วนตัวว่า  กิจกรรม  แล้วดูว่าได้รหัส 6 ตัวกลับมาไหม';
