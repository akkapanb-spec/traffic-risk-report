-- ============================================================
-- โพสต์สองจังหวะ  ไฟล์ 23c จาก 3  ตัวสานต่อจังหวะสอง
-- ============================================================
-- รันหลัง 23a และ 23b
--
-- ห้ามมีปีกกาในไฟล์นี้ ตัวแก้ไขจะเติมแบ็กสแลชให้
-- ก่อนกด Run ให้ลบสิ่งที่ตัวแก้ไขเติมไว้ท้ายสุดออกก่อน เป็นดอลลาร์ตามด้วยเลขศูนย์
--
-- ------------------------------------------------------------
-- หน้าที่
-- ------------------------------------------------------------
-- เดินดูแถวที่ค้างอยู่ในขั้น photo  อ่านคำตอบของการอัปโหลดรูป
-- ได้รหัสรูปแล้วก็สร้างโพสต์บนวอลล์ โดยแนบรหัสรูปนั้นไปกับข้อความ
-- แล้วเลื่อนแถวไปขั้น feed เพื่อรอผลของโพสต์
--
-- แถวที่อยู่ขั้น feed แล้ว จะอ่านผลแล้วปิดงานเป็น done
--
-- ------------------------------------------------------------
-- กันกรณีที่คำตอบไม่มาสักที
-- ------------------------------------------------------------
-- ถ้าค้างในขั้น photo เกินสิบนาที ให้เลิกรอและจดว่าไม่สำเร็จ
-- ไม่ลองใหม่เอง เพราะเราไม่รู้ว่ารูปขึ้นไปแล้วหรือยัง
-- แต่รูปที่ยังไม่เผยแพร่ไม่ใช่โพสต์ การลองใหม่ด้วยมือจึงปลอดภัย
-- ล้างด้วย fb_clear_for_retry แล้วให้ตัวส่งหยิบไปทำใหม่รอบหน้า

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
  v_req   bigint;
  v_made  int := 0;
  v_done  int := 0;
  v_fail  int := 0;
begin
  v_page := coalesce((select val #>> array[]::text[] from bs_settings where key = 'fbPageId'), '');
  v_ver  := coalesce((select val #>> array[]::text[] from bs_settings where key = 'fbApiVersion'), 'v21.0');

  -- ขั้นแรก  แถวที่รอรหัสรูปอยู่
  for s in
    select * from fb_sent
     where stage = 'photo'
     order by posted_at
     limit greatest(1, p_max)
  loop
    select * into r from net._http_response where id = s.req_id;

    if not found then
      -- คำตอบยังไม่มา  รอรอบหน้า เว้นแต่รอนานเกินไปแล้ว
      if s.posted_at < now() - interval '10 minutes' then
        update fb_sent
           set stage = 'failed',
               note  = 'ไม่ได้รับคำตอบของการอัปโหลดรูปภายในสิบนาที'
         where id = s.id;
        v_fail := v_fail + 1;
      end if;
      continue;
    end if;

    v_photo := case when r.status_code = 200
                    then (r.content::jsonb) ->> 'id' else null end;

    if coalesce(v_photo, '') = '' then
      update fb_sent
         set stage = 'failed',
             note  = 'อัปโหลดรูปไม่สำเร็จ  ' || left(coalesce(r.content, r.error_msg, ''), 200)
       where id = s.id;
      v_fail := v_fail + 1;
      continue;
    end if;

    v_tok := fb_token();

    -- จังหวะสอง  โพสต์บนวอลล์พร้อมแนบรูป
    -- attached_media เป็นรายการของวัตถุ สร้างด้วย jsonb_build_array กับ jsonb_build_object
    -- เขียนเป็นปีกกาตรง ๆ ไม่ได้ในไฟล์ของโปรเจกต์นี้
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
       set stage    = 'feed',
           photo_id = v_photo,
           req2_id  = v_req,
           note     = 'สร้างโพสต์บนวอลล์แล้ว รอคำตอบ'
     where id = s.id;
    v_made := v_made + 1;
  end loop;

  -- ขั้นสอง  แถวที่รอผลของโพสต์อยู่
  for s in
    select * from fb_sent
     where stage = 'feed'
     order by posted_at
     limit greatest(1, p_max)
  loop
    select * into r from net._http_response
     where id = coalesce(s.req2_id, s.req_id);

    if not found then
      if s.posted_at < now() - interval '10 minutes' then
        update fb_sent set stage = 'done', note = 'ไม่ได้รับคำตอบของโพสต์ ให้ไปดูที่เพจ'
         where id = s.id;
      end if;
      continue;
    end if;

    if r.status_code = 200 then
      update fb_sent
         set stage   = 'done',
             ok      = true,
             post_id = (r.content::jsonb) ->> 'id',
             note    = 'ขึ้นวอลล์แล้ว'
       where id = s.id;
      v_done := v_done + 1;
    else
      update fb_sent
         set stage = 'done',
             ok    = false,
             note  = 'โพสต์ไม่สำเร็จ  ' || left(coalesce(r.content, r.error_msg, ''), 200)
       where id = s.id;
      v_fail := v_fail + 1;
    end if;
  end loop;

  return jsonb_build_object('success', true,
    'สร้างโพสต์', v_made, 'ปิดงาน', v_done, 'ไม่สำเร็จ', v_fail);
end;
$fn$;

revoke execute on function fb_finish_posts(int) from public, anon, authenticated;

-- ==========================================================
-- ตั้งเวลาทุกนาที  งานเบามาก ถ้าไม่มีอะไรค้างก็จบทันที
-- ==========================================================
-- ทุกนาทีเพราะนี่คือเวลาที่โพสต์ต้องรอเพิ่มก่อนขึ้นวอลล์
-- ข่าวผู้เสียชีวิตเดิมช้าได้ถึงสิบนาทีอยู่แล้ว บวกอีกหนึ่งนาทีไม่เปลี่ยนอะไร

select cron.schedule('fb-finish', '* * * * *', 'select fb_finish_posts(5)');

-- ตรวจ  ต้องเห็นงานชื่อ fb-finish และยังไม่มีแถวค้าง
select
  (select count(*) from fb_sent where stage = 'photo')  as ค้างรอรหัสรูป,
  (select count(*) from fb_sent where stage = 'feed')   as ค้างรอผลโพสต์,
  (select count(*) from fb_sent where stage = 'failed') as ไม่สำเร็จ,
  (select count(*) from cron.job where jobname = 'fb-finish') as ตั้งเวลาแล้ว;

-- จบไฟล์  อย่าเคาะบรรทัดใหม่ต่อท้ายบรรทัดนี้ ->
