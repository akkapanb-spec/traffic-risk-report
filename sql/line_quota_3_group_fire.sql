-- ถามไลน์ว่ากลุ่มมีสมาชิกกี่คน  และยอดใช้โควตาล่าสุด
-- ถ้ามี $0 ต่อท้าย ให้ลบก่อนกด Run
--
-- ทั้งสองอย่างเป็นการอ่านข้อมูล ไม่ใช่การส่งข้อความ จึงไม่กินโควตา
--
-- ต้องรู้จำนวนสมาชิก เพราะไลน์นับค่าส่งตามจำนวนคนที่ได้รับ ไม่ใช่ตามจำนวนข้อความ
-- ส่งเข้ากลุ่มหนึ่งครั้ง จึงเท่ากับส่งเท่าจำนวนคนในกลุ่ม
-- ตัวเลขนี้เป็นตัวชี้ว่าเดือนหนึ่งเราแจ้งเตือนได้กี่ครั้งจริง ๆ
--
-- รันไฟล์นี้ รอสิบวินาที แล้วรัน line_quota_2_read.sql

select
  net.http_get(
    url     := 'https://api.line.me/v2/bot/group/C81363b18be5a1b0fcf5cd4d7d868e782/members/count',
    headers := jsonb_build_object('Authorization', 'Bearer ' || line_token())
  ) as ถามจำนวนสมาชิกในกลุ่ม,
  net.http_get(
    url     := 'https://api.line.me/v2/bot/message/quota/consumption',
    headers := jsonb_build_object('Authorization', 'Bearer ' || line_token())
  ) as ถามยอดที่ใช้ไปแล้ว;
