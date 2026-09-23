-- ============================================================
-- โพสต์เฟซบุ๊กอัตโนมัติ  ไฟล์ 5b จาก 3  ใส่ภาพให้ข่าวเสียชีวิต
-- ============================================================
-- รันหลัง 5a เท่านั้น เพราะเรียก fb_card_url
--
-- ห้ามมีปีกกาในไฟล์นี้ ตัวแก้ไขจะเติมแบ็กสแลชให้
-- ก่อนกด Run ให้ลบสิ่งที่ตัวแก้ไขเติมไว้ท้ายสุดออกก่อน เป็นดอลลาร์ตามด้วยเลขศูนย์
--
-- ทับฟังก์ชันเดิมทั้งตัว เนื้อความเหมือนเดิมทุกตัวอักษร
-- เพราะยังเรียก line_msg_death ตัวเดิม  ที่เพิ่มคือพารามิเตอร์ตัวที่สี่ของ fb_post
--
-- ชุดพารามิเตอร์ต้องเหมือนของเดิมเป๊ะ ทั้งชื่อและค่าตั้งต้น
-- ถ้าเปลี่ยนชื่อพารามิเตอร์ create or replace จะไม่ยอมทำงาน
-- และถ้าเปลี่ยนจำนวน จะกลายเป็นมีสองตัวให้เลือกจนเรียกไม่ถูก

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

    v_r := fb_post('death', d.id::text, v_txt, fb_card_url('death', d.id::text));
    if coalesce((v_r ->> 'posted')::boolean, false) then
      v_sent := v_sent + 1;
    end if;
  end loop;

  return jsonb_build_object('success', true, 'sent', v_sent, 'skipped', v_skip);
end;
$fn$;

revoke execute on function fb_send_deaths(int, int) from public, anon, authenticated;

-- ตรวจ  ดูว่ารอบถัดไปจะหยิบรายไหน และจะแนบภาพใบไหนไปกับโพสต์
-- ยังไม่มีอะไรถูกส่งออกไป บรรทัดนี้แค่อ่าน
select d.id                               as รหัสผู้เสียชีวิต,
       d.col_g                            as อาการ,
       fb_card_url('death', d.id::text)   as ภาพที่จะแนบ
  from deaths d
 where not exists (select 1 from fb_sent s where s.kind = 'death' and s.ref_id = d.id::text)
   and d.incident_datetime >= now() - make_interval(hours => 48)
 order by d.incident_datetime desc nulls last
 limit 5;

-- จบไฟล์  อย่าเคาะบรรทัดใหม่ต่อท้ายบรรทัดนี้ ->
