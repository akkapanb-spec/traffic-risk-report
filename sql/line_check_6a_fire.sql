-- ขั้นที่ 1 จาก 2  ยิงคำขอทดสอบออกไปยังไลน์
-- อ่านอย่างเดียว ไม่ส่งข้อความหาใคร ไม่แก้ไขข้อมูลใด ๆ
--
-- ต้องแยกเป็นสองไฟล์ เพราะ SQL Editor ครอบทั้งไฟล์เป็นทรานแซกชันเดียว
-- pg_net จะยิงคำขอออกไปหลังจบทรานแซกชันเท่านั้น
-- ถ้ายิงแล้วอ่านในไฟล์เดียวกัน จะอ่านได้แต่คำตอบเก่าของงานอื่น
--
-- รันไฟล์นี้ก่อน แล้วรอสักครู่ จากนั้นค่อยรัน line_check_6b_read.sql
-- ถ้ามี $0 ต่อท้ายไฟล์ ให้ลบออกก่อนกด Run

select
  net.http_get(
    url := 'https://api.line.me/v2/bot/group/' || target_id || '/members/ids',
    headers := jsonb_build_object('Authorization', 'Bearer ' || line_token())
  ) as คำขอที่1_ขอรายชื่อทั้งกลุ่ม,
  net.http_get(
    url := 'https://api.line.me/v2/bot/group/' || target_id
           || '/member/U00000000000000000000000000000000',
    headers := jsonb_build_object('Authorization', 'Bearer ' || line_token())
  ) as คำขอที่2_ตรวจรายคน,
  label as กลุ่มที่ทดสอบ
from line_targets
where target_type = 'group'
limit 1;
