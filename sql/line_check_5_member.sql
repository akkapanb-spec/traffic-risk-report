-- ตรวจว่าบัญชีทางการเรียกจุดตรวจสมาชิกกลุ่มของไลน์ได้หรือไม่
-- อ่านอย่างเดียว ไม่ส่งข้อความหาใคร ไม่แก้ไขข้อมูลใด ๆ
-- ใช้ตัดสินใจว่าระบบนับกิจกรรมแจกหมวกจะตรวจแบบไหนได้
--
-- รันทั้งไฟล์รวดเดียว ผลจะขึ้นจากคำสั่งสุดท้ายคำสั่งเดียว
-- ถ้ามี $0 ต่อท้ายไฟล์ ให้ลบออกก่อนกด Run

-- คำสั่งที่ 1 ถามไลน์ว่าขอรายชื่อสมาชิกทั้งกลุ่มได้ไหม จุดนี้ไลน์จำกัดเฉพาะบัญชีที่ยืนยันแล้ว
select net.http_get(
         url := 'https://api.line.me/v2/bot/group/' || target_id || '/members/ids',
         headers := jsonb_build_object('Authorization', 'Bearer ' || line_token())
       )
from line_targets
where target_type = 'group'
limit 1;

-- คำสั่งที่ 2 ถามไลน์ว่าตรวจรายคนได้ไหม ใช้รหัสผู้ใช้สมมติที่ไม่มีอยู่จริง
-- จุดนี้คือจุดที่ระบบนับกิจกรรมจะใช้จริง
select net.http_get(
         url := 'https://api.line.me/v2/bot/group/' || target_id
                || '/member/U00000000000000000000000000000000',
         headers := jsonb_build_object('Authorization', 'Bearer ' || line_token())
       )
from line_targets
where target_type = 'group'
limit 1;

-- รอให้ pg_net ยิงออกไปและรับคำตอบกลับมาก่อน
select pg_sleep(5);

-- คำสั่งสุดท้าย แสดงผล เรียงจากคำขอล่าสุดขึ้นก่อน
-- คำขอที่ยิงทีหลังจะมีเลข id สูงกว่า จึงเป็นการตรวจรายคน
select
  case when rn = 1 then 'ตรวจรายคนว่าอยู่ในกลุ่มไหม  <-- จุดที่ระบบจะใช้จริง'
       else 'ขอรายชื่อสมาชิกทั้งกลุ่ม' end                       as จุดตรวจ,
  status_code                                                     as รหัสตอบกลับ,
  case
    when status_code = 200 then 'เรียกได้ ใช้งานได้'
    when status_code = 404 then 'เรียกได้ ไม่พบผู้ใช้รายนี้ในกลุ่ม ซึ่งถูกต้องเพราะเป็นรหัสสมมติ'
    when status_code = 403 then 'บัญชีไม่มีสิทธิ์เรียกจุดนี้ ต้องเปลี่ยนวิธีนับ'
    when status_code = 401 then 'โทเคนไม่ถูกต้องหรือหมดอายุ'
    when status_code is null then 'ยังไม่ได้คำตอบกลับ ลองรันไฟล์นี้ซ้ำอีกครั้ง'
    else 'ต้องอ่านข้อความตอบกลับประกอบ'
  end                                                             as แปลว่า,
  left(coalesce(content, coalesce(error_msg, 'ไม่มีข้อความ')), 200) as ข้อความตอบกลับ
from (
  select row_number() over (order by id desc) as rn,
         status_code, content, error_msg
  from net._http_response
  order by id desc
  limit 2
) t
order by rn;
