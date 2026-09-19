-- ============================================================
-- กิจกรรมชวนเพื่อน  ไฟล์ 13d  เช็กว่ารอบตรวจทุกนาทีทำงานจริง
-- ============================================================
-- รันได้ทุกเมื่อ ไม่เปลี่ยนอะไร
-- แสดงห้ารอบล่าสุดของงานกิจกรรม  สถานะต้องเป็น succeeded
-- ถ้าเป็น failed ช่องข้อความจะบอกสาเหตุ ส่งมาให้ดูได้
--
-- ห้ามมีปีกกาในไฟล์นี้ ตัวแก้ไขจะเติมแบ็กสแลชให้
-- ก่อนกด Run ให้ลบสิ่งที่ตัวแก้ไขเติมไว้ท้ายสุดออกก่อน เป็นดอลลาร์ตามด้วยเลขศูนย์

select j.jobname                                                            as งาน,
       to_char(d.start_time at time zone 'Asia/Bangkok', 'HH24:MI:SS')      as เวลาไทย,
       d.status                                                             as สถานะ,
       left(coalesce(d.return_message, ''), 120)                            as ข้อความ,
       (select count(*) from camp_members where checked_at is null)         as ยังไม่เคยตรวจ,
       (select to_char(max(checked_at) at time zone 'Asia/Bangkok', 'HH24:MI:SS')
          from camp_members)                                                as ตรวจล่าสุด
  from cron.job_run_details d
  join cron.job j on j.jobid = d.jobid
 where j.jobname like 'camp-%'
 order by d.start_time desc
 limit 5;

-- จบไฟล์  อย่าเคาะบรรทัดใหม่ต่อท้ายบรรทัดนี้ ->
