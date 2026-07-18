-- เพิ่มคอลัมน์วันบันทึกข้อมูลใน view สาธารณะ (ใช้นับสถิติหน้าแรกแบบเดียวกับระบบเดิม)
-- ไม่เปิดเผยข้อมูลส่วนบุคคลใดๆ — มีแค่ id กับวันเวลา 2 ช่อง
create or replace view accidents_public as
  select id, incident_datetime, recorded_at from accidents;
grant select on accidents_public to anon;
