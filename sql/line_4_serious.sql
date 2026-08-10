-- ============================================================
-- LINE Bot — อุบัติเหตุร้ายแรง แจ้งเตือนอัตโนมัติ
-- ============================================================
-- ไฟล์ที่ 4  ต้องรัน line_1 line_2 line_3 มาก่อน
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
--
-- นิยาม "อุบัติเหตุร้ายแรง" — เข้าข้อใดข้อหนึ่งก็ถือว่าใช่
--   1. มีผู้เสียชีวิต
--   2. มีผู้บาดเจ็บสาหัส หรือ หมดสติ
--   3. ชนคนเดินเท้าบนทางม้าลาย
--
-- ข้อ 3 ต้องเข้าทั้งสองอย่างพร้อมกัน คือลักษณะทางเป็น "ทางม้าลาย"
-- และมีฝ่ายใดฝ่ายหนึ่งเป็น "คนเดินเท้า"
-- ถ้าอยากให้นับการชนคนเดินเท้าทุกที่ ไม่เฉพาะบนทางม้าลาย
-- แก้ที่ line_acc_is_serious บรรทัดเดียว
-- ============================================================

set search_path = public, extensions;

-- ============================================================
-- 1) ดึงอาการบาดเจ็บของทุกคนในอุบัติเหตุหนึ่งครั้ง
-- ============================================================
-- คนในเหตุหนึ่งครั้งกระจายอยู่ 4 ที่ — ฝ่ายที่ 1, ผู้โดยสารฝ่ายที่ 1,
-- ฝ่ายที่ 2, ผู้โดยสารฝ่ายที่ 2 ต้องกวาดให้ครบทั้งสี่
--
-- ระวัง: ข้อมูลที่นำเข้าย้อนหลังเก็บ passengers เป็น {} ไม่ใช่ []
-- เรียก jsonb_array_elements ใส่ออบเจกต์จะ error ทั้งคำสั่ง
-- จึงต้องเช็คชนิดก่อนทุกครั้ง
create or replace function line_acc_injuries(p_p1 jsonb, p_p2 jsonb)
returns text[]
language plpgsql immutable set search_path = public, extensions as $line_acc_injuries$
declare
  v_out text[] := '{}';
  v_party jsonb;
  v_pass jsonb;
begin
  foreach v_party in array array[coalesce(p_p1, '{}'::jsonb), coalesce(p_p2, '{}'::jsonb)]
  loop
    if coalesce(v_party->>'injury', '') <> '' then
      v_out := v_out || (v_party->>'injury');
    end if;

    if jsonb_typeof(v_party->'passengers') = 'array' then
      for v_pass in select value from jsonb_array_elements(v_party->'passengers')
      loop
        if coalesce(v_pass->>'injury', '') <> '' then
          v_out := v_out || (v_pass->>'injury');
        end if;
      end loop;
    end if;
  end loop;

  return v_out;
end $line_acc_injuries$;

-- ============================================================
-- 2) อุบัติเหตุครั้งนี้ร้ายแรงหรือไม่
-- ============================================================
create or replace function line_acc_is_serious(p_p1 jsonb, p_p2 jsonb, p_road_character text)
returns boolean
language sql immutable set search_path = public, extensions as $line_acc_is_serious$
  select
    -- 1 + 2 มีคนตาย สาหัส หรือหมดสติ
    exists (select 1 from unnest(line_acc_injuries(p_p1, p_p2)) x
             where x in ('เสียชีวิต', 'สาหัส', 'หมดสติ'))
    -- 3 ชนคนเดินเท้าบนทางม้าลาย
    or (coalesce(p_road_character, '') = 'ทางม้าลาย'
        and (coalesce(p_p1->>'status', '') = 'คนเดินเท้า'
          or coalesce(p_p2->>'status', '') = 'คนเดินเท้า'));
$line_acc_is_serious$;

-- ============================================================
-- 3) นับอุบัติเหตุร้ายแรงในช่วงเวลาหนึ่ง
-- ============================================================
create or replace function line_serious_count(p_from timestamptz, p_to timestamptz)
returns int
language sql stable security definer set search_path = public, extensions as $line_serious_count$
  select count(*)::int from accidents
   where incident_datetime >= p_from and incident_datetime < p_to
     and line_acc_is_serious(party1, party2, road_character);
$line_serious_count$;

-- ============================================================
-- 4) ข้อความแจ้งเตือน
-- ============================================================
-- จำนวนคนเสียชีวิตและสาหัส ใช้ตัวนับตัวเดียวกับ #ac-d
-- ถ้าเขียนวิธีนับขึ้นมาใหม่ตรงนี้ วันหนึ่งตัวเลขสองข้อความจะไม่ตรงกัน
-- แล้วไม่มีใครรู้ว่าอันไหนถูก
--
-- ไม่มีบรรทัดบาดเจ็บเล็กน้อย ตามที่ตกลงกัน — ไม่ใช่เรื่องร้ายแรง
-- และการใส่มาด้วยจะทำให้สายตาไปจับตัวเลขที่ใหญ่ที่สุดซึ่งไม่ใช่ประเด็น
create or replace function line_msg_serious_day(p_day date default null)
returns text
language plpgsql stable security definer set search_path = public, extensions as $line_msg_serious_day$
declare
  v_day date := coalesce(p_day, line_today());
  v_from timestamptz; v_to timestamptz; c jsonb; v_serious int;
begin
  v_from := timezone('Asia/Bangkok', v_day::timestamp);
  v_to   := timezone('Asia/Bangkok', (v_day + 1)::timestamp);
  c := line_acc_counts(v_from, v_to);
  v_serious := line_serious_count(v_from, v_to);

  return array_to_string(array[
    '🚨 อุบัติเหตุร้ายแรงวันนี้',
    line_thai_date(v_from),
    '',
    '• อุบัติเหตุร้ายแรง ' || v_serious || ' ครั้ง',
    '• เสียชีวิต ' || (c->>'deaths') || ' ราย',
    '• สาหัส/หมดสติ ' || (c->>'severe') || ' ราย'
  ], E'\n');
end $line_msg_serious_day$;

-- ============================================================
-- 5) ส่งเมื่อมีอุบัติเหตุร้ายแรงรายใหม่
-- ============================================================
-- ใช้วิธีเดียวกับการแจ้งผู้เสียชีวิต คือถามว่า "ครั้งไหนยังไม่เคยแจ้ง"
-- และต้องหมายของเก่าว่าแจ้งแล้วตอนติดตั้ง (ข้อ 6) ไม่งั้นรอบแรกยิงรัวทั้งคลัง
--
-- ส่งข้อความเดียวต่อรอบ แม้จะเจอหลายครั้งพร้อมกัน
-- เพราะเนื้อหาเป็นยอดรวมของทั้งวันอยู่แล้ว ส่งซ้ำหลายฉบับก็ได้เลขเดิม
create or replace function line_send_serious(p_max int default 5)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $line_send_serious$
declare
  a record; v_new int := 0; v_day date; v_n int := 0;
begin
  for a in
    select id, incident_datetime from accidents acc
     where line_acc_is_serious(party1, party2, road_character)
       and not exists (select 1 from line_sent s where s.kind = 'serious' and s.ref_id = acc.id::text)
     order by incident_datetime desc nulls last, id desc
     limit greatest(1, p_max)
  loop
    -- จดว่าเห็นครั้งนี้แล้ว target_id = null คือจดไว้เฉย ๆ ยังไม่ได้ส่ง
    insert into line_sent (kind, ref_id, target_id, ok, detail)
    values ('serious', a.id::text, null, true, 'พบอุบัติเหตุร้ายแรง')
    on conflict do nothing;
    v_new := v_new + 1;
    v_day := (timezone('Asia/Bangkok', a.incident_datetime))::date;
  end loop;

  if v_new = 0 then
    return jsonb_build_object('success', true, 'new', 0);
  end if;

  -- ส่งยอดของวันที่เกิดเหตุล่าสุดที่เพิ่งพบ
  v_n := line_broadcast('serious', line_msg_serious_day(v_day),
                        'serious-day-' || v_day::text || '-' || to_char(now(), 'HH24MI'));

  return jsonb_build_object('success', true, 'new', v_new, 'targets', v_n, 'day', v_day);
end $line_send_serious$;

-- ============================================================
-- 6) หมายอุบัติเหตุร้ายแรงที่มีอยู่แล้วว่า "แจ้งไปแล้ว"
-- ============================================================
-- ข้ามข้อนี้ไม่ได้ ระบบมีอุบัติเหตุสะสมกว่าพันครั้ง
-- ถ้าไม่หมายไว้ก่อน cron รอบแรกจะเริ่มไล่แจ้งย้อนหลังทั้งหมด
insert into line_sent (kind, ref_id, target_id, ok, detail)
select 'serious', id::text, null, true, 'หมายไว้ตอนติดตั้ง ไม่ได้ส่งจริง'
  from accidents
 where line_acc_is_serious(party1, party2, road_character)
on conflict do nothing;

-- ============================================================
-- 7) เปิดให้ปลายทางเลือกรับได้
-- ============================================================
alter table line_targets add column if not exists want_serious boolean not null default true;

-- line_broadcast เดิมไม่รู้จักชนิด 'serious' ต้องสอนให้รู้จัก
create or replace function line_broadcast(p_kind text, p_text text, p_ref text default null)
returns int
language plpgsql security definer set search_path = public, extensions as $line_broadcast$
declare t record; v_n int := 0; v_req bigint;
begin
  if coalesce(btrim(p_text), '') = '' then return 0; end if;

  for t in
    select target_id from line_targets
     where enabled
       and case p_kind when 'death'   then want_death
                       when 'daily'   then want_daily
                       when 'weekly'  then want_weekly
                       when 'serious' then want_serious
                       else true end
  loop
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
-- 8) สิทธิ์
-- ============================================================
-- ตัวนับกับตัวสร้างข้อความเปิดให้ anon ได้ เพราะคืนจำนวนล้วน ๆ
-- ส่วนตัวที่ส่งข้อความจริงต้องถอนสิทธิ์ PUBLIC ออก
grant execute on function line_acc_injuries(jsonb, jsonb)                  to anon, authenticated;
grant execute on function line_acc_is_serious(jsonb, jsonb, text)          to anon, authenticated;
grant execute on function line_serious_count(timestamptz, timestamptz)     to anon, authenticated;
grant execute on function line_msg_serious_day(date)                       to anon, authenticated;

revoke execute on function line_send_serious(int)                          from public, anon, authenticated;
revoke execute on function line_broadcast(text, text, text)                from public, anon, authenticated;

-- ============================================================
-- 9) ตั้งเวลา — ตรวจทุก 5 นาที
-- ============================================================
select cron.unschedule(jobname) from cron.job where jobname = 'line-serious';
select cron.schedule('line-serious', '*/5 * * * *', $job$ select line_send_serious(5); $job$);

-- ============================================================
-- ตรวจผลหลังรัน
-- ============================================================
-- ข้อความที่จะถูกส่ง
--   select line_msg_serious_day();
--
-- นิยามจับได้กี่ครั้งในระบบ แยกตามเหตุผล — ตรวจว่าไม่ได้จับกว้างหรือแคบเกินไป
--   select count(*) filter (where exists (select 1 from unnest(line_acc_injuries(party1,party2)) x where x = 'เสียชีวิต')) as มีผู้เสียชีวิต,
--          count(*) filter (where exists (select 1 from unnest(line_acc_injuries(party1,party2)) x where x in ('สาหัส','หมดสติ'))) as สาหัสหรือหมดสติ,
--          count(*) filter (where road_character = 'ทางม้าลาย') as บนทางม้าลาย,
--          count(*) filter (where line_acc_is_serious(party1,party2,road_character)) as ร้ายแรงรวม,
--          count(*) as ทั้งหมด
--     from accidents;
--
-- ร้ายแรงย้อนหลัง 30 วัน
--   select line_serious_count(now() - interval '30 days', now());
