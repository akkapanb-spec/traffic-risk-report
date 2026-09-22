-- ============================================================
-- โพสต์เฟซบุ๊กอัตโนมัติ  ไฟล์ 5  ต่อภาพอินโฟกราฟิกเข้ากับตัวส่ง
-- ============================================================
-- รันได้หลังไฟล์ 2a 3a และ fb_4_weekly_data ผ่านแล้ว
--
-- ห้ามมีปีกกาในไฟล์นี้ ตัวแก้ไขจะเติมแบ็กสแลชให้
-- ก่อนกด Run ให้ลบสิ่งที่ตัวแก้ไขเติมไว้ท้ายสุดออกก่อน เป็นดอลลาร์ตามด้วยเลขศูนย์
--
-- ------------------------------------------------------------
-- ภาพมาจากไหน
-- ------------------------------------------------------------
-- ภาพไม่ได้เก็บเป็นไฟล์ไว้ล่วงหน้า แต่วาดสดตอนที่เฟซบุ๊กมาขอ
-- ฟังก์ชันขอบชื่อ fbcard เป็นคนวาด  เอาแบบการ์ดที่ออกแบบไว้มาเขียนข้อมูลจริงลงไป
-- ฐานข้อมูลส่งให้เฟซบุ๊กแค่ที่อยู่ของภาพ ไม่ได้ส่งตัวภาพ
--
-- เฟซบุ๊กจะมาดึงภาพเอง จึงต้องปิดการตรวจโทเคนของฟังก์ชัน fbcard
-- ถ้าไม่ปิด เฟซบุ๊กจะได้ข้อความปฏิเสธแทนภาพ แล้วโพสต์จะล้มทั้งโพสต์
--
-- ------------------------------------------------------------
-- ถ้าวาดภาพไม่สำเร็จจะเกิดอะไร
-- ------------------------------------------------------------
-- fb_post ส่งที่อยู่ภาพไปที่ปลายทาง photos ของเฟซบุ๊ก
-- ถ้าเฟซบุ๊กดึงภาพไม่ได้ ทั้งโพสต์จะไม่ขึ้น ไม่ใช่ขึ้นแบบไม่มีภาพ
-- ตั้ง fbCardUrl เป็นค่าว่างเมื่อใดก็ตามที่ตัววาดภาพมีปัญหา
-- แล้วระบบจะกลับไปโพสต์เป็นข้อความล้วนทันที โดยไม่ต้องแก้ฟังก์ชันอะไรเลย

-- ==========================================================
-- 1  ที่อยู่ของตัววาดภาพ
-- ==========================================================

insert into bs_settings(key, val) values
  ('fbCardUrl', to_jsonb('https://ftpruljwwsmvipfcedyk.supabase.co/functions/v1/fbcard'::text))
on conflict (key) do nothing;

-- ==========================================================
-- 2  ตัวประกอบที่อยู่ภาพ
-- ==========================================================
-- คืนค่าว่างเมื่อยังไม่ได้ตั้งที่อยู่ไว้  ผู้เรียกจะได้โพสต์เป็นข้อความล้วน

create or replace function fb_card_url(p_kind text, p_arg text)
returns text
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_base text;
begin
  v_base := coalesce((select val #>> array[]::text[] from bs_settings where key = 'fbCardUrl'), '');
  if btrim(v_base) = '' then
    return null;
  end if;

  if p_kind = 'death' then
    return btrim(v_base) || '?kind=death&id=' || p_arg;
  elsif p_kind = 'weekly' then
    return btrim(v_base) || '?kind=weekly&days=' || p_arg;
  end if;

  return null;
end;
$fn$;

revoke execute on function fb_card_url(text, text) from public, anon, authenticated;

-- ==========================================================
-- 3  ตัวส่งข่าวเสียชีวิต  เพิ่มภาพเข้าไป
-- ==========================================================
-- เนื้อความเหมือนเดิมทุกตัวอักษร เพราะยังเรียก line_msg_death ตัวเดิม
-- ที่เพิ่มคือพารามิเตอร์ตัวที่สี่ของ fb_post

create or replace function fb_send_deaths(p_max int default 3, p_hours int default 48)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $fn$
declare
  d      record;
  v_txt  text;
  v_r    jsonb;
  v_sent int := 0;
  v_skip int := 0;
begin
  if coalesce((select (val #>> array[]::text[])::boolean from bs_settings
                where key = 'fbEnabled'), false) is not true then
    return jsonb_build_object('success', true, 'sent', 0, 'message', 'ปิดอยู่');
  end if;

  for d in
    select d2.id, d2.col_g from deaths d2
     where not exists (select 1 from fb_sent s
                        where s.kind = 'death' and s.ref_id = d2.id::text)
       and d2.incident_datetime >= now() - make_interval(hours => greatest(1, p_hours))
     order by d2.incident_datetime desc nulls last, d2.id desc
     limit greatest(1, p_max)
  loop
    if coalesce(btrim(d.col_g), '') <> 'เสียชีวิตที่เกิดเหตุ' then
      insert into fb_sent(kind, ref_id, ok, note)
      values ('death', d.id::text, true, 'ข้าม ไม่ได้เสียชีวิตในที่เกิดเหตุ')
      on conflict (kind, ref_id) do nothing;
      v_skip := v_skip + 1;
      continue;
    end if;

    v_txt := line_msg_death(d.id);
    if coalesce(v_txt, '') = '' then
      continue;
    end if;

    v_r := fb_post('death', d.id::text, v_txt, fb_card_url('death', d.id::text));
    if coalesce((v_r ->> 'posted')::boolean, false) then
      v_sent := v_sent + 1;
    end if;
  end loop;

  return jsonb_build_object('success', true, 'sent', v_sent, 'skipped', v_skip);
end;
$fn$;

revoke execute on function fb_send_deaths(int, int) from public, anon, authenticated;

-- ==========================================================
-- 4  ตัวส่งสรุปรายสัปดาห์  ยังไม่เคยมี สร้างใหม่ที่นี่
-- ==========================================================
-- กันส่งซ้ำด้วยเลขสัปดาห์ตามปฏิทิน  สัปดาห์หนึ่งโพสต์ได้ครั้งเดียว
-- ต่อให้ตั้งเวลาให้ทำงานทุกชั่วโมงก็ยังได้สัปดาห์ละโพสต์เดียว

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

-- ==========================================================
-- 5  ตรวจ  ดูที่อยู่ภาพที่จะส่งให้เฟซบุ๊ก โดยยังไม่มีอะไรถูกส่งออกไป
-- ==========================================================
-- เอาที่อยู่ในช่อง ภาพข่าวเสียชีวิตรายล่าสุด ไปเปิดในเบราว์เซอร์ได้เลย
-- ถ้าเห็นการ์ดแปลว่าตัววาดภาพพร้อมแล้ว ถ้าเห็นข้อความแดงแปลว่ายังไม่พร้อม

select
  (select val #>> array[]::text[] from bs_settings where key = 'fbCardUrl') as ที่อยู่ตัววาดภาพ,
  fb_card_url('death', (select max(id)::text from deaths))                  as ภาพข่าวเสียชีวิตรายล่าสุด,
  fb_card_url('weekly', '7')                                                as ภาพสรุปรายสัปดาห์,
  (select to_char(now() at time zone 'Asia/Bangkok', 'IYYY') || '-' ||
          to_char(now() at time zone 'Asia/Bangkok', 'IW'))                 as สัปดาห์นี้;

-- จบไฟล์  อย่าเคาะบรรทัดใหม่ต่อท้ายบรรทัดนี้ ->
