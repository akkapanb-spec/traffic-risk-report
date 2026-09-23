-- ============================================================
-- โพสต์เฟซบุ๊กอัตโนมัติ  ไฟล์ 5c จาก 3  ตัวส่งสรุปรายสัปดาห์
-- ============================================================
-- รันหลัง 5a และหลัง fb_4_weekly_data เท่านั้น
--
-- ห้ามมีปีกกาในไฟล์นี้ ตัวแก้ไขจะเติมแบ็กสแลชให้
-- ก่อนกด Run ให้ลบสิ่งที่ตัวแก้ไขเติมไว้ท้ายสุดออกก่อน เป็นดอลลาร์ตามด้วยเลขศูนย์
--
-- ตัวสร้างข้อความสรุปมีมาตั้งแต่ไฟล์ 1c แต่ยังไม่เคยมีใครเรียกใช้
-- ไฟล์นี้คือตัวที่เรียก  พร้อมแนบภาพการ์ดสรุปไปด้วย
--
-- กันส่งซ้ำด้วยเลขสัปดาห์ตามปฏิทิน  สัปดาห์หนึ่งขึ้นเพจได้โพสต์เดียว
-- ต่อให้ตั้งเวลาให้ทำงานทุกชั่วโมง fb_post ก็จะบอกว่าโพสต์เรื่องนี้ไปแล้ว
-- ตัวกันอยู่ในตาราง fb_sent ไม่ได้อยู่ที่ความถี่ของตัวตั้งเวลา
-- ซึ่งต่างจากแจ้งเตือนจุดเสี่ยงในไลน์ที่กันด้วยความถี่อย่างเดียวแล้วส่งซ้ำเอง

create or replace function fb_send_weekly(p_days int default 7)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $fn$
declare
  v_txt text;
  v_ref text;
  v_now timestamp;
  v_r   jsonb;
begin
  if coalesce((select (val #>> array[]::text[])::boolean from bs_settings
                where key = 'fbEnabled'), false) is not true then
    return jsonb_build_object('success', true, 'sent', 0, 'message', 'ปิดอยู่');
  end if;

  if p_days is null or p_days < 1 or p_days > 92 then
    p_days := 7;
  end if;

  v_now := now() at time zone 'Asia/Bangkok';
  v_ref := to_char(v_now, 'IYYY') || '-' || to_char(v_now, 'IW') || '-' || p_days::text;

  v_txt := fb_weekly_text(p_days);
  if coalesce(btrim(coalesce(v_txt, '')), '') = '' then
    return jsonb_build_object('success', false, 'sent', 0, 'message', 'สร้างข้อความไม่ได้');
  end if;

  v_r := fb_post('weekly', v_ref, v_txt, fb_card_url('weekly', p_days::text));

  return jsonb_build_object('success', true,
    'sent', case when coalesce((v_r ->> 'posted')::boolean, false) then 1 else 0 end,
    'ref', v_ref, 'result', v_r);
end;
$fn$;

revoke execute on function fb_send_weekly(int) from public, anon, authenticated;

-- ตรวจ  ดูรหัสสัปดาห์ที่ใช้กันส่งซ้ำ และดูว่าสัปดาห์นี้ส่งไปหรือยัง
-- ยังไม่มีอะไรถูกส่งออกไป บรรทัดนี้แค่อ่าน
select
  to_char(now() at time zone 'Asia/Bangkok', 'IYYY') || '-' ||
  to_char(now() at time zone 'Asia/Bangkok', 'IW')  || '-7'          as รหัสสัปดาห์นี้,
  fb_card_url('weekly', '7')                                         as ภาพที่จะแนบ,
  (select count(*) from fb_sent where kind = 'weekly')               as เคยส่งไปแล้วกี่สัปดาห์;

-- จบไฟล์  อย่าเคาะบรรทัดใหม่ต่อท้ายบรรทัดนี้ ->
