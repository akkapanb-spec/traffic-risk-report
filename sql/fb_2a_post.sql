-- ============================================================
-- โพสต์เฟซบุ๊กอัตโนมัติ  ไฟล์ 2a  ตัวยิงโพสต์ขึ้นเพจ
-- ============================================================
-- รันเรียงตามเลขหน้าไฟล์  1a 1b 1c 2a 2b 2c  ห้ามข้าม
--
-- ห้ามมีปีกกาในไฟล์นี้ ตัวแก้ไขจะเติมแบ็กสแลชให้
-- ก่อนกด Run ให้ลบสิ่งที่ตัวแก้ไขเติมไว้ท้ายสุดออกก่อน เป็นดอลลาร์ตามด้วยเลขศูนย์
--
-- นี่คือชิ้นเดียวที่ส่งของออกไปข้างนอกจริง ที่เหลือแค่เตรียมข้อความ
--
-- ยังโพสต์ไม่ได้จนกว่าจะครบสามอย่าง
--   หนึ่ง  วางโทเคนในตู้นิรภัยแล้ว
--   สอง   เลขเพจถูกต้อง
--   สาม   เปลี่ยน fbEnabled เป็นจริง
-- ขาดข้อไหนข้อหนึ่ง ฟังก์ชันจะคืนค่าว่าไม่ได้โพสต์ และไม่มีอะไรออกไป
--
-- ข้อควรรู้ที่สำคัญที่สุดของไฟล์นี้
-- pg_net ยิงคำขอแล้วไม่รอคำตอบ คืนมาแค่เลขคำขอ แล้วไปส่งเบื้องหลัง
-- คำว่าโพสต์แล้วในตาราง fb_sent จึงแปลว่ายิงคำขอออกไปแล้วเท่านั้น
-- ไม่ได้แปลว่าเฟซบุ๊กรับเรียบร้อย ผลจริงต้องอ่านด้วยไฟล์ 2b
-- จุดนี้เคยทำให้เข้าใจผิดมาแล้วกับไลน์ ว่าส่งสำเร็จทุกครั้งทั้งที่ไม่ได้ส่ง

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
  v_req := net.http_post(
    url     := v_url,
    headers := jsonb_build_object('Content-Type', 'application/json',
                                  'Authorization', 'Bearer ' || v_tok),
    body    := v_body);

  update fb_sent
     set req_id = v_req,
         note   = 'ยิงคำขอแล้ว รอคำตอบ'
   where kind = p_kind and ref_id = p_ref;

  return jsonb_build_object('success', true, 'posted', true,
    'request_id', v_req, 'kind', p_kind, 'ref', p_ref,
    'message', 'ยิงคำขอแล้ว ผลจริงอ่านด้วยไฟล์ 2b');
end;
$fn$;

-- หน้าเว็บสาธารณะต้องเรียกไม่ได้เด็ดขาด  ไม่งั้นใครก็โพสต์ในนามเพจ สภ. ได้
revoke execute on function fb_post(text, text, text, text) from public, anon, authenticated;

-- ตรวจ  ต้องได้ฟังก์ชัน 1 และลองเรียกแล้วต้องขึ้นว่าปิดอยู่
-- ที่ต้องขึ้นว่าปิดอยู่ เพราะ fbEnabled ยังเป็นเท็จ ถ้าขึ้นอย่างอื่นแปลว่าสวิตช์ไม่ทำงาน
select
  (select count(*) from pg_proc where proname = 'fb_post')            as ฟังก์ชัน,
  fb_post('probe', 'probe-1', 'ข้อความทดสอบ ยังไม่ควรถูกส่ง')          as ลองเรียกตอนปิดอยู่;

-- จบไฟล์  อย่าเคาะบรรทัดใหม่ต่อท้ายบรรทัดนี้ ->