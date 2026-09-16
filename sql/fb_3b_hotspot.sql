-- ============================================================
-- โพสต์เฟซบุ๊กอัตโนมัติ  ไฟล์ 3b  โพสต์จุดอุบัติเหตุซ้ำ
-- ============================================================
-- รันได้หลังไฟล์ 2a ผ่านแล้วเท่านั้น เพราะเรียก fb_post
--
-- ห้ามมีปีกกาในไฟล์นี้ ตัวแก้ไขจะเติมแบ็กสแลชให้
-- ก่อนกด Run ให้ลบสิ่งที่ตัวแก้ไขเติมไว้ท้ายสุดออกก่อน เป็นดอลลาร์ตามด้วยเลขศูนย์
--
-- ไม่คำนวณเอง อ่านผลที่ไลน์คำนวณไว้แล้วจาก line_hotspot_cache
-- ซึ่งงานตามเวลาคำนวณให้ใหม่ทุกชั่วโมงอยู่แล้ว
-- การคำนวณจุดซ้ำถูกเขียนใหม่มาสี่รอบกว่าจะนิ่ง ห้ามลอกมาทำใหม่เด็ดขาด
--
-- รหัสอ้างอิงผูกกับสัปดาห์ จึงโพสต์ได้สัปดาห์ละครั้งเป็นอย่างมาก
-- ตั้งใจไม่ผูกกับตัวเลขจำนวนครั้งแบบที่ไลน์ทำ
-- เพราะรอบนับเป็นแบบเลื่อน ตัวเลขขยับเองได้แม้ไม่มีใครกรอกอะไรเพิ่ม
-- ผูกกับตัวเลขเมื่อไร เรื่องเดิมจะถูกโพสต์ซ้ำเรื่อย ๆ โดยไม่มีอะไรเปลี่ยนจริง
-- ซึ่งเคยเกิดกับไลน์มาแล้ว ส่ง 21 ข้อความใน 30 วัน

create or replace function fb_send_hotspots()
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $fn$
declare
  v_body jsonb;
  v_txt  text;
  v_ref  text;
  v_r    jsonb;
begin
  if coalesce((select (val #>> array[]::text[])::boolean from bs_settings
                where key = 'fbEnabled'), false) is not true then
    return jsonb_build_object('success', true, 'sent', 0, 'message', 'ปิดอยู่');
  end if;

  select body into v_body from line_hotspot_cache where id = 1;

  if v_body is null then
    return jsonb_build_object('success', true, 'sent', 0, 'message', 'ยังไม่มีผลคำนวณ');
  end if;

  if coalesce((v_body ->> 'found')::int, 0) = 0 then
    return jsonb_build_object('success', true, 'sent', 0, 'message', 'ไม่มีจุดใดเข้าเกณฑ์ ซึ่งเป็นเรื่องดี');
  end if;

  v_txt := v_body ->> 'text';
  if coalesce(v_txt, '') = '' then
    return jsonb_build_object('success', false, 'sent', 0, 'message', 'ผลคำนวณไม่มีข้อความ');
  end if;

  -- สัปดาห์ตามมาตรฐานสากล  ปีกับเลขสัปดาห์ ไม่ใช่วันที่
  v_ref := 'hs-' || to_char(now() at time zone 'Asia/Bangkok', 'IYYY-IW');

  v_r := fb_post('hotspot', v_ref, v_txt);

  return jsonb_build_object('success', true,
    'sent', case when coalesce((v_r ->> 'posted')::boolean, false) then 1 else 0 end,
    'ref', v_ref, 'ผล', v_r);
end;
$fn$;

revoke execute on function fb_send_hotspots() from public, anon, authenticated;

-- ตรวจ  ลองเรียกได้ผลเป็น ปิดอยู่ เพราะ fbEnabled ยังเป็นเท็จ
select
  (select count(*) from pg_proc where proname = 'fb_send_hotspots')          as ฟังก์ชัน,
  (select count(*) from line_hotspot_cache)                                  as มีผลคำนวณไหม,
  (select body ->> 'found' from line_hotspot_cache where id = 1)             as จุดที่เข้าเกณฑ์,
  fb_send_hotspots()                                                         as ลองเรียก;

-- จบไฟล์  อย่าเคาะบรรทัดใหม่ต่อท้ายบรรทัดนี้ ->