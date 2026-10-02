-- ============================================================
-- ย้ายลิงก์ออกจากตัวโพสต์  ไฟล์ 31c จาก 3  ตัวสานต่อ เพิ่มขั้นคอมเมนต์
-- ============================================================
-- รันหลัง 31a และ 31b
--
-- ห้ามมีปีกกาในไฟล์นี้ ตัวแก้ไขจะเติมแบ็กสแลชให้
-- ก่อนกด Run ให้ลบสิ่งที่ตัวแก้ไขเติมไว้ท้ายสุดออกก่อน เป็นดอลลาร์ตามด้วยเลขศูนย์
--
-- เส้นทางเต็มตอนนี้มีสามขั้น
--   photo    อัปโหลดรูปแบบยังไม่เผยแพร่ รอรหัสรูป
--   feed     สร้างโพสต์บนวอลล์ รอรหัสโพสต์
--   comment  เอาลิงก์ไปใส่เป็นคอมเมนต์แรก รอผล
--
-- โพสต์ที่ไม่มีลิงก์จะข้ามขั้นคอมเมนต์ไปจบที่ done เลย
-- ถ้าคอมเมนต์ล้มเหลว โพสต์ยังอยู่ครบ แค่ไม่มีลิงก์ใต้โพสต์
-- จึงไม่ถือเป็นความล้มเหลวของทั้งงาน ปิดงานเป็น done แล้วจดเหตุไว้

create or replace function fb_finish_posts(p_max int default 5)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $fn$
declare
  s       record;
  r       record;
  v_page  text;
  v_ver   text;
  v_tok   text;
  v_photo text;
  v_post  text;
  v_req   bigint;
  v_made  int := 0;
  v_done  int := 0;
  v_cmt   int := 0;
  v_fail  int := 0;
begin
  v_page := coalesce((select val #>> array[]::text[] from bs_settings where key = 'fbPageId'), '');
  v_ver  := coalesce((select val #>> array[]::text[] from bs_settings where key = 'fbApiVersion'), 'v21.0');

  -- ขั้นที่หนึ่ง  รอรหัสรูป
  for s in
    select * from fb_sent where stage = 'photo' order by posted_at limit greatest(1, p_max)
  loop
    select * into r from net._http_response where id = s.req_id;

    if not found then
      if s.posted_at < now() - interval '10 minutes' then
        update fb_sent set stage = 'failed',
               note = 'ไม่ได้รับคำตอบของการอัปโหลดรูปภายในสิบนาที' where id = s.id;
        v_fail := v_fail + 1;
      end if;
      continue;
    end if;

    v_photo := case when r.status_code = 200 then (r.content::jsonb) ->> 'id' else null end;

    if coalesce(v_photo, '') = '' then
      update fb_sent set stage = 'failed',
             note = 'อัปโหลดรูปไม่สำเร็จ  ' || left(coalesce(r.content, r.error_msg, ''), 200)
       where id = s.id;
      v_fail := v_fail + 1;
      continue;
    end if;

    v_tok := fb_token();

    v_req := net.http_post(
      url     := 'https://graph.facebook.com/' || v_ver || '/' || v_page || '/feed',
      headers := jsonb_build_object('Content-Type', 'application/json',
                                    'Authorization', 'Bearer ' || v_tok),
      body    := jsonb_build_object(
                   'message', s.pending_text,
                   'attached_media', jsonb_build_array(
                     jsonb_build_object('media_fbid', v_photo))),
      timeout_milliseconds := 30000);

    update fb_sent
       set stage = 'feed', photo_id = v_photo, req2_id = v_req,
           note  = 'สร้างโพสต์บนวอลล์แล้ว รอคำตอบ'
     where id = s.id;
    v_made := v_made + 1;
  end loop;

  -- ขั้นที่สอง  รอรหัสโพสต์ แล้วส่งลิงก์ไปเป็นคอมเมนต์
  for s in
    select * from fb_sent where stage = 'feed' order by posted_at limit greatest(1, p_max)
  loop
    select * into r from net._http_response where id = coalesce(s.req2_id, s.req_id);

    if not found then
      if s.posted_at < now() - interval '10 minutes' then
        update fb_sent set stage = 'done', note = 'ไม่ได้รับคำตอบของโพสต์ ให้ไปดูที่เพจ'
         where id = s.id;
      end if;
      continue;
    end if;

    if r.status_code <> 200 then
      update fb_sent set stage = 'done', ok = false,
             note = 'โพสต์ไม่สำเร็จ  ' || left(coalesce(r.content, r.error_msg, ''), 200)
       where id = s.id;
      v_fail := v_fail + 1;
      continue;
    end if;

    v_post := (r.content::jsonb) ->> 'id';

    if coalesce(btrim(coalesce(s.pending_links, '')), '') = '' then
      update fb_sent set stage = 'done', ok = true, post_id = v_post,
             note = 'ขึ้นวอลล์แล้ว ไม่มีลิงก์ให้คอมเมนต์' where id = s.id;
      v_done := v_done + 1;
      continue;
    end if;

    v_tok := fb_token();

    v_req := net.http_post(
      url     := 'https://graph.facebook.com/' || v_ver || '/' || v_post || '/comments',
      headers := jsonb_build_object('Content-Type', 'application/json',
                                    'Authorization', 'Bearer ' || v_tok),
      body    := jsonb_build_object('message',
                   'รายละเอียดและแผนที่' || chr(10) || s.pending_links),
      timeout_milliseconds := 30000);

    update fb_sent
       set stage = 'comment', ok = true, post_id = v_post, req3_id = v_req,
           note  = 'ขึ้นวอลล์แล้ว กำลังใส่ลิงก์ในคอมเมนต์'
     where id = s.id;
    v_cmt := v_cmt + 1;
  end loop;

  -- ขั้นที่สาม  รอผลคอมเมนต์
  for s in
    select * from fb_sent where stage = 'comment' order by posted_at limit greatest(1, p_max)
  loop
    select * into r from net._http_response where id = s.req3_id;

    if not found then
      if s.posted_at < now() - interval '10 minutes' then
        update fb_sent set stage = 'done', note = 'ขึ้นวอลล์แล้ว ไม่ทราบผลของคอมเมนต์'
         where id = s.id;
      end if;
      continue;
    end if;

    update fb_sent
       set stage = 'done',
           note  = case when r.status_code = 200 then 'ขึ้นวอลล์แล้ว พร้อมลิงก์ในคอมเมนต์'
                        else 'ขึ้นวอลล์แล้ว แต่คอมเมนต์ไม่สำเร็จ  '
                             || left(coalesce(r.content, r.error_msg, ''), 150) end
     where id = s.id;
    v_done := v_done + 1;
  end loop;

  return jsonb_build_object('success', true,
    'สร้างโพสต์', v_made, 'ใส่คอมเมนต์', v_cmt, 'ปิดงาน', v_done, 'ไม่สำเร็จ', v_fail);
end;
$fn$;

revoke execute on function fb_finish_posts(int) from public, anon, authenticated;

-- ตรวจ  ไม่ควรมีอะไรค้างอยู่
select
  coalesce(stage, 'ไม่ระบุ') as ขั้น,
  count(*)                   as จำนวน
from fb_sent
group by 1
order by 2 desc;

-- จบไฟล์  อย่าเคาะบรรทัดใหม่ต่อท้ายบรรทัดนี้ ->
