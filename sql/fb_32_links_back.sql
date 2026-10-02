-- ============================================================
-- เอาลิงก์กลับเข้าตัวโพสต์  เพราะคอมเมนต์ถูกปฏิเสธ 403
-- ============================================================
-- ห้ามมีปีกกาในไฟล์นี้ ตัวแก้ไขจะเติมแบ็กสแลชให้
-- ก่อนกด Run ให้ลบสิ่งที่ตัวแก้ไขเติมไว้ท้ายสุดออกก่อน เป็นดอลลาร์ตามด้วยเลขศูนย์
--
-- ------------------------------------------------------------
-- สิ่งที่เกิดขึ้นกับประกาศน้ำท่วมสองใบเมื่อ 15:30
-- ------------------------------------------------------------
--   ผลรูป 200       อัปโหลดรูปสำเร็จ
--   ผลโพสต์ 200     โพสต์ขึ้นวอลล์สำเร็จ
--   ผลคอมเมนต์ 403  เฟซบุ๊กปฏิเสธการคอมเมนต์
--
-- 403 คือไม่มีสิทธิ์ การคอมเมนต์ในนามเพจต้องใช้สิทธิ์ pages_manage_engagement
-- ซึ่งโทเคนของเรายังไม่มี มีแต่สิทธิ์สำหรับโพสต์
--
-- ผลคือประกาศน้ำท่วมสองใบนั้นออกไปโดย ไม่มีลิงก์แผนที่เลย
-- ผมตัดลิงก์ออกจากตัวโพสต์แล้วย้ายไปคอมเมนต์ แต่คอมเมนต์ไม่สำเร็จ ลิงก์จึงหายไปเฉย ๆ
-- เตือนน้ำท่วมที่ไม่มีพิกัด แย่กว่าเตือนน้ำท่วมที่คนเห็นน้อย
--
-- ------------------------------------------------------------
-- แก้ตรงนี้ก่อน แล้วค่อยว่ากันเรื่องการมองเห็น
-- ------------------------------------------------------------
-- เพิ่มสวิตช์ fbLinksInComment  ตั้งต้นเป็นเท็จ คือใส่ลิงก์ในตัวโพสต์เหมือนเดิม
-- เนื้อหาครบเหมือนก่อนหน้านี้ทุกตัวอักษร ไม่มีอะไรหายอีก
--
-- ถ้าวันหลังขอสิทธิ์ pages_manage_engagement ได้แล้ว และอยากลองอีกครั้ง
-- เปิดสวิตช์ด้วยคำสั่งเดียว ไม่ต้องแก้ฟังก์ชัน
--   update bs_settings set val = 'true'::jsonb where key = 'fbLinksInComment';
--
-- สวิตช์นี้ยังไม่ควรเปิดจนกว่าจะเห็นผลคอมเมนต์เป็น 200 สักครั้ง

insert into bs_settings(key, val) values ('fbLinksInComment', 'false'::jsonb)
on conflict (key) do nothing;

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
  v_move  boolean;
  v_req   bigint;
begin
  if coalesce((select (val #>> array[]::text[])::boolean from bs_settings
                where key = 'fbEnabled'), false) is not true then
    return jsonb_build_object('success', true, 'posted', false, 'message', 'ปิดอยู่');
  end if;

  if coalesce(trim(p_text), '') = '' then
    return jsonb_build_object('success', false, 'posted', false, 'message', 'ไม่มีข้อความ');
  end if;

  v_move := coalesce((select (val #>> array[]::text[])::boolean from bs_settings
                       where key = 'fbLinksInComment'), false);

  if v_move then
    v_split := fb_strip_links(p_text);
    v_body  := v_split ->> 'text';
    v_links := v_split ->> 'links';
  else
    -- ลิงก์อยู่ในตัวโพสต์เหมือนเดิม  ไม่มีอะไรถูกตัดออก
    v_body  := p_text;
    v_links := '';
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
    v_req := net.http_post(
      url     := 'https://graph.facebook.com/' || v_ver || '/' || v_page || '/feed',
      headers := jsonb_build_object('Content-Type', 'application/json',
                                    'Authorization', 'Bearer ' || v_tok),
      body    := jsonb_build_object('message', v_body),
      timeout_milliseconds := 30000);

    update fb_sent
       set req_id = v_req, stage = 'feed', pending_links = nullif(v_links, ''),
           note   = 'ยิงโพสต์ข้อความแล้ว รอคำตอบ'
     where kind = p_kind and ref_id = p_ref;

    return jsonb_build_object('success', true, 'posted', true, 'request_id', v_req,
      'kind', p_kind, 'ref', p_ref, 'message', 'ยิงโพสต์ข้อความแล้ว');
  end if;

  v_req := net.http_post(
    url     := 'https://graph.facebook.com/' || v_ver || '/' || v_page || '/photos',
    headers := jsonb_build_object('Content-Type', 'application/json',
                                  'Authorization', 'Bearer ' || v_tok),
    body    := jsonb_build_object('url', trim(p_image), 'published', false),
    timeout_milliseconds := 30000);

  update fb_sent
     set req_id = v_req, stage = 'photo', pending_text = v_body,
         pending_links = nullif(v_links, ''),
         note = 'อัปโหลดรูปแล้ว รอรหัสรูปเพื่อสร้างโพสต์'
   where kind = p_kind and ref_id = p_ref;

  return jsonb_build_object('success', true, 'posted', true, 'request_id', v_req,
    'kind', p_kind, 'ref', p_ref,
    'message', 'อัปโหลดรูปแล้ว โพสต์จะขึ้นวอลล์ภายในหนึ่งนาที');
end;
$fn$;

revoke execute on function fb_post(text, text, text, text) from public, anon, authenticated;

-- ตรวจ  สวิตช์ต้องเป็น false และตัวอย่างข้อความต้องมีลิงก์อยู่ครบ
select
  (select val #>> array[]::text[] from bs_settings where key = 'fbLinksInComment') as ย้ายลิงก์ไปคอมเมนต์,
  case when position('http' in line_adv_item_text((select max(id) from traffic_advisories))) > 0
       then 'มีลิงก์อยู่ในข้อความ ถูกต้อง' else 'ไม่มีลิงก์ ผิดปกติ' end          as ตรวจข้อความ;

-- จบไฟล์  อย่าเคาะบรรทัดใหม่ต่อท้ายบรรทัดนี้ ->
