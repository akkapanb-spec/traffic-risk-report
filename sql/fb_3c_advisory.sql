-- ============================================================
-- โพสต์เฟซบุ๊กอัตโนมัติ  ไฟล์ 3c  โพสต์จุดที่ควรหลีกเลี่ยงและเส้นทางเลี่ยง
-- ============================================================
-- รันได้หลังไฟล์ 2a ผ่านแล้วเท่านั้น เพราะเรียก fb_post
--
-- ห้ามมีปีกกาในไฟล์นี้ ตัวแก้ไขจะเติมแบ็กสแลชให้
-- ก่อนกด Run ให้ลบสิ่งที่ตัวแก้ไขเติมไว้ท้ายสุดออกก่อน เป็นดอลลาร์ตามด้วยเลขศูนย์
--
-- ข้อความมาจาก line_adv_item_text ตัวเดียวกับที่ไลน์ใช้
-- รูปมาจากช่องแนบรูปในฟอร์มของผู้ดูแล เก็บเป็นลิงก์สาธารณะอยู่แล้ว
-- จึงส่งลิงก์ให้เฟซบุ๊กได้ตรง ๆ ไม่ต้องอัปโหลดซ้ำ
-- มีรูปจะโพสต์เป็นรูป ไม่มีรูปจะโพสต์เป็นข้อความ ทั้งสองแบบใช้ได้
--
-- โพสต์เฉพาะประกาศที่กำลังมีผลอยู่ ยังไม่ถูกปิด และยังไม่เคยโพสต์
-- ประกาศที่หมดอายุไปแล้วจะไม่ถูกโพสต์ย้อนหลัง เพราะโพสต์ไปก็ทำให้คนเข้าใจผิด
--
-- ท้ายไฟล์จดประกาศเก่าทั้งหมดว่าจัดการแล้ว ด้วยเหตุผลเดียวกับไฟล์ 3a

create or replace function fb_send_advisories(p_max int default 3)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $fn$
declare
  a      record;
  v_txt  text;
  v_img  text;
  v_site text;
  v_r    jsonb;
  v_sent int := 0;
begin
  if coalesce((select (val #>> array[]::text[])::boolean from bs_settings
                where key = 'fbEnabled'), false) is not true then
    return jsonb_build_object('success', true, 'sent', 0, 'message', 'ปิดอยู่');
  end if;

  v_site := coalesce((select val #>> array[]::text[] from bs_settings where key = 'publicSiteUrl'), '');

  for a in
    select t.id, t.images from traffic_advisories t
     where t.closed_at is null
       and t.starts_at <= now()
       and t.ends_at   >= now()
       and not exists (select 1 from fb_sent s
                        where s.kind = 'advisory' and s.ref_id = t.id::text)
     order by t.created_at desc
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

  return jsonb_build_object('success', true, 'sent', v_sent);
end;
$fn$;

revoke execute on function fb_send_advisories(int) from public, anon, authenticated;

-- ============================================================
-- กันของค้างเก่า  ห้ามตัดออกด้วยเหตุผลเดียวกับไฟล์ 3a
-- ============================================================
insert into fb_sent(kind, ref_id, ok, note)
select 'advisory', id::text, true, 'มีอยู่ก่อนเปิดใช้เฟซบุ๊ก ไม่โพสต์ย้อนหลัง'
  from traffic_advisories
on conflict (kind, ref_id) do nothing;

-- ตรวจ  ลองเรียกได้ผลเป็น ปิดอยู่ เพราะ fbEnabled ยังเป็นเท็จ
select
  (select count(*) from pg_proc where proname = 'fb_send_advisories')  as ฟังก์ชัน,
  (select count(*) from traffic_advisories)                            as ประกาศทั้งหมด,
  (select count(*) from fb_sent where kind = 'advisory')               as จดไว้แล้ว,
  fb_send_advisories(3)                                                as ลองเรียก;

-- จบไฟล์  อย่าเคาะบรรทัดใหม่ต่อท้ายบรรทัดนี้ ->