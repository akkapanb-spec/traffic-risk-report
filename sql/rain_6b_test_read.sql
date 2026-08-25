-- อ่านผลของการทดลองส่ง  รันไฟล์นี้หลังรัน rain_6a_test_send.sql ราวสิบวินาที
-- ถ้ามี $0 ต่อท้ายไฟล์ ให้ลบออกก่อนกด Run
--
-- ต้องแยกเป็นคนละไฟล์ เพราะ pg_net ยิงคำขอออกไปจริงหลังทรานแซกชันปิดแล้วเท่านั้น
-- ถ้าอ่านในไฟล์เดียวกับที่ส่ง จะอ่านไม่เจอ หรือเจอผลของครั้งก่อน
--
-- อ่านเฉพาะตอนที่ข้อความไม่เข้าไลน์ เพื่อดูว่าไลน์ตอบว่าอะไร
-- ถ้าข้อความเข้าไลน์แล้ว ไม่ต้องรันไฟล์นี้

select
  to_char(x.created at time zone 'Asia/Bangkok', 'HH24:MI:SS') as เวลา,
  x.status_code                                                as รหัสตอบกลับ,
  case x.status_code
    when 200 then 'สำเร็จ ข้อความออกไปแล้ว'
    when 400 then 'รหัสปลายทางผิด หรือบอทไม่ได้อยู่ในกลุ่มนั้น'
    when 401 then 'โทเคนหมดอายุหรือผิด'
    when 403 then 'บัญชีไลน์ไม่มีสิทธิ์ส่งแบบนี้'
    when 429 then 'ส่งเกินโควตาของเดือน'
    else 'ดูข้อความดิบในช่องถัดไป'
  end                                                          as แปลว่า,
  left(coalesce(x.content, x.error_msg, ''), 200)              as ข้อความดิบ
from net._http_response x
where x.created > now() - interval '10 minutes'
order by x.created desc
limit 3;
