-- จัดรูปแบบข้อความแจ้งเตือนจุดเกิดอุบัติเหตุซ้ำใหม่
-- รันหลัง line_hotspot_6_rolling30.sql
-- ไม่ต้องรัน line_hotspot_7_title.sql ไฟล์นี้ครอบคลุมทั้งหมดแล้ว
-- ถ้ามี $0 ต่อท้ายไฟล์ ให้ลบออกก่อนกด Run
--
-- รูปแบบที่ต้องการ
--   ⚠️ แจ้งเตือนจุดอันตราย
--   💥 เกิดอุบัติเหตุซ้ำ ขับผ่านให้ระวัง
--   ในรอบ 30 วันที่ผ่านมา
--
--   📍 จุดที่หนึ่ง
--   🔢 4 ครั้ง
--   📍 จุดที่สอง
--   🔢 3 ครั้ง
--   👮 จราจรชอนตะวัน และผู้เกี่ยวข้อง กำลังเร่งแก้ไข
--
--   รายละเอียดที่นี่
--   ลิงก์
--
-- บรรทัดของหน่วยงานอยู่ท้ายรายการจุด ไม่ใช่บนหัว
-- วางไว้ตรงนั้นได้ผลดีกว่า เพราะคนอ่านเห็นจุดอันตรายครบก่อน
-- แล้วจึงเห็นว่ามีคนกำลังแก้อยู่ ไม่ใช่บอกว่ากำลังแก้ตั้งแต่ยังไม่รู้ว่าแก้เรื่องอะไร

-- ==========================================================
-- 1  ค่าตั้งสองตัว  หัวเรื่อง กับ บรรทัดหน่วยงาน
-- ==========================================================
-- แยกกันเพราะอยู่คนละที่ในข้อความ หัวเรื่องอยู่บนสุด หน่วยงานอยู่ท้ายรายการ
-- ใช้ chr(10) แทนการขึ้นบรรทัดจริงในสตริง
-- เพราะการขึ้นบรรทัดกลางสตริงเคยเพี้ยนตอนพาไฟล์เข้าตัวแก้ไขของ Supabase

update bs_settings
   set val = to_jsonb(
         '⚠️ แจ้งเตือนจุดอันตราย' || chr(10) ||
         '💥 เกิดอุบัติเหตุซ้ำ ขับผ่านให้ระวัง'
       )
 where key = 'hotspotTitle';

insert into bs_settings (key, val) values
  ('hotspotAgencyLine', to_jsonb('👮 จราจรชอนตะวัน และผู้เกี่ยวข้อง กำลังเร่งแก้ไข'::text))
on conflict (key) do update set val = excluded.val;

-- ==========================================================
-- 2  ให้ฟังก์ชันวางบรรทัดหน่วยงานไว้ท้ายรายการจุด
-- ==========================================================
-- ดึงนิยามฟังก์ชันมาแก้เฉพาะจุดแล้วสร้างทับ ไม่พิมพ์ใหม่ทั้งก้อน
-- ตรวจก่อนว่าข้อความที่จะใช้เป็นจุดแทรกมีอยู่แห่งเดียวจริง ถ้าไม่ใช่จะหยุดทั้งไฟล์
-- ทั้งไฟล์อยู่ในทรานแซกชันเดียว ฟังก์ชันเดิมจึงไม่ถูกแทนที่ครึ่ง ๆ กลาง ๆ

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

  -- แทรกก่อนบล็อกที่ต่อลิงก์ท้ายข้อความ
  -- ถ้าค่าตั้งว่าง จะไม่เพิ่มบรรทัดเปล่าเข้าไปให้ข้อความดูโหว่
  v_old := 'if v_site <> '''' then';

  v_new := 'v_lines := v_lines || case when coalesce((select (val #>> array[]::text[]) '
        || 'from bs_settings where key = ''hotspotAgencyLine''), '''') = '''' '
        || 'then array[]::text[] '
        || 'else array[(select (val #>> array[]::text[]) from bs_settings '
        || 'where key = ''hotspotAgencyLine''), ''''] end;'
        || chr(10) || chr(10) || '  ' || v_old;

  v_n := (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old);
  if v_n <> 1 then
    raise exception 'จุดแทรกพบ % แห่ง ต้องพบ 1 แห่ง จึงไม่แก้อะไรเลย', v_n;
  end if;

  v_def := replace(v_def, v_old, v_new);
  execute v_def;
end;
$patch$;

-- ==========================================================
-- ตรวจผล  คำสั่งสุดท้ายคำสั่งเดียวที่จะแสดงผล
-- ==========================================================
-- ประกอบข้อความตัวจริงออกมาให้ดูทั้งก้อน ก่อนของจริงจะออกไปหาประชาชน

select 'ตัวอย่างข้อความที่ประชาชนจะได้รับ' as รายการ,
       coalesce((select (val #>> array[]::text[]) from bs_settings where key = 'hotspotTitle'), 'ไม่พบหัวเรื่อง')
       || chr(10)
       || 'ในรอบ ' || coalesce((select (val #>> array[]::text[]) from bs_settings where key = 'hotspotWindowDays'), '30')
       || ' วันที่ผ่านมา'
       || chr(10) || chr(10)
       || '📍 แยกสุวรรณวิถี 64 · ถนนสวรรค์วิถี · ต.นครสวรรค์ตก' || chr(10)
       || '🔢 4 ครั้ง' || chr(10)
       || '🩸 บาดเจ็บ 2 ราย' || chr(10)
       || '🗺️ https://www.google.com/maps?q=15.700000,100.120000' || chr(10) || chr(10)
       || '📍 หน้าตะวันแดง · ถนนเจ้าสี่พระยา · ต.ปากน้ำโพ' || chr(10)
       || '🔢 3 ครั้ง' || chr(10)
       || '🗺️ https://www.google.com/maps?q=15.706000,100.118000' || chr(10) || chr(10)
       || '📍 หน้าเซเว่นราชภัฏ · ถนนสวรรค์วิถี · ต.นครสวรรค์ตก' || chr(10)
       || '🔢 3 ครั้ง' || chr(10)
       || '🗺️ https://www.google.com/maps?q=15.701000,100.115000' || chr(10)
       || coalesce((select (val #>> array[]::text[]) from bs_settings where key = 'hotspotAgencyLine'), '')
       || chr(10) || chr(10)
       || 'รายละเอียดที่นี่' || chr(10)
       || coalesce((select (val #>> array[]::text[]) from bs_settings where key = 'publicSiteUrl'), '')
       as ข้อความ
union all
select 'ฟังก์ชันรู้จักบรรทัดหน่วยงานแล้วหรือยัง',
       case when (select position('hotspotAgencyLine' in prosrc) > 0
                    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                   where n.nspname = 'public' and p.proname = 'line_send_hotspots')
            then 'รู้จักแล้ว' else 'ยังไม่รู้จัก การแก้ไม่สำเร็จ' end;
