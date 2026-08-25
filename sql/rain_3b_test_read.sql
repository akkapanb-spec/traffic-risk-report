-- ทดสอบทั้งสาย ขั้นที่ 2 จาก 2
-- รันหลัง rain_3a_test_fire.sql ไปแล้วราว 20 วินาที
-- ถ้ามี $0 ต่อท้ายไฟล์ ให้ลบออกก่อนกด Run
--
-- ถ้าผลขึ้นว่า ฝนยังไม่ถึงเกณฑ์ แปลว่าทั้งสายทำงานถูกต้อง
-- คือฐานข้อมูลยิงออกไปได้ ตัวอ่านเรดาร์ตอบกลับมาได้ และแปลคำตอบได้
--
-- ถ้าขึ้นว่า ยังไม่มีคำตอบให้อ่าน ให้รออีกสิบวินาทีแล้วรันไฟล์นี้ซ้ำ
-- ถ้าขึ้นว่า อ่านเรดาร์ไม่สำเร็จ ให้ส่งผลมาให้ดู

select rain_alert_collect();

select 'ผลการตัดสินใจ' as รายการ, rain_alert_collect()::text as ผล
union all
select 'สวิตช์ตอนนี้',
       coalesce((select val #>> array[]::text[] from bs_settings where key = 'rainAlertEnabled'), '-')
       || '   ถ้าอยากปิดกลับ ใช้ rain_3c_off.sql'
union all
select 'คำขอที่ยังไม่ได้อ่าน',
       (select count(*)::text from rain_probe where not done) || ' รายการ'
union all
select 'เคยส่งข้อความฝนไปแล้วกี่ครั้ง',
       (select count(*)::text from line_sent where kind = 'rain') || ' ครั้ง';
