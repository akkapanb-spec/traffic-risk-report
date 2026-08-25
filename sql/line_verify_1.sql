-- ตรวจว่าข้อความที่สั่งส่งไปแล้ว ไลน์รับจริงหรือไม่
-- ถ้ามี $0 ต่อท้ายไฟล์ ให้ลบออกก่อนกด Run
--
-- ปัญหาที่ไฟล์นี้แก้
--   การส่งข้อความเป็นแบบยิงแล้วไม่รอคำตอบ ตอนบันทึกจึงยังไม่รู้ผล
--   ระบบเดิมบันทึกว่าส่งแล้วทันที ไม่ว่าไลน์จะรับหรือปฏิเสธ
--   เมื่อโควตาหมดเมื่อ 25 ส.ค. 2569 ไลน์ตอบ 429 ปฏิเสธทั้งฉบับ
--   แต่ตารางบันทึกว่าส่งแล้ว ตัวกันส่งซ้ำจึงไม่ยอมส่งใหม่ตลอดกาล
--   ถ้ามีเหตุเสียชีวิตในวันนั้น ข่าวจะหายไปเงียบ ๆ โดยไม่มีอะไรฟ้อง
--
-- วิธีแก้
--   line_broadcast เก็บหมายเลขคำขอไว้ในช่อง detail อยู่แล้ว จึงไม่ต้องแก้ตาราง
--   ไฟล์นี้เอาหมายเลขนั้นไปเทียบกับคำตอบที่ไลน์ส่งกลับมา แล้วตัดสินสามทาง
--     ไลน์รับแล้ว     บันทึกยืนยัน จบ
--     โควตาหมด       ลบแถวทิ้ง รอบถัดไปจะส่งใหม่เอง
--     ผิดพลาดถาวร     เก็บไว้และทำเครื่องหมายว่าล้มเหลว ส่งใหม่ไปก็ไม่สำเร็จ
--
-- ทำไมต้องมีเพดานเวลา
--   คำตอบของไลน์ถูกเก็บไว้ราวหกชั่วโมงแล้วถูกลบ
--   ถ้าเลยเวลานั้นแล้วยังไม่รู้ผล จะไม่เดา แต่บันทึกว่าไม่ทราบผล
--   และไม่ลองส่งซ้ำข่าวที่เก่าเกินหนึ่งวัน เพราะส่งไปก็ไม่ทันการณ์แล้ว
--
-- ทำไมต้องใช้ materialized กับ CTE
--   ช่อง detail ของแถวเก่าบางแถวไม่ได้เก็บตัวเลข การแปลงเป็นตัวเลขจะพัง
--   ถ้าไม่บังคับให้กรองก่อน Postgres มีสิทธิ์ยกการแปลงขึ้นไปทำก่อนกรอง
--   แล้วทั้งฟังก์ชันจะล้มด้วยข้อความว่าแปลงเป็นตัวเลขไม่ได้
--   materialized เป็นกำแพงกั้น บังคับให้กรองเสร็จก่อนเสมอ

create or replace function line_verify_sends()
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $fn$
declare
  v_ok      int := 0;
  v_retry   int := 0;
  v_fail    int := 0;
  v_unknown int := 0;
begin
  -- ยืนยันตัวที่ไลน์รับแล้ว
  with src as materialized (
    select id, replace(detail, 'net_request_id=', '') as rid
    from line_sent
    where detail like 'net_request_id=%'
      and replace(detail, 'net_request_id=', '') ~ '^[0-9]+$'
      and sent_at > now() - interval '2 days'
  ), done as (
    update line_sent s
       set ok = true, detail = 'ไลน์รับแล้ว 200'
      from src, net._http_response x
     where s.id = src.id
       and x.id = src.rid::bigint
       and x.status_code = 200
    returning 1
  )
  select count(*) into v_ok from done;

  -- โควตาหมดหรือฝั่งไลน์ขัดข้อง ลบทิ้งเพื่อให้รอบถัดไปส่งใหม่
  -- ลบเฉพาะข่าวที่ยังไม่เกินหนึ่งวัน ข่าวเก่ากว่านั้นส่งไปก็ไม่ทันการณ์
  with src as materialized (
    select id, replace(detail, 'net_request_id=', '') as rid
    from line_sent
    where detail like 'net_request_id=%'
      and replace(detail, 'net_request_id=', '') ~ '^[0-9]+$'
      and sent_at > now() - interval '1 day'
  ), gone as (
    delete from line_sent s
     using src, net._http_response x
     where s.id = src.id
       and x.id = src.rid::bigint
       and (x.status_code = 429 or x.status_code >= 500)
    returning 1
  )
  select count(*) into v_retry from gone;

  -- ผิดพลาดถาวร เก็บไว้เป็นหลักฐาน ส่งใหม่ไปก็ไม่สำเร็จ
  with src as materialized (
    select id, replace(detail, 'net_request_id=', '') as rid
    from line_sent
    where detail like 'net_request_id=%'
      and replace(detail, 'net_request_id=', '') ~ '^[0-9]+$'
      and sent_at > now() - interval '2 days'
  ), bad as (
    update line_sent s
       set ok = false, detail = 'ไลน์ปฏิเสธ รหัส ' || x.status_code
      from src, net._http_response x
     where s.id = src.id
       and x.id = src.rid::bigint
       and x.status_code >= 400 and x.status_code < 500 and x.status_code <> 429
    returning 1
  )
  select count(*) into v_fail from bad;

  -- เลยเวลาที่คำตอบยังอยู่แล้ว แต่ยังไม่รู้ผล บอกตรง ๆ ว่าไม่ทราบ
  update line_sent
     set detail = 'ไม่ทราบผล คำตอบของไลน์ถูกลบไปก่อนตรวจ'
   where detail like 'net_request_id=%'
     and sent_at < now() - interval '8 hours';
  get diagnostics v_unknown = row_count;

  return jsonb_build_object(
    'success',        true,
    'ยืนยันแล้ว',      v_ok,
    'ลบเพื่อส่งใหม่',  v_retry,
    'ล้มเหลวถาวร',    v_fail,
    'ไม่ทราบผล',      v_unknown
  );
end;
$fn$;

-- ==========================================================
-- ตั้งเวลาให้ตรวจเอง
-- ==========================================================
-- ตรวจทุกสิบนาที เหลื่อมกับรอบส่งพอให้คำตอบกลับมาถึงแล้ว

select cron.unschedule(jobname) from cron.job where jobname = 'line-verify';
select cron.schedule('line-verify', '7,17,27,37,47,57 * * * *', 'select line_verify_sends()');

-- ==========================================================
-- ตรวจผล  คำสั่งสุดท้ายคำสั่งเดียวที่จะแสดงผล
-- ==========================================================

select 'ผลการตรวจรอบแรก' as รายการ, line_verify_sends()::text as ผล
union all
select 'งานตั้งเวลา',
       coalesce((select jobname || ' = ' || schedule from cron.job where jobname = 'line-verify'), 'ไม่พบ')
union all
select 'แถวที่ยังรอผลอยู่',
       (select count(*)::text from line_sent where detail like 'net_request_id=%') || ' แถว';
