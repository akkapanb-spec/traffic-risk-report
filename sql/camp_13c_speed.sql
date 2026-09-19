-- ============================================================
-- กิจกรรมชวนเพื่อน  ตรวจเร็วขึ้น  ไฟล์ 13c จาก 3  สลับโหมด และเปิดโหมดทุกนาทีวันนี้
-- ============================================================
-- รันไฟล์นี้แล้วระบบเริ่มตรวจทุกนาทีทันที
-- และจะกลับเป็นทุก 5 นาทีเองตอนเที่ยงคืนตามเวลาไทย ไม่ต้องมีใครมารันอะไร
--
-- สองโหมด
--   fast    ตรวจทุกนาที  คนที่ยังไม่ผ่านตรวจซ้ำทุก 2 นาที  ใช้วันที่มีคนเข้าร่วมเยอะ
--   normal  ถาม 0 5 10 ...  เก็บ 2 7 12 ...  ให้สิทธิ์ 3 8 13 ...  คนที่ยังไม่ผ่านตรวจซ้ำทุก 10 นาที
--
-- อยากเปิดโหมดเร็วอีกวันไหนก็ได้    select camp_speed('fast');
-- อยากกลับโหมดปกติก่อนเที่ยงคืน       select camp_speed('normal');
--
-- งานตามเวลาอ่านเวลาเป็น UTC  เที่ยงคืนไทยคือ 17 นาฬิกา UTC ของวันเดียวกัน
-- วันที่ในงานปิดโหมดเร็วจึงคำนวณจากวันที่ไทย แล้วตั้งชั่วโมงเป็น 17
-- งานปิดโหมดเร็วลบตัวเองทิ้งตอนทำงาน ไม่วนกลับมาทำซ้ำปีหน้า
--
-- ห้ามมีปีกกาในไฟล์นี้ ตัวแก้ไขจะเติมแบ็กสแลชให้
-- ก่อนกด Run ให้ลบสิ่งที่ตัวแก้ไขเติมไว้ท้ายสุดออกก่อน เป็นดอลลาร์ตามด้วยเลขศูนย์

create or replace function camp_speed(p_mode text)
returns text
language plpgsql
volatile
security definer
set search_path = public
as $fn$
declare
  v_day date := (now() at time zone 'Asia/Bangkok')::date;
  v_end text;
begin
  -- ตรวจชื่อโหมดก่อนลบงานเดิม  ไม่งั้นพิมพ์ผิดทีเดียวกิจกรรมหยุดตรวจทั้งหมด
  if p_mode not in ('fast', 'normal') then
    return 'ไม่รู้จักโหมด ' || coalesce(p_mode, '') || '  ใช้ได้แค่ fast หรือ normal  ไม่ได้เปลี่ยนอะไร';
  end if;

  perform cron.unschedule(jobid) from cron.job
   where jobname in ('camp-fire', 'camp-collect', 'camp-award', 'camp-tick', 'camp-fast-end');

  if p_mode = 'fast' then
    perform cron.schedule('camp-tick', '* * * * *', 'select camp_tick()');
    v_end := '0 17 ' || extract(day from v_day)::int || ' ' || extract(month from v_day)::int || ' *';
    perform cron.schedule('camp-fast-end', v_end, 'select camp_speed(''normal'')');
    insert into bs_settings(key, val) values ('campRetryMinutes', '2'::jsonb)
    on conflict (key) do update set val = excluded.val, updated_at = now();
    return 'โหมดตรวจทุกนาที  จะกลับเป็นทุก 5 นาทีเองตอนเที่ยงคืนของวันที่ '
           || to_char(v_day, 'DD/MM/') || (extract(year from v_day)::int + 543)::text;
  end if;

  perform cron.schedule('camp-fire',    '*/5 * * * *',    'select camp_check_fire()');
  perform cron.schedule('camp-collect', '2-59/5 * * * *', 'select camp_check_collect()');
  perform cron.schedule('camp-award',   '3-59/5 * * * *', 'select camp_award()');
  insert into bs_settings(key, val) values ('campRetryMinutes', '10'::jsonb)
  on conflict (key) do update set val = excluded.val, updated_at = now();
  return 'โหมดปกติ  ตรวจทุก 5 นาที';
end;
$fn$;

revoke execute on function camp_speed(text) from public, anon, authenticated;

-- เปิดโหมดทุกนาทีสำหรับวันนี้
select camp_speed('fast');

-- ตรวจ  ต้องเห็นสองงาน  camp-tick ทุกนาที  และ camp-fast-end ตอน 17 นาฬิกา UTC ของวันนี้
-- และต้องไม่เหลือ camp-fire camp-collect camp-award ค้างอยู่
select jobname as งาน, schedule as เวลา_UTC, command as คำสั่ง
  from cron.job
 where jobname like 'camp-%'
 order by jobname;

-- จบไฟล์  อย่าเคาะบรรทัดใหม่ต่อท้ายบรรทัดนี้ ->
