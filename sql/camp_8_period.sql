-- กำหนดช่วงเวลาของกิจกรรม 21 ส.ค. ถึง 21 ก.ย. 2569
-- รันหลัง camp_6_name.sql
-- ถ้ามี $0 ต่อท้ายไฟล์ ให้ลบออกก่อนกด Run
--
-- ที่เปลี่ยนไปจากเดิม
--   1 มีวันเริ่มและวันสิ้นสุด นอกช่วงนี้ระบบไม่รับคนเพิ่มและไม่ให้สิทธิ์
--   2 เลิกโควตารายเดือน เปลี่ยนเป็นจำกัดหมวก 100 ใบตลอดกิจกรรม ใครครบก่อนได้ก่อน
--     ของเดิมตั้งไว้เดือนละ 5 ใบ ซึ่งกิจกรรมคร่อมสองเดือนปฏิทินจะกลายเป็น 10 ใบโดยไม่ตั้งใจ
--   3 คนที่ทักมาหลังกิจกรรมจบ จะได้คำตอบว่าจบแล้ว ไม่ใช่เงียบใส่

-- ==========================================================
-- 1  ค่าตั้งช่วงเวลา
-- ==========================================================
-- เก็บเป็น ค.ศ. รูปแบบ ปี-เดือน-วัน เพราะฐานข้อมูลคำนวณด้วยค่านี้
-- ส่วนที่แสดงให้ประชาชนเห็นจะแปลงเป็น พ.ศ. ให้เอง

insert into bs_settings (key, val) values
  ('campStartDate', to_jsonb('2026-08-21'::text)),
  ('campEndDate',   to_jsonb('2026-09-21'::text)),
  ('campQuota',     to_jsonb(100))
on conflict (key) do update set val = excluded.val;

-- เลิกใช้โควตารายเดือน กิจกรรมนี้จำกัดที่จำนวนหมวกทั้งหมด ไม่ได้จำกัดรายเดือน
-- ลบทิ้งเลยดีกว่าปล่อยค้างไว้ให้คนอ่านทีหลังเข้าใจผิดว่ายังมีผล
delete from bs_settings where key = 'campMonthlyQuota';

-- ==========================================================
-- 2  ตัวช่วยเรื่องวัน
-- ==========================================================

-- วันนี้ตามเวลาไทย ไม่ใช่เวลาของเซิร์ฟเวอร์
create or replace function camp_today()
returns date
language sql
stable
security definer
set search_path = public
as $fn$
  select (now() at time zone 'Asia/Bangkok')::date
$fn$;

-- กิจกรรมเปิดรับอยู่ไหม  ต้องทั้งเปิดสวิตช์และอยู่ในช่วงวันที่กำหนด
create or replace function camp_open()
returns boolean
language sql
stable
security definer
set search_path = public
as $fn$
  select camp_cfg('campEnabled', 'false')::boolean
     and camp_today() >= coalesce(nullif(camp_cfg('campStartDate', ''), '')::date, camp_today())
     and camp_today() <= coalesce(nullif(camp_cfg('campEndDate',   ''), '')::date, camp_today())
$fn$;

-- แปลงวันเป็นข้อความไทยแบบย่อ เช่น 21 ก.ย. 2569
create or replace function camp_thai_date(p_d date)
returns text
language sql
immutable
as $fn$
  select extract(day from p_d)::int::text || ' ' ||
         case extract(month from p_d)::int
           when 1 then 'ม.ค.'  when 2 then 'ก.พ.'  when 3 then 'มี.ค.'
           when 4 then 'เม.ย.' when 5 then 'พ.ค.'  when 6 then 'มิ.ย.'
           when 7 then 'ก.ค.'  when 8 then 'ส.ค.'  when 9 then 'ก.ย.'
           when 10 then 'ต.ค.' when 11 then 'พ.ย.' else 'ธ.ค.'
         end || ' ' ||
         (extract(year from p_d)::int + 543)::text
$fn$;

-- ==========================================================
-- 3  รอบของกิจกรรม แทนการนับเป็นเดือนปฏิทิน
-- ==========================================================
-- ใช้ช่วงวันเป็นชื่อรอบ โควตาจึงเป็นของทั้งรอบ ไม่ใช่ต่อเดือน
-- ถ้าวันหน้าจัดกิจกรรมรอบใหม่ แค่เปลี่ยนวันที่ ชื่อรอบก็เปลี่ยนตาม
-- สิทธิ์ของรอบเก่าจะยังอยู่ครบ ไม่ปนกัน

create or replace function camp_period()
returns text
language sql
stable
security definer
set search_path = public
as $fn$
  select case
           when nullif(camp_cfg('campStartDate', ''), '') is not null
            and nullif(camp_cfg('campEndDate',   ''), '') is not null
           then camp_cfg('campStartDate', '') || '..' || camp_cfg('campEndDate', '')
           else (extract(year from (now() at time zone 'Asia/Bangkok'))::int + 543)::text
                || '-' || to_char(now() at time zone 'Asia/Bangkok', 'MM')
         end
$fn$;

-- ==========================================================
-- 4  ข้อความสถานะ เพิ่มวันสิ้นสุดเข้าไป
-- ==========================================================
-- คนต้องรู้ว่าเหลือเวลาเท่าไหร่ ไม่งั้นจะดองไว้แล้วมาต่อว่าตอนหมดเขต

create or replace function camp_msg_status(p_user_id text)
returns text
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_code   text;
  v_need   int  := camp_cfg('campNeedFriends', '5')::int;
  v_have   int;
  v_share  text := camp_cfg('campShareBase', 'https://line.me/R/oaMessage/%40690vodvg/?');
  v_group  text := camp_cfg('campGroupUrl', '');
  v_prize  text := camp_cfg('campPrizeName', 'ของรางวัล');
  v_end    date := nullif(camp_cfg('campEndDate', ''), '')::date;
  v_left   int;
  v_lines  text[];
begin
  select ref_code into v_code from camp_members where line_user_id = p_user_id;
  if v_code is null then return null; end if;

  v_have := camp_friend_count(p_user_id);

  v_lines := array[
    '🎁 กิจกรรมแจก' || v_prize,
    '',
    'รหัสของคุณ  ' || v_code,
    '',
    'ส่งลิงก์นี้ให้เพื่อน เพื่อนกดแล้วกดส่งข้อความได้เลย ไม่ต้องพิมพ์อะไร',
    v_share || v_code,
    '',
    'จากนั้นให้เพื่อนเข้ากลุ่มนี้ด้วย',
    v_group,
    '',
    'ต้องครบทั้งสองอย่าง เพิ่มเพื่อนและเข้ากลุ่ม จึงจะนับให้',
    'ตอนนี้นับได้ ' || v_have || ' จาก ' || v_need || ' คน'
  ];

  if v_end is not null then
    v_left := (v_end - camp_today());
    v_lines := v_lines || '' ||
      ('⏳ กิจกรรมถึง ' || camp_thai_date(v_end) ||
       case when v_left > 0 then '  เหลืออีก ' || v_left || ' วัน'
            when v_left = 0 then '  วันนี้วันสุดท้าย'
            else '  หมดเขตแล้ว' end);
  end if;

  if v_have >= v_need then
    v_lines := v_lines || '' || ('🎉 ครบแล้ว ติดต่อรับ' || v_prize || ' ได้ที่ สภ.เมืองนครสวรรค์');
  end if;

  return array_to_string(v_lines, chr(10));
end;
$fn$;

-- ==========================================================
-- 5  ตัวยิงคำถามและตัวให้สิทธิ์ ต้องดูวันด้วย
-- ==========================================================

create or replace function camp_check_fire(p_limit int default 60, p_stale_hours int default 6)
returns int
language plpgsql
volatile
security definer
set search_path = public
as $fn$
declare
  v_group text;
  v_tok   text;
  v_n     int := 0;
  r       record;
  v_req   bigint;
begin
  if not camp_open() then
    return 0;
  end if;

  v_group := camp_cfg('campGroupId', '');
  if v_group = '' then
    raise notice 'ยังไม่ได้ตั้ง campGroupId จึงยังตรวจการอยู่ในกลุ่มไม่ได้';
    return 0;
  end if;

  v_tok := line_token();

  for r in
    select line_user_id
      from camp_members
     where checked_at is null
        or checked_at < now() - make_interval(hours => p_stale_hours)
     order by checked_at nulls first
     limit p_limit
  loop
    select net.http_get(
             url := 'https://api.line.me/v2/bot/profile/' || r.line_user_id,
             headers := jsonb_build_object('Authorization', 'Bearer ' || v_tok)
           ) into v_req;
    insert into camp_probe (req_id, line_user_id, kind)
    values (v_req, r.line_user_id, 'friend')
    on conflict (req_id) do nothing;

    select net.http_get(
             url := 'https://api.line.me/v2/bot/group/' || v_group
                    || '/member/' || r.line_user_id,
             headers := jsonb_build_object('Authorization', 'Bearer ' || v_tok)
           ) into v_req;
    insert into camp_probe (req_id, line_user_id, kind)
    values (v_req, r.line_user_id, 'group')
    on conflict (req_id) do nothing;

    v_n := v_n + 1;
  end loop;

  return v_n;
end;
$fn$;

create or replace function camp_award()
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $fn$
declare
  v_period text;
  v_need   int := camp_cfg('campNeedFriends', '5')::int;
  v_quota  int := camp_cfg('campQuota', '100')::int;
  v_used   int;
  v_new    int := 0;
  r        record;
begin
  if not camp_open() then
    return jsonb_build_object('success', false, 'message', 'กิจกรรมยังไม่เปิด หรือหมดเขตแล้ว');
  end if;

  v_period := camp_period();

  select count(*) into v_used from camp_claims where period = v_period;

  for r in
    select m.line_user_id, camp_friend_count(m.line_user_id) as n
      from camp_members m
     where not exists (
             select 1 from camp_claims c
              where c.line_user_id = m.line_user_id and c.period = v_period
           )
     order by m.created_at
  loop
    exit when v_used >= v_quota;

    if r.n >= v_need then
      insert into camp_claims (line_user_id, period, friends_at_claim)
      values (r.line_user_id, v_period, r.n)
      on conflict (line_user_id, period) do nothing;

      v_used := v_used + 1;
      v_new  := v_new + 1;
    end if;
  end loop;

  return jsonb_build_object(
    'success', true,
    'period',  v_period,
    'new',     v_new,
    'used',    v_used,
    'quota',   v_quota,
    'message', 'ให้สิทธิ์ใหม่ ' || v_new || ' คน  รวมทั้งกิจกรรม ' || v_used || ' จาก ' || v_quota || ' ใบ'
  );
end;
$fn$;

-- ==========================================================
-- 6  line_reply  เปลี่ยนแค่ด่านเช็คว่ากิจกรรมเปิดอยู่ไหม
-- ==========================================================
-- ตรรกะเดิมทุกบรรทัด เปลี่ยนสองอย่าง
--   ใช้ camp_open แทน campEnabled ตรง ๆ จึงดูวันด้วย
--   ถ้าหมดเขตแล้วแต่ยังเปิดสวิตช์อยู่ คนถามถึงกิจกรรมจะได้คำตอบว่าจบแล้ว ไม่ใช่เงียบใส่

create or replace function line_reply(
  p_text        text,
  p_user_id     text default null,
  p_source_type text default null
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $fn$
declare
  v_q text := lower(btrim(coalesce(p_text, '')));
  v_action text; v_lines text[]; r record;
  v_inviter text;
  v_group   text;
  v_end     date;
begin
  if v_q = '' then return null; end if;

  -- ---------- ส่วนกิจกรรม ----------
  -- ทำเฉพาะเมื่อรู้ว่าใครพูด และพูดในแชทส่วนตัวกับบัญชีทางการเท่านั้น
  -- ในกลุ่มไม่ทำ เพราะรหัสชวนเป็นเรื่องส่วนตัว และบอทที่พูดในกลุ่มบ่อยจะถูกเตะออก
  if p_user_id is not null and coalesce(p_source_type, 'user') = 'user'
     and camp_cfg('campEnabled', 'false')::boolean then

    if camp_open() then
      -- ทุกคนที่ทักมาต้องมีรหัสของตัวเอง จะได้ชวนต่อได้
      perform camp_touch(p_user_id);

      -- หารหัสชวนที่ปนมาในข้อความ
      -- ไม่ใช้ regular expression เพราะรูปแบบนับจำนวนตัวอักษรต้องใช้วงเล็บปีกกา
      -- ซึ่งเขียนลงไฟล์ SQL ไม่ได้ ตัวแก้ไขของ Supabase จะทำให้เสีย
      select m.line_user_id into v_inviter
        from camp_members m
       where m.line_user_id <> p_user_id
         and m.ref_code = any (
               select upper(btrim(t))
                 from unnest(string_to_array(
                        replace(replace(p_text, chr(10), ' '), chr(13), ' '), ' ')) as t
               where btrim(t) <> ''
             )
       limit 1;

      if v_inviter is not null then
        -- ผูกได้ครั้งเดียว ใครผูกไปแล้วจะเปลี่ยนผู้ชวนทีหลังไม่ได้
        update camp_members
           set referred_by = v_inviter
         where line_user_id = p_user_id
           and referred_by is null;

        v_group := camp_cfg('campGroupUrl', '');

        return jsonb_build_object(
          'action', 'camp-join',
          'text', array_to_string(array[
            '✅ บันทึกแล้ว ขอบคุณที่เข้าร่วมกิจกรรม',
            '',
            'เหลืออีกขั้นเดียว กดเข้ากลุ่มนี้',
            v_group,
            '',
            'เมื่อเข้ากลุ่มแล้ว เพื่อนที่ชวนคุณมาจะได้รับเครดิตหนึ่งคน',
            'ถ้าออกจากกลุ่มหรือบล็อกบัญชีนี้ เครดิตจะหายไปเอง',
            '',
            'อยากชวนเพื่อนของคุณเองบ้าง พิมพ์คำว่า  กิจกรรม'
          ], chr(10))
        );
      end if;

      -- ถามสถานะของตัวเอง
      if v_q in ('กิจกรรม', 'รหัส', 'รหัสของฉัน', 'หมวก', 'ของรางวัล') then
        return jsonb_build_object('action', 'camp-status', 'text', camp_msg_status(p_user_id));
      end if;

    else
      -- นอกช่วงเวลา ตอบเฉพาะคนที่ถามถึงกิจกรรมโดยตรง
      if v_q in ('กิจกรรม', 'รหัส', 'รหัสของฉัน', 'หมวก', 'ของรางวัล') then
        v_end := nullif(camp_cfg('campEndDate', ''), '')::date;
        return jsonb_build_object(
          'action', 'camp-closed',
          'text', array_to_string(array[
            '🎁 กิจกรรมแจก' || camp_cfg('campPrizeName', 'ของรางวัล'),
            '',
            case when v_end is not null and camp_today() > v_end
                 then 'กิจกรรมสิ้นสุดแล้วเมื่อ ' || camp_thai_date(v_end)
                 else 'กิจกรรมยังไม่เริ่ม จะเริ่มวันที่ ' ||
                      camp_thai_date(nullif(camp_cfg('campStartDate', ''), '')::date) end,
            '',
            'ขอบคุณที่สนใจครับ ติดตามข่าวสารความปลอดภัยทางถนนได้ที่นี่ต่อไป'
          ], chr(10))
        );
      end if;
    end if;
  end if;

  -- ---------- ของเดิม ไม่แก้อะไรเลย ----------
  select action into v_action from line_keywords
   where enabled and (v_q = keyword or v_q like keyword || ' %')
   order by sort_order, length(keyword) desc limit 1;

  if v_action is null then return null; end if;

  if v_action = 'id' then
    return jsonb_build_object('action', 'id', 'text', null);
  end if;

  if v_action = 'ac-d' then
    return jsonb_build_object('action', v_action, 'text', line_msg_acc_day());
  elsif v_action = 'ac-w' then
    return jsonb_build_object('action', v_action, 'text', line_msg_acc_week());

  elsif v_action = 'help' then
    v_lines := array['🤖 คำสั่งที่ใช้ได้', ''];
    for r in
      select string_agg(keyword, ' / ' order by keyword) as ks,
             max(case action when 'ac-d' then 'สรุปอุบัติเหตุวันนี้'
                             when 'ac-w' then 'สรุปอุบัติเหตุรอบสัปดาห์'
                             else action end) as ds
        from line_keywords where enabled and action not in ('help', 'id')
       group by action order by min(sort_order)
    loop
      v_lines := v_lines || (r.ks || '  —  ' || r.ds);
    end loop;
  end if;

  if v_lines is null or array_length(v_lines, 1) is null then return null; end if;
  return jsonb_build_object('action', v_action, 'text', array_to_string(v_lines, chr(10)));
end;
$fn$;

grant execute on function line_reply(text, text, text) to anon, authenticated, service_role;

notify pgrst, 'reload schema';

-- ==========================================================
-- 7  ภาพรวมของเจ้าหน้าที่ ต้องอ่านโควตาตัวใหม่
-- ==========================================================
-- ตัวเดิมใน camp_4 อ่าน campMonthlyQuota ซึ่งไฟล์นี้ลบทิ้งไปแล้ว
-- ถ้าไม่สร้างใหม่ มันจะตกไปใช้ค่าสำรอง 5 แล้วรายงานว่าโควตาเหลือติดลบ

create or replace function camp_admin_overview(p_token text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $fn$
declare
  v_err    jsonb;
  v_period text := camp_period();
  v_need   int  := camp_cfg('campNeedFriends', '5')::int;
  v_quota  int  := camp_cfg('campQuota', '100')::int;
  v_end    date := nullif(camp_cfg('campEndDate', ''), '')::date;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;

  return jsonb_build_object(
    'success',  true,
    'period',   v_period,
    'enabled',  camp_cfg('campEnabled', 'false')::boolean,
    'open',     camp_open(),
    'startDate', camp_cfg('campStartDate', ''),
    'endDate',   camp_cfg('campEndDate', ''),
    'daysLeft',  case when v_end is null then null else (v_end - camp_today()) end,
    'prize',    camp_cfg('campPrizeName', 'ของรางวัล'),
    'need',     v_need,
    'quota',    v_quota,
    'groupSet', camp_cfg('campGroupId', '') <> '',
    'members',  (select count(*) from camp_members),
    'friendOk', (select count(*) from camp_members where is_friend is true),
    'groupOk',  (select count(*) from camp_members where in_group  is true),
    'bothOk',   (select count(*) from camp_members where is_friend is true and in_group is true),
    'never',    (select count(*) from camp_members where checked_at is null),
    'ready',    (select count(*) from camp_members m
                  where camp_friend_count(m.line_user_id) >= v_need
                    and not exists (select 1 from camp_claims c
                                     where c.line_user_id = m.line_user_id and c.period = v_period)),
    'claimed',  (select count(*) from camp_claims where period = v_period),
    'left',     greatest(v_quota - (select count(*) from camp_claims where period = v_period), 0)
  );
end;
$fn$;

grant execute on function camp_admin_overview(text) to anon, authenticated;

-- ==========================================================
-- ตรวจผล  คำสั่งสุดท้ายคำสั่งเดียวที่จะแสดงผล
-- ==========================================================

select 'ช่วงกิจกรรม' as รายการ,
       camp_thai_date(camp_cfg('campStartDate','')::date) || ' ถึง ' ||
       camp_thai_date(camp_cfg('campEndDate','')::date) as ผล
union all
select 'วันนี้', camp_thai_date(camp_today())
union all
select 'เหลืออีกกี่วัน',
       (camp_cfg('campEndDate','')::date - camp_today())::text || ' วัน'
union all
select 'กิจกรรมเปิดรับอยู่ไหม',
       case when camp_open() then 'เปิดรับอยู่' else 'ปิด  ทั้งสวิตช์หรือนอกช่วงเวลา' end
union all
select 'ชื่อรอบที่ใช้เก็บสิทธิ์', camp_period()
union all
select 'โควตาหมวกทั้งกิจกรรม',
       camp_cfg('campQuota','100') || ' ใบ  ใครครบเงื่อนไขก่อนได้ก่อน ไม่จำกัดรายเดือน'
union all
select 'โควตารายเดือนตัวเก่า',
       coalesce((select val::text from bs_settings where key = 'campMonthlyQuota'), 'ลบทิ้งแล้ว')
union all
select 'ลายเซ็นของ line_reply ต้องมีอันเดียว',
       coalesce((select string_agg(p.oid::regprocedure::text, '  |  ')
                 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                 where n.nspname = 'public' and p.proname = 'line_reply'), 'หายไป');
