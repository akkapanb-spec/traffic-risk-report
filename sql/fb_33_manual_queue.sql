-- ============================================================
-- รายการเนื้อหาพร้อมโพสต์ด้วยมือ  สำหรับหน้าเจ้าหน้าที่
-- ============================================================
-- ห้ามมีปีกกาในไฟล์นี้ ตัวแก้ไขจะเติมแบ็กสแลชให้
-- ก่อนกด Run ให้ลบสิ่งที่ตัวแก้ไขเติมไว้ท้ายสุดออกก่อน เป็นดอลลาร์ตามด้วยเลขศูนย์
--
-- ------------------------------------------------------------
-- ทำไมต้องมีของแบบนี้
-- ------------------------------------------------------------
-- วัดมาหนึ่งสัปดาห์ โพสต์ของระบบแปดกว่าอัน ลองสี่รูปแบบเนื้อหา
-- ได้ยอดเข้าถึง 0 ถึง 1 ทุกครั้ง  ส่วนโพสต์ที่เจ้าหน้าที่พิมพ์เองได้พันกว่าถึงสามพันทุกครั้ง
-- ตัวแปรเดียวที่ต่างกันคือโพสต์นั้นมาจากแอปหรือมาจากคน
-- ไม่มีหน้าตั้งค่าไหนปรับได้ และแก้ด้วยโค้ดฝั่งเราไม่ได้
--
-- ฟังก์ชันนี้จึงไม่ส่งอะไรออกไปเลย แค่เตรียมเนื้อหาให้ครบ
-- แล้วให้เจ้าหน้าที่ก๊อปไปวางที่หน้าเพจเอง ใช้เวลาไม่ถึงนาทีต่อโพสต์
-- ได้ความเร็วและความถูกต้องของระบบ กับการมองเห็นของโพสต์ที่คนพิมพ์เอง
--
-- ------------------------------------------------------------
-- ข้อความต้องตรงกับที่ตัวส่งอัตโนมัติใช้ทุกตัวอักษร
-- ------------------------------------------------------------
-- ไม่อย่างนั้นสิ่งที่ขึ้นเพจด้วยมือกับสิ่งที่ขึ้นด้วยระบบจะเป็นคนละเรื่อง
-- แล้วเวลามีปัญหาจะไล่ไม่ได้ว่าเกิดจากอะไร
-- จึงเรียกตัวสร้างข้อความตัวเดียวกันทั้งหมด ไม่ได้เขียนขึ้นใหม่

create or replace function fb_manual_queue(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $fn$
declare
  v_err   jsonb;
  v_rows  jsonb := jsonb_build_array();
  v_site  text;
  v_txt   text;
  v_ref   text;
  v_body  jsonb;
  a       record;
  d       record;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;

  v_site := coalesce((select val #>> array[]::text[] from bs_settings where key = 'publicSiteUrl'), '');

  -- ------------------------------------------------------------
  -- หนึ่ง  สรุปสถานการณ์รายสัปดาห์  มีให้โพสต์เสมอ
  -- ------------------------------------------------------------
  v_ref := to_char(now() at time zone 'Asia/Bangkok', 'IYYY') || '-' ||
           to_char(now() at time zone 'Asia/Bangkok', 'IW') || '-7';
  v_txt := fb_weekly_text(7);
  if coalesce(v_txt, '') <> '' then
    v_rows := v_rows || jsonb_build_array(jsonb_build_object(
      'kind',  'weekly',
      'ref',   v_ref,
      'label', 'สรุปสถานการณ์รายสัปดาห์',
      'text',  v_txt,
      'image', fb_card_url('weekly', '7'),
      'posted', exists (select 1 from fb_sent s where s.kind = 'weekly' and s.ref_id = v_ref)));
  end if;

  -- ------------------------------------------------------------
  -- สอง  จุดอุบัติเหตุซ้ำ  อ่านผลที่คำนวณไว้แล้ว ไม่คำนวณใหม่
  -- ------------------------------------------------------------
  select body into v_body from line_hotspot_cache where id = 1;
  if v_body is not null and coalesce((v_body ->> 'found')::int, 0) > 0
     and coalesce(v_body ->> 'text', '') <> '' then
    v_ref := 'hs-' || to_char(now() at time zone 'Asia/Bangkok', 'IYYY-IW');
    v_rows := v_rows || jsonb_build_array(jsonb_build_object(
      'kind',  'hotspot',
      'ref',   v_ref,
      'label', 'จุดอุบัติเหตุซ้ำ',
      'text',  v_body ->> 'text',
      'image', null,
      'posted', exists (select 1 from fb_sent s where s.kind = 'hotspot' and s.ref_id = v_ref)));
  end if;

  -- ------------------------------------------------------------
  -- สาม  ประกาศจุดเลี่ยงที่ยังมีผลอยู่
  -- ------------------------------------------------------------
  for a in
    select t.id, t.images, t.title from traffic_advisories t
     where t.closed_at is null and t.ends_at >= now()
     order by t.starts_at desc
     limit 10
  loop
    v_txt := line_adv_item_text(a.id);
    if coalesce(v_txt, '') = '' then continue; end if;

    v_txt := '🚧 แจ้งจุดที่ควรหลีกเลี่ยง' || chr(10) || chr(10) || v_txt || chr(10) || chr(10) ||
      'โปรดวางแผนการเดินทาง และใช้ความระมัดระวังเมื่อผ่านบริเวณดังกล่าว';
    if v_site <> '' then
      v_txt := v_txt || chr(10) || chr(10) || 'ดูรูปภาพและรายละเอียดทั้งหมด' || chr(10) || v_site;
    end if;
    v_txt := v_txt || chr(10) || chr(10) || '👮 ด้วยความปรารถนาดี น้องจราจรชอนตะวัน';

    v_rows := v_rows || jsonb_build_array(jsonb_build_object(
      'kind',  'advisory',
      'ref',   a.id::text,
      'label', 'จุดเลี่ยง  ' || left(coalesce(a.title, ''), 40),
      'text',  v_txt,
      'image', nullif(btrim(coalesce(a.images ->> 0, '')), ''),
      'posted', exists (select 1 from fb_sent s
                         where s.kind = 'advisory' and s.ref_id = a.id::text)));
  end loop;

  -- ------------------------------------------------------------
  -- สี่  ผู้เสียชีวิตใน 48 ชั่วโมง เฉพาะรายที่เสียชีวิตในที่เกิดเหตุ
  -- ------------------------------------------------------------
  for d in
    select d2.id from deaths d2
     where d2.incident_datetime >= now() - interval '48 hours'
       and coalesce(btrim(d2.col_g), '') = 'เสียชีวิตที่เกิดเหตุ'
     order by d2.incident_datetime desc
     limit 5
  loop
    v_txt := line_msg_death(d.id);
    if coalesce(v_txt, '') = '' then continue; end if;

    v_rows := v_rows || jsonb_build_array(jsonb_build_object(
      'kind',  'death',
      'ref',   d.id::text,
      'label', 'อุบัติเหตุเสียชีวิต รหัส ' || d.id,
      'text',  v_txt,
      'image', fb_card_url('death', d.id::text),
      'posted', exists (select 1 from fb_sent s
                         where s.kind = 'death' and s.ref_id = d.id::text)));
  end loop;

  return jsonb_build_object('success', true, 'rows', v_rows);
end;
$fn$;

grant execute on function fb_manual_queue(text) to anon;

-- ตรวจ  เรียกด้วยโทเคนมั่วแล้วต้องถูกปฏิเสธ
select fb_manual_queue('ไม่ใช่โทเคนจริง') as ลองเรียกแบบไม่มีสิทธิ์;

-- จบไฟล์  อย่าเคาะบรรทัดใหม่ต่อท้ายบรรทัดนี้ ->
