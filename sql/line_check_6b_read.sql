-- ขั้นที่ 2 จาก 2  อ่านคำตอบที่ไลน์ส่งกลับมา
-- รันไฟล์นี้หลังรัน line_check_6a_fire.sql ไปแล้วสักครู่หนึ่ง
-- ถ้ายังไม่เห็นคำตอบของการทดสอบ ให้รอสิบวินาทีแล้วรันไฟล์นี้ซ้ำ
-- ถ้ามี $0 ต่อท้ายไฟล์ ให้ลบออกก่อนกด Run

select
  case
    when content like '%memberIds%'     then 'ขอรายชื่อสมาชิกทั้งกลุ่ม'
    when content like '%displayName%'   then 'ตรวจรายคน  <-- จุดที่ระบบจะใช้จริง'
    when content like '%Not found%'     then 'ตรวจรายคน  <-- จุดที่ระบบจะใช้จริง'
    when content like '%sentMessages%'  then 'ไม่เกี่ยวกับการทดสอบ เป็นการส่งข้อความของงานตั้งเวลา'
    else 'อื่น ๆ'
  end                                                               as จุดตรวจ,
  status_code                                                       as รหัสตอบกลับ,
  case
    when content like '%sentMessages%'                 then 'ข้ามได้ ไม่เกี่ยวกับการทดสอบ'
    when status_code = 200                             then 'เรียกได้ ใช้งานได้'
    when status_code = 404                             then 'เรียกได้ตามปกติ ไม่พบรหัสสมมติในกลุ่ม ซึ่งถูกต้อง'
    when status_code = 403                             then 'บัญชีไม่มีสิทธิ์เรียกจุดนี้ ต้องเปลี่ยนวิธีนับ'
    when status_code = 401                             then 'โทเคนไม่ถูกต้องหรือหมดอายุ'
    else 'ต้องอ่านข้อความตอบกลับประกอบ'
  end                                                               as แปลว่า,
  left(coalesce(content, coalesce(error_msg, 'ไม่มีข้อความ')), 150)  as ข้อความตอบกลับ,
  created                                                           as เวลาที่ได้คำตอบ
from net._http_response
order by id desc
limit 5;
