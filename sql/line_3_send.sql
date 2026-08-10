-- ============================================================
-- LINE Bot — ต่อท่อส่งจริง และตั้งเวลา
-- ============================================================
-- ไฟล์ที่ 3 จาก 3  ต้องรัน line_1_tables.sql และ line_2_messages.sql มาก่อน
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
--
-- ไฟล์นี้ส่งข้อความออก LINE ได้จริง แต่ยังไม่ส่งทันทีที่รัน
-- เพราะยังไม่มี token และยังไม่มีปลายทาง — ต้องทำอีก 3 ขั้นตอนท้ายไฟล์
--
-- ทำไมไม่ต้องมี Edge Function สำหรับส่ง
--   pg_cron ตั้งเวลาได้ในฐานข้อมูล และ pg_net ยิง HTTP ออกไปได้เอง
--   การส่งออกจึงจบในฐานข้อมูลทั้งหมด ไม่ต้อง deploy อะไรเลย
--   Edge Function จำเป็นเฉพาะขา "รับ" ข้อความที่คนพิมพ์เข้ามา
-- ============================================================

set search_path = public, extensions;

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- ============================================================
-- 1) เก็บ token ไว้ใน Vault
-- ============================================================
-- ห้ามเขียน token ลงในคำสั่ง cron หรือในตัวฟังก์ชันตรง ๆ
-- ใครอ่านตาราง cron.job หรือ pg_proc ได้ ก็เอา token ไปยิงข้อความ
-- เข้ากลุ่มในนามหน่วยได้ทันที
--
-- ฟังก์ชันนี้ตั้งใจไม่ให้ anon เรียก — เรียกได้จาก SQL Editor เท่านั้น
create or replace function line_set_token(p_token text)
returns text
language plpgsql security definer set search_path = public, extensions, vault as $line_set_token$
declare v_id uuid;
begin
  if coalesce(btrim(p_token), '') = '' then
    return 'ไม่ได้ใส่ token';
  end if;

  select id into v_id from vault.secrets where name = 'line_channel_access_token';
  if v_id is null then
    perform vault.create_secret(btrim(p_token), 'line_channel_access_token',
                                'LINE Messaging API — ระบบแจ้งข้อมูลจุดเสี่ยงอุบัติเหตุ');
    return 'บันทึก token ใหม่แล้ว';
  else
    perform vault.update_secret(v_id, btrim(p_token));
    return 'อัปเดต token เดิมแล้ว';
  end if;
end $line_set_token$;

create or replace function line_token()
returns text
language sql stable security definer set search_path = public, extensions, vault as $line_token$
  select decrypted_secret from vault.decrypted_secrets where name = 'line_channel_access_token';
$line_token$;

-- ============================================================
-- 2) ส่งข้อความหนึ่งฉบับไปหนึ่งปลายทาง
-- ============================================================
-- pg_net ทำงานแบบไม่รอผล คืนเลขคำขอมาให้ แล้วไปส่งเบื้องหลัง
-- แปลว่า "ส่งแล้ว" ในตาราง line_sent หมายถึงยิงคำขอออกไปแล้ว
-- ไม่ได้แปลว่า LINE รับเรียบร้อย ผลจริงต้องดูที่ net._http_response
-- (มีคำสั่งตรวจให้ท้ายไฟล์) — จุดนี้ต้องรู้ไว้ ไม่งั้นจะเข้าใจผิดว่าส่งสำเร็จทุกครั้ง
create or replace function line_push(p_target text, p_text text)
returns bigint
language plpgsql security definer set search_path = public, extensions as $line_push$
declare v_token text; v_body jsonb; v_text text;
begin
  v_token := line_token();
  if coalesce(v_token, '') = '' then
    raise exception 'ยังไม่ได้ตั้ง token — เรียก line_set_token(''...'') ก่อน';
  end if;
  if coalesce(btrim(p_target), '') = '' or coalesce(btrim(p_text), '') = '' then
    return null;
  end if;

  -- LINE รับข้อความละไม่เกิน 5000 ตัวอักษร เกินแล้วตีกลับทั้งฉบับ
  -- ตัดเองดีกว่าปล่อยให้ตีกลับ เพราะข้อความยาวเกิดขึ้นได้จริงเมื่อมีเหตุหลายราย
  v_text := left(p_text, 4900);
  if length(p_text) > 4900 then v_text := v_text || chr(10) || '… (ข้อความยาวเกิน ตัดบางส่วนออก)'; end if;

  v_body := jsonb_build_object('to', p_target,
              'messages', jsonb_build_array(jsonb_build_object('type', 'text', 'text', v_text)));

  return net.http_post(
    url     := 'https://api.line.me/v2/bot/message/push',
    headers := jsonb_build_object('Content-Type', 'application/json',
                                  'Authorization', 'Bearer ' || v_token),
    body    := v_body);
end $line_push$;

-- ส่งไปทุกปลายทางที่เปิดรับเรื่องนั้น
create or replace function line_broadcast(p_kind text, p_text text, p_ref text default null)
returns int
language plpgsql security definer set search_path = public, extensions as $line_broadcast$
declare t record; v_n int := 0; v_req bigint;
begin
  if coalesce(btrim(p_text), '') = '' then return 0; end if;

  for t in
    select target_id from line_targets
     where enabled
       and case p_kind when 'death'  then want_death
                       when 'daily'  then want_daily
                       when 'weekly' then want_weekly
                       else true end
  loop
    -- ส่งซ้ำเรื่องเดิมไปปลายทางเดิมไม่ได้ กัน cron เดินซ้ำแล้วยิงซ้ำ
    if p_ref is not null and exists (
      select 1 from line_sent where kind = p_kind and ref_id = p_ref and target_id = t.target_id
    ) then continue; end if;

    v_req := line_push(t.target_id, p_text);
    insert into line_sent (kind, ref_id, target_id, ok, detail)
    values (p_kind, p_ref, t.target_id, v_req is not null, 'net_request_id=' || coalesce(v_req::text, 'null'));
    v_n := v_n + 1;
  end loop;

  return v_n;
end $line_broadcast$;

-- ============================================================
-- 3) ผู้เสียชีวิตรายใหม่
-- ============================================================
-- ตาราง deaths ไม่มีคอลัมน์ "บันทึกเมื่อไหร่" มีแต่วันเวลาเกิดเหตุ
-- จะถามว่า "รายไหนเพิ่งบันทึก" ตรง ๆ ไม่ได้ จึงถามว่า "รายไหนยังไม่เคยแจ้ง" แทน
-- โดยต้องหมายรายที่มีอยู่แล้วว่าแจ้งไปแล้วตั้งแต่ตอนติดตั้ง (ดูข้อ 6)
--
-- p_max กันไว้อีกชั้น เผื่อมีการนำเข้าข้อมูลย้อนหลังทีละมาก ๆ
-- ซึ่งระบบนี้เคยทำมาแล้ว (accidents_part1..8) ถ้าไม่กัน กลุ่มจะได้ข้อความรัวเป็นร้อย
create or replace function line_send_new_deaths(p_max int default 3)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $line_send_new_deaths$
declare
  d record; v_sent int := 0; v_left int; v_txt text;
begin
  select count(*) into v_left from deaths d
   where not exists (select 1 from line_sent s where s.kind = 'death' and s.ref_id = d.id::text);

  if v_left = 0 then return jsonb_build_object('success', true, 'sent', 0, 'left', 0); end if;

  for d in
    select id from deaths d2
     where not exists (select 1 from line_sent s where s.kind = 'death' and s.ref_id = d2.id::text)
     order by incident_datetime desc nulls last, id desc
     limit greatest(1, p_max)
  loop
    v_txt := line_msg_death(d.id);
    if v_txt is not null then
      perform line_broadcast('death', v_txt, d.id::text);
      v_sent := v_sent + 1;
    else
      -- สร้างข้อความไม่ได้ ก็ต้องหมายว่าจัดการแล้ว ไม่งั้นจะวนพยายามใหม่ทุกรอบตลอดไป
      insert into line_sent (kind, ref_id, target_id, ok, detail)
      values ('death', d.id::text, null, false, 'สร้างข้อความไม่ได้')
      on conflict do nothing;
    end if;
  end loop;

  -- เหลือค้างเยอะแปลว่ามีการนำเข้าย้อนหลัง บอกไว้ครั้งเดียว ดีกว่ายิงทีละราย
  if v_left > v_sent then
    perform line_broadcast('death',
      'ℹ️ มีผู้เสียชีวิตที่บันทึกเข้าระบบเพิ่มอีก ' || (v_left - v_sent) || ' ราย' ||
      chr(10) || 'ระบบจะทยอยแจ้งรอบละ ' || greatest(1, p_max) || ' ราย หรือดูทั้งหมดได้ที่หน้าสถิติผู้เสียชีวิต',
      'bulk-' || to_char(now(), 'YYYYMMDDHH24MI'));
  end if;

  return jsonb_build_object('success', true, 'sent', v_sent, 'left', v_left - v_sent);
end $line_send_new_deaths$;

-- ============================================================
-- 4) สรุปประจำวัน / ประจำสัปดาห์
-- ============================================================
create or replace function line_send_daily()
returns jsonb language plpgsql security definer set search_path = public, extensions as $line_send_daily$
declare v_day date := line_today() - 1; v_n int;
begin
  v_n := line_broadcast('daily', line_msg_acc_day(v_day), 'daily-' || v_day::text);
  return jsonb_build_object('success', true, 'targets', v_n, 'day', v_day);
end $line_send_daily$;

create or replace function line_send_weekly()
returns jsonb language plpgsql security definer set search_path = public, extensions as $line_send_weekly$
declare v_end date := line_today() - 1; v_n int;
begin
  v_n := line_broadcast('weekly', line_msg_weekly(v_end), 'weekly-' || v_end::text);
  return jsonb_build_object('success', true, 'targets', v_n, 'week_ending', v_end);
end $line_send_weekly$;

-- ============================================================
-- 5) สิทธิ์ — ปิดทั้งหมด
-- ============================================================
-- Postgres ให้สิทธิ์เรียกฟังก์ชันแก่ PUBLIC โดยอัตโนมัติ ต้องถอนเอง
-- ไม่ถอน = ใครก็ได้ที่มี anon key (ซึ่งอยู่ในหน้าเว็บ ใครกด View Source ก็เห็น)
-- เรียก line_push ยิงข้อความอะไรก็ได้เข้ากลุ่มในนามหน่วย
revoke execute on function line_set_token(text)        from public, anon, authenticated;
revoke execute on function line_token()                from public, anon, authenticated;
revoke execute on function line_push(text, text)       from public, anon, authenticated;
revoke execute on function line_broadcast(text, text, text) from public, anon, authenticated;
revoke execute on function line_send_new_deaths(int)   from public, anon, authenticated;
revoke execute on function line_send_daily()           from public, anon, authenticated;
revoke execute on function line_send_weekly()          from public, anon, authenticated;

-- ============================================================
-- 6) หมายผู้เสียชีวิตที่มีอยู่แล้วว่า "แจ้งไปแล้ว"
-- ============================================================
-- ขั้นตอนนี้สำคัญที่สุดในไฟล์ ถ้าข้ามไป รอบแรกที่ cron เดิน
-- บอทจะยิงผู้เสียชีวิตทุกรายที่มีในระบบเข้ากลุ่มรวดเดียว
--
-- target_id = null คือ "หมายไว้ตอนติดตั้ง ไม่ได้ส่งจริง"
-- ใช้ ref_id เดียวกับตอนส่งจริง ตัวเช็คซ้ำจึงเห็นว่าเคยจัดการแล้ว
insert into line_sent (kind, ref_id, target_id, ok, detail)
select 'death', id::text, null, true, 'หมายไว้ตอนติดตั้ง ไม่ได้ส่งจริง'
  from deaths
on conflict do nothing;

-- ============================================================
-- 7) ตั้งเวลา
-- ============================================================
-- pg_cron บน Supabase ใช้เวลา UTC ไทยคือ UTC+7
--   08:00 น. ไทย = 01:00 UTC
-- unschedule ก่อน เพื่อให้รันไฟล์นี้ซ้ำได้โดยไม่เกิดงานซ้อน
select cron.unschedule(jobname) from cron.job
 where jobname in ('line-daily', 'line-weekly', 'line-new-deaths');

-- สรุปประจำวัน ทุกวัน 08:00 น. ไทย
select cron.schedule('line-daily', '0 1 * * *', $job$ select line_send_daily(); $job$);

-- สรุปประจำสัปดาห์ ทุกวันจันทร์ 08:00 น. ไทย
select cron.schedule('line-weekly', '0 1 * * 1', $job$ select line_send_weekly(); $job$);

-- ผู้เสียชีวิตรายใหม่ ตรวจทุก 5 นาที
-- ไม่ใช้ trigger ตอน insert เพราะการนำเข้าข้อมูลทีละมาก ๆ จะยิงรัวทันที
-- หน่วง 5 นาทีแลกกับความปลอดภัยตรงนี้ คุ้มกว่า
select cron.schedule('line-new-deaths', '*/5 * * * *', $job$ select line_send_new_deaths(3); $job$);

-- ============================================================
-- ยังต้องทำอีก 3 ขั้นตอน — ทำในช่อง SQL Editor นี้เลย
-- ============================================================
--
-- ขั้นที่ 1  ใส่ token (เอามาจาก LINE Developers Console)
--   select line_set_token('วาง Channel access token ตรงนี้');
--   ต้องได้ข้อความว่า "บันทึก token ใหม่แล้ว"
--
-- ขั้นที่ 2  เชิญบอทเข้ากลุ่มไลน์ แล้วพิมพ์คำว่า  id  ในกลุ่ม
--   บอทจะตอบ group id กลับมา (ต้อง deploy Edge Function ก่อน)
--
-- ขั้นที่ 3  เอา group id มาใส่เป็นปลายทาง
--   insert into line_targets (label, target_id, target_type)
--   values ('กลุ่มงานจราจร สภ.เมืองนครสวรรค์', 'วาง group id ตรงนี้', 'group');
--
-- ============================================================
-- ตรวจผลหลังทำครบ
-- ============================================================
-- ทดสอบส่งเข้ากลุ่มทันทีหนึ่งฉบับ โดยไม่ต้องรอถึงเวลา
--   select line_broadcast('daily', line_msg_acc_day(), 'ทดสอบ-' || now()::text);
--
-- ผลจริงจาก LINE (pg_net ทำงานเบื้องหลัง ต้องรอสัก 5 วินาทีแล้วค่อยดู)
-- status_code 200 = สำเร็จ · 401 = token ผิด · 400 = group id ผิดหรือบอทไม่ได้อยู่ในกลุ่ม
--   select id, status_code, left(content, 300) as ผลลัพธ์, created
--     from net._http_response order by id desc limit 5;
--
-- งานที่ตั้งเวลาไว้
--   select jobname, schedule, active from cron.job where jobname like 'line-%';
--
-- ประวัติการส่ง
--   select kind, ref_id, target_id, ok, sent_at from line_sent
--    where target_id is not null order by sent_at desc limit 20;
--
-- ============================================================
-- ปิดการแจ้งเตือนชั่วคราว (เผื่อต้องใช้)
-- ============================================================
-- update line_targets set enabled = false;                      -- หยุดทุกปลายทาง
-- select cron.unschedule('line-daily');                          -- หยุดเฉพาะสรุปประจำวัน
-- update line_targets set want_daily = false where target_id = '...';  -- หยุดเฉพาะกลุ่มนั้น
