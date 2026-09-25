-- ============================================================
-- ขยายเวลารอคำตอบจากเฟซบุ๊ก  ห้าวินาทีไม่พอ
-- ============================================================
-- ห้ามมีปีกกาในไฟล์นี้ ตัวแก้ไขจะเติมแบ็กสแลชให้
-- ก่อนกด Run ให้ลบสิ่งที่ตัวแก้ไขเติมไว้ท้ายสุดออกก่อน เป็นดอลลาร์ตามด้วยเลขศูนย์
--
-- ------------------------------------------------------------
-- สาเหตุที่เจอ
-- ------------------------------------------------------------
-- คำขอที่ยิงไปตอนทดสอบ ตอบกลับมาว่า Timeout of 5000 ms reached
-- ไม่ใช่โทเคนผิด ไม่ใช่เลขเพจผิด แต่รอไม่ทัน
--
-- ห้าวินาทีคือค่าตั้งต้นของ pg_net ซึ่งพอสำหรับคำขอที่ปลายทางตอบทันที
-- แต่โพสต์รูปของเฟซบุ๊กไม่ใช่แบบนั้น  เราส่งลิงก์รูปไปให้
-- เฟซบุ๊กต้องวิ่งไปดึงรูปจากลิงก์นั้นก่อน แล้วค่อยตอบเรา
-- ตัววาดภาพของเราใช้เวลาราวห้าวินาทีครึ่งต่อหนึ่งใบ วัดไว้ตอนทดสอบ
-- บวกเวลาที่เฟซบุ๊กใช้เอง จึงเกินห้าวินาทีแน่นอนทุกครั้ง
--
-- แปลว่าโพสต์ที่มีรูปจะไม่มีวันสำเร็จเลยด้วยค่าเดิม
-- และจะเป็นแบบนี้กับทุกช่องทาง ทั้งข่าวเสียชีวิต จุดเลี่ยง และสรุปรายสัปดาห์
--
-- ------------------------------------------------------------
-- แก้อย่างไร
-- ------------------------------------------------------------
-- บอก pg_net ให้รอสามสิบวินาที  เปลี่ยนที่เดียวในฟังก์ชัน fb_post
-- ที่เหลือของฟังก์ชันเหมือนเดิมทุกบรรทัด
--
-- สามสิบวินาทีไม่ได้ทำให้อะไรช้าลง เพราะเป็นเพดานเวลารอ ไม่ใช่เวลาที่ใช้จริง
-- ถ้าเฟซบุ๊กตอบใน 6 วินาที ก็จบที่ 6 วินาที

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

  -- จองที่ในตารางก่อนยิง  ถ้าจองไม่ได้แปลว่าเรื่องนี้เคยโพสต์ไปแล้ว
  -- จองก่อนยิงไม่ใช่หลังยิง เพราะถ้ายิงก่อนแล้วค่อยจด คำสั่งที่ทำงานพร้อมกันสองรอบ
  -- จะยิงซ้ำทั้งคู่ก่อนที่ใครจะได้จด ซึ่งบนเพจสาธารณะคือโพสต์ซ้ำให้คนทั้งเพจเห็น
  insert into fb_sent(kind, ref_id, note)
  values (p_kind, p_ref, 'จองที่ไว้ ยังไม่ได้ยิง')
  on conflict (kind, ref_id) do nothing;

  if not found then
    return jsonb_build_object('success', true, 'posted', false, 'message', 'โพสต์เรื่องนี้ไปแล้ว');
  end if;

  v_page := coalesce((select val #>> array[]::text[] from bs_settings where key = 'fbPageId'), '');
  v_ver  := coalesce((select val #>> array[]::text[] from bs_settings where key = 'fbApiVersion'), 'v21.0');
  v_tok  := fb_token();

  if v_page = '' or coalesce(v_tok, '') = '' then
    -- ลบที่จองไว้ทิ้ง ไม่งั้นเรื่องนี้จะถูกกันไว้ตลอดกาลทั้งที่ยังไม่เคยโพสต์
    delete from fb_sent where kind = p_kind and ref_id = p_ref;
    return jsonb_build_object('success', false, 'posted', false,
      'message', 'ยังไม่ได้ตั้งเลขเพจ หรือยังไม่ได้วางโทเคนในตู้นิรภัย');
  end if;

  -- มีรูปให้โพสต์เป็นรูป ไม่มีรูปให้โพสต์เป็นข้อความ
  -- รูปส่งเป็นลิงก์ ไม่ต้องอัปโหลดไฟล์ เพราะรูปในระบบนี้อยู่บนที่เก็บสาธารณะอยู่แล้ว
  if coalesce(trim(p_image), '') <> '' then
    v_url  := 'https://graph.facebook.com/' || v_ver || '/' || v_page || '/photos';
    v_body := jsonb_build_object('message', p_text, 'url', trim(p_image));
  else
    v_url  := 'https://graph.facebook.com/' || v_ver || '/' || v_page || '/feed';
    v_body := jsonb_build_object('message', p_text);
  end if;

  -- โทเคนไปในหัวคำขอ ไม่ไปในที่อยู่เว็บ  ที่อยู่เว็บถูกจดไว้ในบันทึกของหลายชั้น
  --
  -- เวลารอสามสิบวินาที  บรรทัดที่เพิ่มเข้ามาในไฟล์นี้คือบรรทัดนี้บรรทัดเดียว
  -- ค่าตั้งต้นห้าวินาทีทำให้โพสต์ที่มีรูปหมดเวลาทุกครั้ง
  -- เพราะเฟซบุ๊กต้องไปดึงรูปจากตัววาดภาพของเราก่อนจะตอบกลับ
  v_req := net.http_post(
    url     := v_url,
    headers := jsonb_build_object('Content-Type', 'application/json',
                                  'Authorization', 'Bearer ' || v_tok),
    body    := v_body,
    timeout_milliseconds := 30000);

  update fb_sent
     set req_id = v_req,
         note   = 'ยิงคำขอแล้ว รอคำตอบ'
   where kind = p_kind and ref_id = p_ref;

  return jsonb_build_object('success', true, 'posted', true,
    'request_id', v_req, 'kind', p_kind, 'ref', p_ref,
    'message', 'ยิงคำขอแล้ว ผลจริงอ่านด้วยไฟล์ 17');
end;
$fn$;

revoke execute on function fb_post(text, text, text, text) from public, anon, authenticated;

-- ==========================================================
-- ล้างแถวของสัปดาห์นี้ทิ้ง เพื่อให้ทดสอบซ้ำได้
-- ==========================================================
-- รอบที่แล้วหมดเวลาไป ไม่มีอะไรขึ้นเพจ แต่แถวจองที่ยังค้างอยู่
-- ถ้าไม่ลบ การทดสอบครั้งต่อไปจะได้คำตอบว่าโพสต์เรื่องนี้ไปแล้ว

delete from fb_sent
 where kind = 'weekly'
   and ref_id = to_char(now() at time zone 'Asia/Bangkok', 'IYYY') || '-' ||
                to_char(now() at time zone 'Asia/Bangkok', 'IW') || '-7';

-- ตรวจ  ยังไม่มีอะไรถูกส่งออกไปจากไฟล์นี้
select
  (select count(*) from fb_sent where kind = 'weekly')        as แถวสรุปรายสัปดาห์ที่เหลือ,
  (select val #>> array[]::text[] from bs_settings where key = 'fbEnabled') as สวิตช์,
  'รันไฟล์ 16 อีกครั้งเพื่อทดสอบใหม่'                          as ขั้นต่อไป;

-- จบไฟล์  อย่าเคาะบรรทัดใหม่ต่อท้ายบรรทัดนี้ ->
