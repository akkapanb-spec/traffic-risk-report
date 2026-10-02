-- ============================================================
-- ตัดสินความเร่งด่วนจากความยาวของเหตุ ไม่ใช่จากวันในปฏิทิน
-- ============================================================
-- ห้ามมีปีกกาในไฟล์นี้ ตัวแก้ไขจะเติมแบ็กสแลชให้
-- ก่อนกด Run ให้ลบสิ่งที่ตัวแก้ไขเติมไว้ท้ายสุดออกก่อน เป็นดอลลาร์ตามด้วยเลขศูนย์
--
-- ------------------------------------------------------------
-- ปัญหาที่เพิ่งเจอกับของจริง 2 ต.ค. 2569
-- ------------------------------------------------------------
-- มีประกาศน้ำท่วมสองใบถูกกรอกตอนบ่าย มีผล 24 ชั่วโมงพอดี
--   รหัส 23  2 ต.ค. 13:39 ถึง 3 ต.ค. 13:39
--   รหัส 24  2 ต.ค. 13:47 ถึง 3 ต.ค. 13:47
--
-- กฎเดิมดูว่า วันที่เริ่ม กับ วันที่จบ เป็นวันเดียวกันในปฏิทินหรือไม่
-- สองใบนี้คร่อมเที่ยงคืน จึงถูกจัดเป็นงานหลายวัน แล้วต้องรอรอบเก้าโมงของวันรุ่งขึ้น
-- ซึ่งคือ 3 ต.ค. 09:00 ห่างจากตอนกรอกเกือบยี่สิบชั่วโมง
-- และเหลือเวลาก่อนประกาศหมดอายุแค่สี่ชั่วโมงครึ่ง
--
-- เตือนน้ำท่วมที่ไปถึงคนอ่านตอนน้ำจะลดแล้ว ไม่ต่างกับไม่ได้เตือน
--
-- ------------------------------------------------------------
-- กฎใหม่
-- ------------------------------------------------------------
-- เหตุที่กินเวลาไม่เกิน 36 ชั่วโมง ถือว่าเร่งด่วน ประกาศรอบถัดไปทันที
-- ไม่สนว่าจะคร่อมเที่ยงคืนหรือไม่  เพราะคนเดือดร้อนไม่ได้สนปฏิทิน
-- เลข 36 เผื่อไว้สำหรับงานที่เริ่มบ่ายนี้แล้วจบเย็นพรุ่งนี้ ซึ่งยังเป็นเรื่องกระชั้น
--
-- เหตุน้ำท่วมถือว่าเร่งด่วนเสมอ ไม่ว่าจะยาวแค่ไหน
-- เพราะระดับน้ำเปลี่ยนเร็วและเส้นทางถูกตัดขาดได้ทันที
-- ถ้าไม่ต้องการข้อนี้ บอกได้ ตัดเงื่อนไข kind ออกบรรทัดเดียว
--
-- ของที่ยาวกว่านั้นและไม่ใช่น้ำท่วม ยังรอรอบเก้าโมงของวันถัดจากวันที่กรอกเหมือนเดิม

create or replace function fb_send_advisories(p_max int default 3)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $fn$
declare
  a        record;
  v_txt    text;
  v_img    text;
  v_site   text;
  v_r      jsonb;
  v_sent   int := 0;
  v_now    timestamp;
  v_hour   int;
  v_today  date;
begin
  if coalesce((select (val #>> array[]::text[])::boolean from bs_settings
                where key = 'fbEnabled'), false) is not true then
    return jsonb_build_object('success', true, 'sent', 0, 'message', 'ปิดอยู่');
  end if;

  v_site := coalesce((select val #>> array[]::text[] from bs_settings where key = 'publicSiteUrl'), '');

  v_now   := now() at time zone 'Asia/Bangkok';
  v_hour  := extract(hour from v_now)::int;
  v_today := v_now::date;

  for a in
    select t.id, t.images from traffic_advisories t
     where t.closed_at is null
       and t.ends_at   >= now()
       and (
         -- เร่งด่วน  ออกรอบถัดไปได้เลย
         t.ends_at - t.starts_at <= interval '36 hours'
         or t.kind = 'flood'
         -- ไม่เร่งด่วน  รอรอบชั่วโมงเก้าของวันถัดจากวันที่กรอก
         or ( v_hour = 9
              and (t.created_at at time zone 'Asia/Bangkok')::date < v_today )
       )
       and not exists (select 1 from fb_sent s
                        where s.kind = 'advisory' and s.ref_id = t.id::text)
     order by t.starts_at, t.created_at
     limit greatest(1, p_max)
  loop
    v_txt := line_adv_item_text(a.id);
    if coalesce(v_txt, '') = '' then
      continue;
    end if;

    v_img := nullif(btrim(coalesce(a.images ->> 0, '')), '');

    v_txt := '🚧 แจ้งจุดที่ควรหลีกเลี่ยง' || chr(10) || chr(10) || v_txt || chr(10) || chr(10) ||
      'โปรดวางแผนการเดินทาง และใช้ความระมัดระวังเมื่อผ่านบริเวณดังกล่าว';

    if v_site <> '' then
      v_txt := v_txt || chr(10) || chr(10) || 'ดูรูปภาพและรายละเอียดทั้งหมด' || chr(10) || v_site;
    end if;

    v_txt := v_txt || chr(10) || chr(10) || '👮 ด้วยความปรารถนาดี น้องจราจรชอนตะวัน';

    v_r := fb_post('advisory', a.id::text, v_txt, v_img);
    if coalesce((v_r ->> 'posted')::boolean, false) then
      v_sent := v_sent + 1;
    end if;
  end loop;

  return jsonb_build_object('success', true, 'sent', v_sent, 'hour', v_hour);
end;
$fn$;

revoke execute on function fb_send_advisories(int) from public, anon, authenticated;

-- ตรวจ  ยังไม่มีอะไรถูกส่งออกไปจากไฟล์นี้
-- ช่อง จะประกาศเมื่อไหร่ ต้องขึ้นว่าเร่งด่วนสำหรับสองใบที่เป็นน้ำท่วม
select
  t.id                                                              as รหัส,
  left(coalesce(t.title, ''), 28)                                   as เรื่อง,
  t.kind                                                            as ประเภท,
  to_char(t.ends_at - t.starts_at, 'DD" วัน "HH24" ชม."')           as กินเวลา,
  case
    when exists (select 1 from fb_sent s
                  where s.kind = 'advisory' and s.ref_id = t.id::text)
      then 'จดไว้แล้ว ไม่ขึ้นเพจ'
    when t.ends_at - t.starts_at <= interval '36 hours' or t.kind = 'flood'
      then 'เร่งด่วน ขึ้นเพจรอบถัดไป'
    else 'รอรอบเก้าโมงเช้า'
  end                                                               as จะประกาศเมื่อไหร่
from traffic_advisories t
where t.closed_at is null
  and t.ends_at >= now()
order by t.created_at desc;

-- จบไฟล์  อย่าเคาะบรรทัดใหม่ต่อท้ายบรรทัดนี้ ->
