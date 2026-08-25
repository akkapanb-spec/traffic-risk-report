-- ปิดกิจกรรมกลับหลังทดสอบเสร็จ
-- ถ้ามี $0 ต่อท้ายไฟล์ ให้ลบออกก่อนกด Run
--
-- ปิดแล้วบอทจะกลับไปเงียบสนิทเหมือนเดิม
-- ข้อมูลผู้เข้าร่วมและรหัสที่ออกไปแล้วยังอยู่ครบ ไม่ได้ถูกลบ
-- เปิดใหม่เมื่อไหร่ก็นับต่อจากเดิมได้

update bs_settings set val = to_jsonb(false) where key = 'campEnabled';

-- ตรวจผล  คำสั่งสุดท้ายคำสั่งเดียวที่จะแสดงผล
select 'สวิตช์กิจกรรม' as รายการ, camp_cfg('campEnabled', 'ไม่พบ') as ผล
union all
select 'ผู้เข้าร่วมที่บันทึกไว้', (select count(*)::text from camp_members) || ' คน  (ยังอยู่ครบ ไม่ได้ลบ)'
union all
select 'สิทธิ์ที่ให้ไปแล้ว', (select count(*)::text from camp_claims) || ' รายการ';
