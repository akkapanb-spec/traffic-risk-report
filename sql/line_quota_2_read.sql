-- อ่านคำตอบจากไลน์  รันหลังไฟล์ที่ยิงคำถามราวสิบวินาที
-- ถ้ามี $0 ต่อท้าย ให้ลบก่อนกด Run
--
-- วงเล็บครอบเงื่อนไขทั้งชุดไว้ตั้งใจ
-- ถ้าไม่ครอบ เงื่อนไขเวลาจะผูกกับบรรทัดแรกบรรทัดเดียว แล้วจะดึงของเก่ามาปนด้วย

select
  to_char(x.created at time zone 'Asia/Bangkok', 'HH24:MI:SS') as เวลา,
  x.status_code                                                as รหัสตอบ,
  coalesce(x.content, x.error_msg, '')                         as คำตอบจากไลน์
from net._http_response x
where x.created > now() - interval '10 minutes'
  and (
        coalesce(x.content, '') like '%totalUsage%'
     or coalesce(x.content, '') like '%"value"%'
     or coalesce(x.content, '') like '%count%'
      )
order by x.created desc
limit 6;
