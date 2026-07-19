-- ============================================================
-- ลบบันทึกอุบัติเหตุที่เจ้าหน้าที่กดบันทึกซ้ำในระบบเดิม (5 แถว)
-- เก็บแถวแรกของแต่ละกลุ่มไว้ · ลบเฉพาะที่เนื้อหาเหมือนกันทุกช่องเท่านั้น
-- ============================================================

-- 1) เนื้อหาเหมือนกันทั้งหมด (เวลาเกิดเหตุ สถานที่ คู่กรณีทั้งสองฝ่าย ถนน สาเหตุ)
delete from accidents a
 using accidents b
 where a.id > b.id
   and a.incident_datetime = b.incident_datetime
   and coalesce(a.place,'')  = coalesce(b.place,'')
   and coalesce(a.party1::text,'') = coalesce(b.party1::text,'')
   and coalesce(a.party2::text,'') = coalesce(b.party2::text,'')
   and coalesce(a.road,'')   = coalesce(b.road,'')
   and coalesce(a.cause,'')  = coalesce(b.cause,'');

-- 2) รหัสเคสเดียวกัน + เวลาเกิดเหตุเดียวกัน (กดบันทึกซ้ำจนได้รหัสเดิม)
delete from accidents a
 using accidents b
 where a.id > b.id
   and a.accident_code is not null
   and a.accident_code = b.accident_code
   and a.incident_datetime = b.incident_datetime;
