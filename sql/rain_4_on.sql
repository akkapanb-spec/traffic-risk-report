-- เปิดใช้งานแจ้งเตือนฝนจริง
-- ถ้ามี $0 ต่อท้ายไฟล์ ให้ลบออกก่อนกด Run
--
-- เปิดแล้วระบบจะตรวจเองทุก 15 นาที และเงียบจนกว่าฝนจะเข้ามาในวง 8 กิโลเมตร
-- รอบแยกเดชาติวงศ์เกินเกณฑ์ 15 เปอร์เซ็นต์ของพื้นที่วง
-- เมื่อถึงเกณฑ์จะส่งข้อความเดียวเข้ากลุ่ม แล้วเงียบไปจนถึงวันรุ่งขึ้น
--
-- อยากปิดกลับเมื่อไหร่ ใช้ rain_3c_off.sql

update bs_settings set val = to_jsonb(true) where key = 'rainAlertEnabled';

-- เก็บกวาดคำขอเก่าที่ค้างอยู่ กันไม่ให้ตัวเก็บผลไปอ่านของเก่าแล้วตัดสินจากภาพเมื่อวาน
update rain_probe set done = true where not done;

select 'สวิตช์แจ้งเตือนฝน' as รายการ,
       coalesce((select val #>> array[]::text[] from bs_settings where key = 'rainAlertEnabled'), '-') as ผล
union all
select 'เกณฑ์', coalesce((select val #>> array[]::text[] from bs_settings where key = 'rainMinPct'), '-')
       || ' เปอร์เซ็นต์ของวงรัศมี 8 กิโลเมตรรอบแยกเดชาติวงศ์'
union all
select 'ความถี่', 'ตรวจทุก 15 นาที ส่งได้วันละหนึ่งข้อความ'
union all
select 'คำขอค้างที่เคลียร์ทิ้ง', '0 รายการแล้ว'
union all
select 'งานตั้งเวลา',
       coalesce((select string_agg(jobname || ' = ' || schedule, '   ' order by jobname)
                 from cron.job where jobname like 'rain-%'), 'ไม่พบ');
