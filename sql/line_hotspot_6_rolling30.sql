-- เปลี่ยนการนับจุดเกิดเหตุซ้ำ จากเดือนปฏิทิน เป็นย้อนหลัง 30 วันแบบเลื่อน
-- รันหลัง line_hotspot_5_report.sql
-- ถ้ามี $0 ต่อท้ายไฟล์ ให้ลบออกก่อนกด Run
--
-- ทำไมต้องเปลี่ยน
--   ของเดิมนับตั้งแต่วันที่ 1 ของเดือน ตัวนับจึงกลับเป็นศูนย์ทุกต้นเดือน
--   สิบวันแรกของทุกเดือนจึงไม่มีทางมีจุดไหนถึงเกณฑ์ ไม่ว่าตั้งเกณฑ์ต่ำแค่ไหน
--   ระบบเงียบครึ่งเดือน แล้วค่อยเริ่มเตือนตอนที่ข้อมูลกำลังจะถูกล้างทิ้งพอดี
--   วัดจากข้อมูลจริงเมื่อ 21 ส.ค. 2569
--     เดือนปฏิทิน   จุดที่ซ้ำ 3 ครั้งขึ้นไป  2 จุด
--     ย้อนหลัง 30 วัน จุดที่ซ้ำ 3 ครั้งขึ้นไป  3 จุด และไม่มีวันรีเซ็ต
--
-- วิธีทำ
--   ดึงนิยามฟังก์ชันจากฐานข้อมูลมาแก้เฉพาะจุด แล้วสร้างทับ
--   ไม่พิมพ์ใหม่ทั้งก้อนเพราะยาวเกือบหนึ่งหมื่นตัวอักษร โอกาสพิมพ์ตกมีสูง
--   ทุกจุดที่แก้มีการนับก่อนว่าเจอจริงหรือไม่ ถ้าไม่เจอจะหยุดทั้งไฟล์
--   ทั้งไฟล์อยู่ในทรานแซกชันเดียว ฟังก์ชันเดิมจึงไม่มีทางถูกแทนที่ครึ่ง ๆ กลาง ๆ

-- ==========================================================
-- 1  ค่าตั้งความยาวหน้าต่างเวลา
-- ==========================================================
-- แยกเป็นค่าตั้ง จะได้เปลี่ยนเป็น 45 หรือ 60 วันทีหลังด้วย update บรรทัดเดียว
-- ไม่ต้องกลับมาแก้ฟังก์ชันอีก

insert into bs_settings (key, val) values ('hotspotWindowDays', to_jsonb(30))
on conflict (key) do update set val = excluded.val;

-- ==========================================================
-- 2  แก้ฟังก์ชัน
-- ==========================================================

do $patch$
declare
  v_def text;
  v_old text;
  v_new text;
  v_n   int;
begin
  select pg_get_functiondef(p.oid) into v_def
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'line_send_hotspots';

  if v_def is null then
    raise exception 'ไม่พบฟังก์ชัน line_send_hotspots ต้องรัน line_hotspot_5_report.sql ก่อน';
  end if;

  -- ---------- จุดที่ 1  ช่วงเวลาที่ใช้นับ ----------
  v_old := 'v_from := date_trunc(''month'', timezone(''Asia/Bangkok'', now()));';
  v_new := 'v_from := timezone(''Asia/Bangkok'', now()) - make_interval(days => '
        || 'coalesce((select (val #>> array[]::text[])::int from bs_settings '
        || 'where key = ''hotspotWindowDays''), 30));';
  v_n := (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old);
  if v_n <> 1 then
    raise exception 'จุดที่ 1 ช่วงเวลา พบ % แห่ง ต้องพบ 1 แห่ง จึงไม่แก้อะไรเลย', v_n;
  end if;
  v_def := replace(v_def, v_old, v_new);

  -- ---------- จุดที่ 2  กุญแจกันส่งซ้ำ ----------
  -- เดิมใช้ปีเดือนของหน้าต่าง ซึ่งกลายเป็นค่าเลื่อนไปเรื่อยเมื่อเปลี่ยนเป็นแบบ 30 วัน
  -- ถ้าปล่อยไว้ กุญแจจะเปลี่ยนทุกวันแล้วส่งข้อความเดิมซ้ำทุกวัน
  -- ตรึงเป็น roll30 บวกเดือนปัจจุบัน แปลว่า
  --   ภาพเหมือนเดิมในเดือนเดียวกัน เงียบ
  --   ตัวเลขในจุดใดขยับ ส่งใหม่ทันทีเพราะกุญแจฝังจำนวนครั้งไว้อยู่แล้ว
  --   ขึ้นเดือนใหม่ ย้ำอีกครั้งหนึ่งสำหรับจุดที่ยังอันตรายอยู่
  v_old := 'v_month := to_char(v_from, ''YYYY-MM'');';
  v_new := 'v_month := ''roll30-'' || to_char(timezone(''Asia/Bangkok'', now()), ''YYYY-MM'');';
  v_n := (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old);
  if v_n <> 1 then
    raise exception 'จุดที่ 2 กุญแจกันส่งซ้ำ พบ % แห่ง ต้องพบ 1 แห่ง จึงไม่แก้อะไรเลย', v_n;
  end if;
  v_def := replace(v_def, v_old, v_new);

  -- ---------- จุดที่ 3  ข้อความที่ประชาชนเห็น ----------
  -- เดิมเขียนว่า ประจำเดือน ส.ค.69 ซึ่งจะกลายเป็นคำโกหกทันทีที่เปลี่ยนวิธีนับ
  -- เพราะช่วงที่นับคร่อมสองเดือนเสมอ
  v_old := '''ประจำเดือน '' || v_monthth';
  v_new := '''ในรอบ '' || coalesce((select (val #>> array[]::text[]) from bs_settings '
        || 'where key = ''hotspotWindowDays''), ''30'') || '' วันที่ผ่านมา''';
  v_n := (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old);
  if v_n <> 1 then
    raise exception 'จุดที่ 3 ข้อความ พบ % แห่ง ต้องพบ 1 แห่ง จึงไม่แก้อะไรเลย', v_n;
  end if;
  v_def := replace(v_def, v_old, v_new);

  execute v_def;
end;
$patch$;

-- ==========================================================
-- ตรวจผล  คำสั่งสุดท้ายคำสั่งเดียวที่จะแสดงผล
-- ==========================================================

select 'ความยาวหน้าต่างเวลา' as รายการ,
       coalesce((select (val #>> array[]::text[]) from bs_settings where key = 'hotspotWindowDays'), 'ไม่พบ')
       || ' วัน' as ผล
union all
select 'เกณฑ์จำนวนครั้ง',
       coalesce((select (val #>> array[]::text[]) from bs_settings where key = 'hotspotMinPerMonth'), 'ไม่พบ')
       || ' ครั้ง  (ชื่อคีย์ยังเป็น PerMonth ตามเดิม แต่ตอนนี้หมายถึงต่อหน้าต่าง 30 วัน)'
union all
select 'เกณฑ์ผู้บาดเจ็บสาหัสหรือเสียชีวิต',
       coalesce((select (val #>> array[]::text[]) from bs_settings where key = 'hotspotSevereMinPerMonth'), 'ไม่พบ')
       || ' ราย'
union all
select 'ยังนับเป็นเดือนปฏิทินอยู่ไหม',
       case when (select position('date_trunc(''month''' in prosrc) > 0
                    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                   where n.nspname = 'public' and p.proname = 'line_send_hotspots')
            then 'ยังนับอยู่  การแก้ไม่สำเร็จ'
            else 'เปลี่ยนเป็นแบบเลื่อนแล้ว' end
union all
select 'ยังมีคำว่า ประจำเดือน ในข้อความไหม',
       case when (select position('ประจำเดือน' in prosrc) > 0
                    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                   where n.nspname = 'public' and p.proname = 'line_send_hotspots')
            then 'ยังมีอยู่  การแก้ไม่สำเร็จ'
            else 'เปลี่ยนเป็น ในรอบ 30 วันที่ผ่านมา แล้ว' end
union all
select 'งานตั้งเวลาที่เรียกฟังก์ชันนี้',
       coalesce((select string_agg(jobname || ' = ' || schedule, '   ')
                 from cron.job where command ilike '%hotspot%'), 'ไม่พบ');
