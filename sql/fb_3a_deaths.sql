-- ============================================================
-- โพสต์เฟซบุ๊กอัตโนมัติ  ไฟล์ 3a  โพสต์อุบัติเหตุเสียชีวิต
-- ============================================================
-- รันได้หลังไฟล์ 2a ผ่านแล้วเท่านั้น เพราะเรียก fb_post
--
-- ห้ามมีปีกกาในไฟล์นี้ ตัวแก้ไขจะเติมแบ็กสแลชให้
-- ก่อนกด Run ให้ลบสิ่งที่ตัวแก้ไขเติมไว้ท้ายสุดออกก่อน เป็นดอลลาร์ตามด้วยเลขศูนย์
--
-- ข้อความเหมือนไลน์ทุกตัวอักษร เพราะเรียกตัวสร้างข้อความตัวเดียวกัน
-- คือ line_msg_death ซึ่งมีเวลา ถนน ตำบล เพศ อายุ และบทบาท
-- เป็นการตัดสินใจของผู้ใช้เมื่อ 16 ก.ย. 2569 หลังทราบว่าเพจเป็นสาธารณะถาวร
-- ค้นเจอด้วยกูเกิล และแคปไปแชร์ต่อได้ ต่างจากกลุ่มไลน์ที่เป็นวงจำกัด
--
-- โพสต์เฉพาะรายที่เสียชีวิตในที่เกิดเหตุ เหมือนเงื่อนไขของไลน์
-- รายที่ไปเสียชีวิตที่โรงพยาบาลจะถูกจดว่าข้าม ไม่ใช่ค้างไว้ให้ลองซ้ำทุกรอบ
--
-- อันตรายที่สุดของไฟล์นี้คือของค้างเก่า ตาราง deaths มีข้อมูลย้อนหลังหลายปี
-- ถ้าไม่กันไว้ รอบแรกจะไล่โพสต์ประวัติทั้งหมดขึ้นเพจจนกว่าจะหมด
-- จึงกันสองชั้น  ท้ายไฟล์จดของเก่าทั้งหมดว่าจัดการแล้ว
-- และตัวฟังก์ชันเองไม่แตะรายที่เกิดเหตุเกินกรอบเวลาที่กำหนด

create or replace function fb_send_deaths(p_max int default 3, p_hours int default 48)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $fn$
declare
  d      record;
  v_txt  text;
  v_r    jsonb;
  v_sent int := 0;
  v_skip int := 0;
begin
  if coalesce((select (val #>> array[]::text[])::boolean from bs_settings
                where key = 'fbEnabled'), false) is not true then
    return jsonb_build_object('success', true, 'sent', 0, 'message', 'ปิดอยู่');
  end if;

  for d in
    select d2.id, d2.col_g from deaths d2
     where not exists (select 1 from fb_sent s
                        where s.kind = 'death' and s.ref_id = d2.id::text)
       and d2.incident_datetime >= now() - make_interval(hours => greatest(1, p_hours))
     order by d2.incident_datetime desc nulls last, d2.id desc
     limit greatest(1, p_max)
  loop
    if coalesce(btrim(d.col_g), '') <> 'เสียชีวิตที่เกิดเหตุ' then
      insert into fb_sent(kind, ref_id, ok, note)
      values ('death', d.id::text, true, 'ข้าม ไม่ได้เสียชีวิตในที่เกิดเหตุ')
      on conflict (kind, ref_id) do nothing;
      v_skip := v_skip + 1;
      continue;
    end if;

    v_txt := line_msg_death(d.id);
    if coalesce(v_txt, '') = '' then
      -- สร้างข้อความไม่ได้  ไม่จดอะไรไว้ รอบหน้าจะได้ลองใหม่
      continue;
    end if;

    v_r := fb_post('death', d.id::text, v_txt);
    if coalesce((v_r ->> 'posted')::boolean, false) then
      v_sent := v_sent + 1;
    end if;
  end loop;

  return jsonb_build_object('success', true, 'sent', v_sent, 'skipped', v_skip);
end;
$fn$;

revoke execute on function fb_send_deaths(int, int) from public, anon, authenticated;

-- ============================================================
-- กันของค้างเก่า  บรรทัดนี้สำคัญที่สุดในไฟล์ ห้ามตัดออก
-- ============================================================
-- จดว่าผู้เสียชีวิตทุกรายที่มีอยู่แล้ววันนี้ จัดการแล้ว
-- ไม่ได้ส่งอะไรออกไป แค่กันไม่ให้ประวัติเก่าถูกโพสต์ย้อนหลัง
-- ตั้งแต่นี้ไป จะโพสต์เฉพาะรายที่ ปนพ. บันทึกเข้ามาใหม่เท่านั้น
insert into fb_sent(kind, ref_id, ok, note)
select 'death', id::text, true, 'มีอยู่ก่อนเปิดใช้เฟซบุ๊ก ไม่โพสต์ย้อนหลัง'
  from deaths
on conflict (kind, ref_id) do nothing;

-- ตรวจ  ต้องได้ฟังก์ชัน 1 และของเก่าถูกจดไว้ครบเท่าจำนวนแถวในตาราง
-- ลองเรียกได้ผลเป็น ปิดอยู่ เพราะ fbEnabled ยังเป็นเท็จ
select
  (select count(*) from pg_proc where proname = 'fb_send_deaths')      as ฟังก์ชัน,
  (select count(*) from deaths)                                        as ผู้เสียชีวิตทั้งหมด,
  (select count(*) from fb_sent where kind = 'death')                  as จดไว้แล้ว,
  fb_send_deaths(3, 48)                                                as ลองเรียก;

-- จบไฟล์  อย่าเคาะบรรทัดใหม่ต่อท้ายบรรทัดนี้ ->