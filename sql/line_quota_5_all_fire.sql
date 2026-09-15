-- ถามไลน์สามอย่างในไฟล์เดียว  โควตาทั้งเดือน  ยอดที่ใช้ไปแล้ว  และจำนวนคนในกลุ่ม
-- รันไฟล์นี้ รอสิบวินาที แล้วรัน line_quota_2_read.sql
--
-- ทั้งสามอย่างเป็นการอ่านข้อมูล ไม่ใช่การส่งข้อความ ถามกี่ครั้งก็ไม่กินโควตา
-- ใช้โทเคนที่เก็บอยู่ในฐานข้อมูลแล้ว ไม่ต้องคัดลอกโทเคนมาจากที่ไหน
--
-- ต้องรู้จำนวนคนในกลุ่มด้วย เพราะไลน์นับตามจำนวนคนที่ได้รับ ไม่ใช่ตามจำนวนข้อความ
-- ส่งเข้ากลุ่มหนึ่งครั้ง จึงกินโควตาเท่ากับจำนวนคนในกลุ่ม
-- เอาโควตาที่เหลือหารด้วยจำนวนคนในกลุ่ม ก็คือจำนวนครั้งที่ยังแจ้งเตือนเข้ากลุ่มได้อีก
--
-- ต้องแยกยิงกับอ่านเป็นคนละไฟล์ เพราะคำขอออกไปจริงหลังทรานแซกชันปิดเท่านั้น

select
  net.http_get(
    url     := 'https://api.line.me/v2/bot/message/quota',
    headers := jsonb_build_object('Authorization', 'Bearer ' || line_token())
  ) as ถามโควตาทั้งเดือน,
  net.http_get(
    url     := 'https://api.line.me/v2/bot/message/quota/consumption',
    headers := jsonb_build_object('Authorization', 'Bearer ' || line_token())
  ) as ถามยอดที่ใช้ไปแล้ว,
  net.http_get(
    url     := 'https://api.line.me/v2/bot/group/C81363b18be5a1b0fcf5cd4d7d868e782/members/count',
    headers := jsonb_build_object('Authorization', 'Bearer ' || line_token())
  ) as ถามจำนวนคนในกลุ่ม;
