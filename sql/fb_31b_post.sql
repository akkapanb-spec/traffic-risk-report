-- ============================================================
-- ย้ายลิงก์ออกจากตัวโพสต์  ไฟล์ 31b จาก 3  ตัวส่ง
-- ============================================================
-- รันหลัง 31a เท่านั้น
--
-- ห้ามมีปีกกาในไฟล์นี้ ตัวแก้ไขจะเติมแบ็กสแลชให้
-- ก่อนกด Run ให้ลบสิ่งที่ตัวแก้ไขเติมไว้ท้ายสุดออกก่อน เป็นดอลลาร์ตามด้วยเลขศูนย์
--
-- ที่เปลี่ยนจาก 23b มีจุดเดียว  แยกลิงก์ออกจากข้อความก่อนส่ง
-- ตัวโพสต์ไม่มีลิงก์เลย ลิงก์ถูกเก็บไว้รอไปเป็นคอมเมนต์แรก ซึ่งไฟล์ 31c จัดการ
--
-- ฝั่งไลน์ไม่กระทบเลย ยังได้ข้อความเต็มพร้อมลิงก์เหมือนเดิมทุกตัวอักษร
-- เพราะการตัดเกิดขึ้นที่ fb_post ไม่ได้ไปแก้ตัวสร้างข้อความที่ใช้ร่วมกัน

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
  v_page  text;
  v_ver   text;
  v_tok   text;
  v_split jsonb;
  v_body  text;
  v_links text;
  v_req   bigint;
begin
  if coalesce((select (val #>> array[]::text[])::boolean from bs_settings
                where key = 'fbEnabled'), false) is not true then
    return jsonb_build_object('success', true, 'posted', false, 'message', 'ปิดอยู่');
  end if;

  if coalesce(trim(p_text), '') = '' then
    return jsonb_build_object('success', false, 'posted', false, 'message', 'ไม่มีข้อความ');
  end if;

  v_split := fb_strip_links(p_text);
  v_body  := v_split ->> 'text';
  v_links := v_split ->> 'links';

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
    v_req := net.http_post(
      url     := 'https://graph.facebook.com/' || v_ver || '/' || v_page || '/feed',
      headers := jsonb_build_object('Content-Type', 'application/json',
                                    'Authorization', 'Bearer ' || v_tok),
      body    := jsonb_build_object('message', v_body),
      timeout_milliseconds := 30000);

    update fb_sent
       set req_id        = v_req,
           stage         = 'feed',
           pending_links = nullif(v_links, ''),
           note          = 'ยิงโพสต์ข้อความแล้ว รอคำตอบ'
     where kind = p_kind and ref_id = p_ref;

    return jsonb_build_object('success', true, 'posted', true, 'request_id', v_req,
      'kind', p_kind, 'ref', p_ref, 'message', 'ยิงโพสต์ข้อความแล้ว');
  end if;

  -- มีรูป  จังหวะแรก อัปโหลดรูปแบบยังไม่เผยแพร่
  v_req := net.http_post(
    url     := 'https://graph.facebook.com/' || v_ver || '/' || v_page || '/photos',
    headers := jsonb_build_object('Content-Type', 'application/json',
                                  'Authorization', 'Bearer ' || v_tok),
    body    := jsonb_build_object('url', trim(p_image), 'published', false),
    timeout_milliseconds := 30000);

  update fb_sent
     set req_id        = v_req,
         stage         = 'photo',
         pending_text  = v_body,
         pending_links = nullif(v_links, ''),
         note          = 'อัปโหลดรูปแล้ว รอรหัสรูปเพื่อสร้างโพสต์'
   where kind = p_kind and ref_id = p_ref;

  return jsonb_build_object('success', true, 'posted', true, 'request_id', v_req,
    'kind', p_kind, 'ref', p_ref,
    'message', 'อัปโหลดรูปแล้ว โพสต์จะขึ้นวอลล์ภายในหนึ่งนาที');
end;
$fn$;

revoke execute on function fb_post(text, text, text, text) from public, anon, authenticated;

-- ตรวจ  ยังไม่มีอะไรถูกส่งออกไปจากไฟล์นี้
select 'พร้อมแล้ว รัน 31c ต่อ' as ขั้นต่อไป;

-- จบไฟล์  อย่าเคาะบรรทัดใหม่ต่อท้ายบรรทัดนี้ ->
