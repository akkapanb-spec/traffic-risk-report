-- ถามโควตาใหม่หลังอัปเกรดแพ็กเกจ
-- ถ้ามี $0 ต่อท้าย ให้ลบก่อนกด Run
-- รันไฟล์นี้ รอสิบวินาที แล้วรัน line_quota_2_read.sql

select
  net.http_get(
    url     := 'https://api.line.me/v2/bot/message/quota',
    headers := jsonb_build_object('Authorization', 'Bearer ' || line_token())
  ) as ถามโควตาใหม่,
  net.http_get(
    url     := 'https://api.line.me/v2/bot/message/quota/consumption',
    headers := jsonb_build_object('Authorization', 'Bearer ' || line_token())
  ) as ถามยอดที่ใช้ไปแล้ว;
