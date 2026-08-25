-- ถามไลน์ว่าโควตาข้อความเดือนนี้เหลือเท่าไร
-- ถ้ามี $0 ต่อท้าย ให้ลบก่อนกด Run
--
-- การถามโควตาไม่นับเป็นการส่งข้อความ ถามกี่ครั้งก็ไม่กินโควตา
-- ใช้โทเคนที่เก็บอยู่ในฐานข้อมูลแล้ว ไม่ต้องไปคัดลอกโทเคนมาจากที่ไหน
--
-- ต้องแยกยิงกับอ่านเป็นคนละไฟล์ เพราะคำขอออกไปจริงหลังทรานแซกชันปิดเท่านั้น
-- รันไฟล์นี้ก่อน รอสิบวินาที แล้วรัน line_quota_2_read.sql

select
  net.http_get(
    url     := 'https://api.line.me/v2/bot/message/quota',
    headers := jsonb_build_object('Authorization', 'Bearer ' || line_token())
  ) as ถามโควตาทั้งเดือน,
  net.http_get(
    url     := 'https://api.line.me/v2/bot/message/quota/consumption',
    headers := jsonb_build_object('Authorization', 'Bearer ' || line_token())
  ) as ถามยอดที่ใช้ไปแล้ว;
