-- ============================================================
-- โพสต์สองจังหวะ  ไฟล์ 23b จาก 3  จังหวะแรก อัปโหลดรูปแบบยังไม่เผยแพร่
-- ============================================================
-- รันหลัง 23a เท่านั้น เพราะใช้ช่องที่เพิ่งเพิ่มไป
--
-- ห้ามมีปีกกาในไฟล์นี้ ตัวแก้ไขจะเติมแบ็กสแลชให้
-- ก่อนกด Run ให้ลบสิ่งที่ตัวแก้ไขเติมไว้ท้ายสุดออกก่อน เป็นดอลลาร์ตามด้วยเลขศูนย์
--
-- ------------------------------------------------------------
-- ของเดิมกับของใหม่ต่างกันตรงไหน
-- ------------------------------------------------------------
-- โพสต์ที่ไม่มีรูป  เหมือนเดิมทุกอย่าง ยิงเข้าวอลล์คำขอเดียวจบ
-- โพสต์ที่มีรูป     เปลี่ยนไป เดิมยิงเข้าช่องทางรูปภาพแล้วจบ ได้เรื่องราวที่ไม่ขึ้นวอลล์
--                   ตอนนี้ยิงอัปโหลดรูปแบบยังไม่เผยแพร่ก่อน แล้วปล่อยค้างไว้
--                   ให้ fb_finish_posts มาสานต่อในนาทีถัดไป
--
-- ------------------------------------------------------------
-- เรื่องที่ต้องรู้ถ้าจังหวะสองไม่สำเร็จ
-- ------------------------------------------------------------
-- รูปที่อัปโหลดไว้แบบยังไม่เผยแพร่ จะค้างอยู่ในคลังรูปที่ไม่เผยแพร่ของเพจ
-- คนทั่วไปมองไม่เห็น ไม่มีใครเดือดร้อน แค่รกอยู่หลังบ้าน
-- และสำคัญกว่านั้นคือมันไม่ใช่โพสต์ จึงยิงจังหวะแรกซ้ำได้โดยไม่เกิดโพสต์ซ้ำ
--
-- การจองที่ในตารางยังทำก่อนยิงเหมือนเดิม ด้วยเหตุผลเดิม
-- สองคำสั่งที่ทำงานพร้อมกันจะยิงซ้ำทั้งคู่ก่อนที่ใครจะได้จด

create or replace function fb_post(
  p_kind  text,
  p_ref   text,
  p_text  text,
  p_image text default null
) returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $fn$
declare
  v_page text;
  v_ver  text;
  v_tok  text;
  v_url  text;
  v_body jsonb;
  v_req  bigint;
begin
  if coalesce((select (val #>> array[]::text[])::boolean from bs_settings
                where key = 'fbEnabled'), false) is not true then
    return jsonb_build_object('success', true, 'posted', false, 'message', 'ปิดอยู่');
  end if;

  if coalesce(trim(p_text), '') = '' then
    return jsonb_build_object('success', false, 'posted', false, 'message', 'ไม่มีข้อความ');
  end if;

  insert into fb_sent(kind, ref_id, note, stage)
  values (p_kind, p_ref, 'จองที่ไว้ ยังไม่ได้ยิง', 'new')
  on conflict (kind, ref_id) do nothing;

  if not found then
    return jsonb_build_object('success', true, 'posted', false, 'message', 'โพสต์เรื่องนี้ไปแล้ว');
  end if;

  v_page := coalesce((select val #>> array[]::text[] from bs_settings where key = 'fbPageId'), '');
  v_ver  := coalesce((select val #>> array[]::text[] from bs_settings where key = 'fbApiVersion'), 'v21.0');
  v_tok  := fb_token();

  if v_page = '' or coalesce(v_tok, '') = '' then
    delete from fb_sent where kind = p_kind and ref_id = p_ref;
    return jsonb_build_object('success', false, 'posted', false,
      'message', 'ยังไม่ได้ตั้งเลขเพจ หรือยังไม่ได้วางโทเคนในตู้นิรภัย');
  end if;

  if coalesce(trim(p_image), '') = '' then
    -- ไม่มีรูป  ยิงเข้าวอลล์ตรง ๆ จบในคำขอเดียว
    v_req := net.http_post(
      url     := 'https://graph.facebook.com/' || v_ver || '/' || v_page || '/feed',
      headers := jsonb_build_object('Content-Type', 'application/json',
                                    'Authorization', 'Bearer ' || v_tok),
      body    := jsonb_build_object('message', p_text),
      timeout_milliseconds := 30000);

    update fb_sent
       set req_id = v_req, stage = 'feed', note = 'ยิงโพสต์ข้อความแล้ว รอคำตอบ'
     where kind = p_kind and ref_id = p_ref;

    return jsonb_build_object('success', true, 'posted', true, 'request_id', v_req,
      'kind', p_kind, 'ref', p_ref, 'message', 'ยิงโพสต์ข้อความแล้ว');
  end if;

  -- มีรูป  จังหวะแรก อัปโหลดรูปแบบยังไม่เผยแพร่
  -- published เป็นเท็จ คือหัวใจของไฟล์นี้ ถ้าเป็นจริงจะกลับไปได้เรื่องราวที่ไม่ขึ้นวอลล์
  v_url  := 'https://graph.facebook.com/' || v_ver || '/' || v_page || '/photos';
  v_body := jsonb_build_object('url', trim(p_image), 'published', false);

  v_req := net.http_post(
    url     := v_url,
    headers := jsonb_build_object('Content-Type', 'application/json',
                                  'Authorization', 'Bearer ' || v_tok),
    body    := v_body,
    timeout_milliseconds := 30000);

  update fb_sent
     set req_id       = v_req,
         stage        = 'photo',
         pending_text = p_text,
         note         = 'อัปโหลดรูปแล้ว รอรหัสรูปเพื่อสร้างโพสต์'
   where kind = p_kind and ref_id = p_ref;

  return jsonb_build_object('success', true, 'posted', true, 'request_id', v_req,
    'kind', p_kind, 'ref', p_ref,
    'message', 'อัปโหลดรูปแล้ว โพสต์จะขึ้นวอลล์ภายในหนึ่งนาที');
end;
$fn$;

revoke execute on function fb_post(text, text, text, text) from public, anon, authenticated;

-- ตรวจ  ยังไม่มีอะไรถูกส่งออกไปจากไฟล์นี้
select
  (select count(*) from fb_sent where stage = 'photo') as ค้างรอรหัสรูป,
  (select count(*) from fb_sent where stage = 'feed')  as ค้างรอผลโพสต์,
  'รัน 23c ต่อเพื่อสร้างตัวสานต่อ'                      as ขั้นต่อไป;

-- จบไฟล์  อย่าเคาะบรรทัดใหม่ต่อท้ายบรรทัดนี้ ->
