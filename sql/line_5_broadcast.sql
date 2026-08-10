-- ============================================================
-- LINE Bot — ส่งแบบ broadcast โดยไม่ต้องรู้ id ของใคร
-- ============================================================
-- ไฟล์ที่ 5  ต้องรัน line_1 ถึง line_4 มาก่อน
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
--
-- ทำไมต้องมีไฟล์นี้
--   การส่งเข้ากลุ่มต้องรู้ group id ซึ่งได้มาทางเดียวคือให้บอทตอบในกลุ่ม
--   ซึ่งต้องมี Edge Function + webhook ทำงานครบก่อน
--   ตอนนี้ส่วนนั้นยังติดอยู่ แต่การแจ้งเตือนไม่ควรต้องรอ
--
--   LINE มี broadcast ที่ส่งหาทุกคนที่เพิ่มบอทเป็นเพื่อน โดยไม่ต้องระบุผู้รับ
--   จึงข้ามข้อจำกัดนั้นได้ทั้งหมด — ไม่ต้องใช้ Edge Function ไม่ต้องใช้ webhook
--
-- เมื่อไรที่ webhook ใช้ได้แล้ว ค่อยเพิ่มกลุ่มเข้า line_targets ตามปกติ
-- แล้วปิดแถว broadcast นี้ — ทั้งสองแบบอยู่ร่วมกันได้ ไม่ต้องรื้ออะไร
-- ============================================================

set search_path = public, extensions;

-- ============================================================
-- 1) ให้ line_push รู้จักการส่งแบบ broadcast
-- ============================================================
-- ใช้ target_id พิเศษว่า 'BROADCAST' เป็นสัญญาณ
-- ทำแบบนี้เพื่อให้ทุกอย่างที่เขียนไว้แล้วใช้ต่อได้ทั้งหมด
-- ทั้ง line_broadcast, line_send_daily, line_send_new_deaths, line_send_serious
-- ไม่ต้องแก้สักตัว และตัวกันส่งซ้ำก็ยังทำงานเหมือนเดิม
create or replace function line_push(p_target text, p_text text)
returns bigint
language plpgsql security definer set search_path = public, extensions as $line_push$
declare v_token text; v_body jsonb; v_text text; v_url text;
begin
  v_token := line_token();
  if coalesce(v_token, '') = '' then
    raise exception 'ยังไม่ได้ตั้ง token — เรียก line_set_token(...) ก่อน';
  end if;
  if coalesce(btrim(p_target), '') = '' or coalesce(btrim(p_text), '') = '' then
    return null;
  end if;

  -- LINE รับข้อความละไม่เกิน 5000 ตัวอักษร เกินแล้วตีกลับทั้งฉบับ
  v_text := left(p_text, 4900);
  if length(p_text) > 4900 then v_text := v_text || chr(10) || '… (ข้อความยาวเกิน ตัดบางส่วนออก)'; end if;

  if btrim(p_target) = 'BROADCAST' then
    -- ปลายทางคือทุกคนที่เพิ่มบอทเป็นเพื่อน จึงไม่มีช่อง to
    v_url  := 'https://api.line.me/v2/bot/message/broadcast';
    v_body := jsonb_build_object(
                'messages', jsonb_build_array(jsonb_build_object('type', 'text', 'text', v_text)));
  else
    v_url  := 'https://api.line.me/v2/bot/message/push';
    v_body := jsonb_build_object('to', btrim(p_target),
                'messages', jsonb_build_array(jsonb_build_object('type', 'text', 'text', v_text)));
  end if;

  return net.http_post(
    url     := v_url,
    headers := jsonb_build_object('Content-Type', 'application/json',
                                  'Authorization', 'Bearer ' || v_token),
    body    := v_body);
end $line_push$;

revoke execute on function line_push(text, text) from public, anon, authenticated;

-- ============================================================
-- 2) เพิ่มปลายทางแบบ broadcast
-- ============================================================
insert into line_targets (label, target_id, target_type, note)
values ('ทุกคนที่เพิ่มบอทเป็นเพื่อน', 'BROADCAST', 'broadcast',
        'ใช้ระหว่างที่ยังตั้ง webhook ไม่สำเร็จ เมื่อได้ group id แล้วให้ปิดแถวนี้')
on conflict (target_id) do nothing;

-- ============================================================
-- ตรวจผลหลังรัน
-- ============================================================
-- 1) ต้องมีปลายทาง BROADCAST อยู่ 1 แถว และ enabled = true
--    select label, target_id, enabled from line_targets;
--
-- 2) ยิงทดสอบจริง — เพิ่มบอทเป็นเพื่อนก่อน แล้วรันบรรทัดนี้
--    select line_push('BROADCAST', 'ทดสอบระบบแจ้งเตือน ' || now()::text);
--
-- 3) ดูผลจริงจาก LINE (pg_net ทำงานเบื้องหลัง รอสัก 5 วินาทีค่อยดู)
--    200 = สำเร็จ · 401 = token ผิด · 400 = ยังไม่มีใครเพิ่มบอทเป็นเพื่อน
--    select id, status_code, left(content, 200) as ผลลัพธ์
--      from net._http_response order by id desc limit 3;
--
-- 4) ทดสอบข้อความจริงทั้งชุด
--    select line_broadcast('daily',   line_msg_acc_day(),     'ทดสอบวัน-'   || now()::text);
--    select line_broadcast('weekly',  line_msg_acc_week(),    'ทดสอบสัปดาห์-' || now()::text);
--    select line_broadcast('serious', line_msg_serious_day(), 'ทดสอบร้ายแรง-' || now()::text);
--
-- ============================================================
-- เมื่อ webhook ใช้ได้แล้วในอนาคต
-- ============================================================
-- เพิ่มกลุ่มตามปกติ แล้วปิด broadcast เพื่อไม่ให้ได้ข้อความซ้ำสองทาง
--   insert into line_targets (label, target_id, target_type)
--   values ('กลุ่มงานจราจร', 'Cxxxxxxxx...', 'group');
--   update line_targets set enabled = false where target_id = 'BROADCAST';
