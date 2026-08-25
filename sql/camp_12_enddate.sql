-- เลื่อนวันสิ้นสุดกิจกรรมเป็น 30 ก.ย. 2569
-- รันเมื่อไหร่ก็ได้ ไม่กระทบข้อมูลผู้เข้าร่วมหรือสิทธิ์ที่ให้ไปแล้ว
-- ถ้ามี $0 ต่อท้ายไฟล์ ให้ลบออกก่อนกด Run
--
-- ข้อควรรู้
--   ชื่อรอบที่ใช้เก็บสิทธิ์คือ วันเริ่ม..วันจบ  การเปลี่ยนวันจบจึงเปลี่ยนชื่อรอบไปด้วย
--   ถ้ามีสิทธิ์ที่ให้ไปแล้วในรอบเดิม ต้องย้ายมาที่ชื่อรอบใหม่ ไม่งั้นระบบจะนับโควตาใหม่
--   แล้วแจกเกิน 100 ใบโดยไม่มีใครรู้
--   ตอนนี้ยังไม่มีใครได้สิทธิ์ แต่เขียนเผื่อไว้ให้ทำงานถูกต้องแม้จะมี

update camp_claims
   set period = camp_cfg('campStartDate', '') || '..' || '2026-09-30'
 where period = camp_period();

update bs_settings
   set val = to_jsonb('2026-09-30'::text)
 where key = 'campEndDate';

-- ตรวจผล  คำสั่งสุดท้ายคำสั่งเดียวที่จะแสดงผล
select 'ช่วงกิจกรรม' as รายการ,
       camp_thai_date(camp_cfg('campStartDate','')::date) || ' ถึง ' ||
       camp_thai_date(camp_cfg('campEndDate','')::date) as ผล
union all
select 'เหลืออีกกี่วัน', (camp_cfg('campEndDate','')::date - camp_today())::text || ' วัน'
union all
select 'เปิดรับอยู่ไหม', case when camp_open() then 'เปิดรับอยู่' else 'ปิด' end
union all
select 'ชื่อรอบที่ใช้เก็บสิทธิ์', camp_period()
union all
select 'สิทธิ์ที่อยู่ในรอบปัจจุบัน',
       (select count(*)::text from camp_claims where period = camp_period()) || ' ราย'
union all
select 'สิทธิ์ที่ตกค้างอยู่รอบอื่น ต้องเป็น 0',
       (select count(*)::text from camp_claims where period <> camp_period()) || ' ราย';
