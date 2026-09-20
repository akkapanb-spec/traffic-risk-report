-- ============================================================
-- เตือนฝน  ไฟล์ 16  ดูสถานะก่อนปรับโควตา
-- ============================================================
-- รันได้ทุกเมื่อ ไม่เปลี่ยนอะไร ไม่ส่งข้อความ
--
-- ตอบสามคำถาม
--   เปิดใช้อยู่ไหม
--   โควตาตอนนี้ตั้งไว้เท่าไร และเกณฑ์ความแรงของฝนเป็นเท่าไร
--   สิบครั้งหลังสุดส่งเมื่อไร และเป็นช่องไหน
--
-- อ่านรหัสอ้างอิงในคอลัมน์สุดท้าย
--   ขึ้นต้นด้วย rush   คือช่องชั่วโมงเร่งด่วน จันทร์ถึงศุกร์ เช้าหรือเย็นช่วงละหนึ่งครั้งต่อวัน
--   ขึ้นต้นด้วย ep     คือช่องนอกชั่วโมงเร่งด่วน วันละ rainFreeMaxPerDay ครั้ง
--
-- ห้ามมีปีกกาในไฟล์นี้ ตัวแก้ไขจะเติมแบ็กสแลชให้
-- ก่อนกด Run ให้ลบสิ่งที่ตัวแก้ไขเติมไว้ท้ายสุดออกก่อน เป็นดอลลาร์ตามด้วยเลขศูนย์

select
  (select val from bs_settings where key = 'rainAlertEnabled')              as เปิดใช้งาน,
  (select val from bs_settings where key = 'rainFreeMaxPerDay')             as โควตานอกเร่งด่วนต่อวัน,
  (select val from bs_settings where key = 'rainMinPct')                    as เกณฑ์ฝนต่ำสุด,
  (select val from bs_settings where key = 'rainYolkMinPct')                as เกณฑ์ฝนหนัก,
  (select string_agg(jobname || ' ' || schedule, '  |  ' order by jobname)
     from cron.job where jobname like 'rain-%')                             as งานตามเวลา,
  (select count(*) from line_sent
    where kind = 'rain'
      and sent_at >= date_trunc('day', now() at time zone 'Asia/Bangkok')
                     at time zone 'Asia/Bangkok')                           as ส่งไปแล้ววันนี้,
  (select string_agg(x.t, chr(10) order by x.t desc) from (
     select to_char(s.sent_at at time zone 'Asia/Bangkok', 'DD/MM HH24:MI')
            || '  ' || coalesce(s.ref_id, '') as t
       from line_sent s
      where s.kind = 'rain'
      order by s.sent_at desc
      limit 10) x)                                                          as สิบครั้งหลังสุด;

-- จบไฟล์  อย่าเคาะบรรทัดใหม่ต่อท้ายบรรทัดนี้ ->
