-- ============================================================
-- ประกาศจุดควรหลีกเลี่ยง  งานหนึ่งวันประกาศทันที นอกนั้นรอบแปดโมงเช้า
-- ============================================================
-- ห้ามมีปีกกาในไฟล์นี้ ตัวแก้ไขจะเติมแบ็กสแลชให้
-- ก่อนกด Run ให้ลบสิ่งที่ตัวแก้ไขเติมไว้ท้ายสุดออกก่อน เป็นดอลลาร์ตามด้วยเลขศูนย์
--
-- ------------------------------------------------------------
-- กฎที่ผู้ใช้กำหนดไว้ 24 ก.ย. 2569
-- ------------------------------------------------------------
-- งานที่เริ่มและจบภายในวันเดียว  ประกาศทันทีที่กรอกเสร็จ
-- งานที่กินเวลาหลายวัน          ประกาศรอบแปดโมงเช้าของวันก่อนเริ่ม
--
-- เหตุผลของการแยกสองแบบ
-- งานวันเดียวมักเป็นของด่วนที่รู้ตัวกระชั้น เช่น งานที่จัดเย็นนี้
-- ถ้าให้รอรอบเช้า ก็ได้ประกาศตอนงานเลิกไปแล้ว เท่ากับไม่ได้ประกาศ
-- ส่วนงานหลายวันรู้ล่วงหน้าอยู่แล้ว ประกาศเช้าวันก่อนหน้าให้คนมีเวลาวางแผนทั้งวัน
-- และไม่ไปเบียดหน้าเพจด้วยโพสต์ที่โผล่มาตอนไหนก็ไม่รู้
--
-- ------------------------------------------------------------
-- ตัวตั้งเวลายังวิ่งทุกสิบห้านาทีเหมือนเดิม ห้ามเปลี่ยนเป็นวันละครั้ง
-- ------------------------------------------------------------
-- เพราะงานวันเดียวต้องออกทันทีที่กรอก ไม่ใช่รอถึงเวลาใดเวลาหนึ่ง
-- ตัวฟังก์ชันเป็นคนตัดสินเองว่ารอบนี้หยิบอะไรได้บ้าง
-- รอบที่ตรงกับแปดโมงเช้าเท่านั้นที่จะหยิบงานหลายวันเพิ่มขึ้นมาด้วย
-- ถ้าไปเปลี่ยนตัวตั้งเวลาเป็นวันละครั้ง งานวันเดียวจะเงียบไปทั้งหมดโดยไม่มีใครรู้
--
-- ฝั่งไลน์ไม่ได้แตะเลย ยังทุกห้านาทีเหมือนเดิม
-- ไลน์เป็นช่องทางด่วนของวงจำกัด เพจเป็นของสาธารณะที่ต้องคุมจังหวะ

-- ==========================================================
-- 1  ตัวส่ง
-- ==========================================================

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
  v_limit  timestamptz;
begin
  if coalesce((select (val #>> array[]::text[])::boolean from bs_settings
                where key = 'fbEnabled'), false) is not true then
    return jsonb_build_object('success', true, 'sent', 0, 'message', 'ปิดอยู่');
  end if;

  v_site := coalesce((select val #>> array[]::text[] from bs_settings where key = 'publicSiteUrl'), '');

  v_now  := now() at time zone 'Asia/Bangkok';
  v_hour := extract(hour from v_now)::int;

  -- รอบแปดโมงเช้ามองไปถึงสิ้นวันพรุ่งนี้  รอบอื่นมองแค่สิ้นวันนี้
  -- ผลคืองานหลายวันได้ประกาศเช้าวันก่อนเริ่ม ส่วนงานวันเดียวออกได้ทุกรอบ
  if v_hour = 8 then
    v_limit := (date_trunc('day', v_now) + interval '2 days') at time zone 'Asia/Bangkok';
  else
    v_limit := (date_trunc('day', v_now) + interval '1 day')  at time zone 'Asia/Bangkok';
  end if;

  for a in
    select t.id, t.images from traffic_advisories t
     where t.closed_at is null
       and t.ends_at   >= now()
       and t.starts_at <  v_limit
       -- นอกรอบแปดโมง รับเฉพาะงานที่เริ่มและจบภายในวันเดียวกัน
       and (v_hour = 8
            or (t.starts_at at time zone 'Asia/Bangkok')::date
                = (t.ends_at at time zone 'Asia/Bangkok')::date)
       and not exists (select 1 from fb_sent s
                        where s.kind = 'advisory' and s.ref_id = t.id::text)
     order by t.starts_at, t.created_at
     limit greatest(1, p_max)
  loop
    v_txt := line_adv_item_text(a.id);
    if coalesce(v_txt, '') = '' then
      continue;
    end if;

    -- รูปแรกที่แนบไว้  เฟซบุ๊กรับรูปเดียวต่อหนึ่งโพสต์ด้วยวิธีนี้
    -- รูปที่เหลือยังดูได้บนหน้าเว็บ ซึ่งมีลิงก์อยู่ท้ายข้อความแล้ว
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

-- ==========================================================
-- 2  ตรวจ  ยังไม่มีอะไรถูกส่งออกไปจากไฟล์นี้
-- ==========================================================
-- ช่อง จะประกาศเมื่อไหร่ บอกชะตากรรมของแต่ละรายการ

select
  t.id                                                              as รหัส,
  left(coalesce(t.title, ''), 30)                                   as เรื่อง,
  to_char(t.starts_at at time zone 'Asia/Bangkok', 'DD/MM HH24:MI') as เริ่ม,
  to_char(t.ends_at   at time zone 'Asia/Bangkok', 'DD/MM HH24:MI') as สิ้นสุด,
  case when (t.starts_at at time zone 'Asia/Bangkok')::date
          = (t.ends_at   at time zone 'Asia/Bangkok')::date
       then 'วันเดียว' else 'หลายวัน' end                            as ประเภทช่วงเวลา,
  case
    when exists (select 1 from fb_sent s
                  where s.kind = 'advisory' and s.ref_id = t.id::text)
      then 'จดไว้แล้ว ไม่ขึ้นเพจ'
    when (t.starts_at at time zone 'Asia/Bangkok')::date
       = (t.ends_at   at time zone 'Asia/Bangkok')::date
      then 'ขึ้นเพจรอบถัดไป ภายใน 15 นาที'
    else 'ขึ้นเพจรอบแปดโมงเช้าของวันก่อนเริ่ม'
  end                                                               as จะประกาศเมื่อไหร่
from traffic_advisories t
where t.closed_at is null
  and t.ends_at >= now()
order by t.starts_at;

-- จบไฟล์  อย่าเคาะบรรทัดใหม่ต่อท้ายบรรทัดนี้ ->
