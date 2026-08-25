-- กิจกรรมแจกหมวกนิรภัย  ตัวตรวจสองเงื่อนไขและตัวให้สิทธิ์
-- รันหลัง camp_2_recv.sql
-- ถ้ามี $0 ต่อท้ายไฟล์ ให้ลบออกก่อนกด Run
--
-- ทำไมต้องแยกเป็นสองจังหวะ ยิงกับเก็บ
--   pg_net ไม่ได้ยิงคำขอทันทีที่เรียก แต่จะยิงหลังทรานแซกชันปิดลงแล้ว
--   ถ้ายิงแล้วอ่านผลในทรานแซกชันเดียวกัน จะอ่านได้แต่คำตอบเก่าของงานอื่น
--   จึงต้องเป็นสองฟังก์ชัน และให้ pg_cron เรียกคนละรอบ

-- ==========================================================
-- 1  ตารางจับคู่คำขอกับคน
-- ==========================================================
-- pg_net คืนเลขคำขอมาให้ แต่คำตอบที่กลับมาไม่ได้บอกว่าเป็นของใคร
-- ต้องจดไว้เองว่าเลขนี้คือการถามเรื่องอะไรของใคร

create table if not exists camp_probe (
  req_id       bigint primary key,
  line_user_id text not null,
  kind         text not null,
  fired_at     timestamptz not null default now(),
  done         boolean not null default false
);

create index if not exists camp_probe_open_idx on camp_probe (done, fired_at);

comment on column camp_probe.kind is 'friend คือถามว่ายังเป็นเพื่อนไหม  group คือถามว่ายังอยู่ในกลุ่มไหม';

alter table camp_probe enable row level security;
revoke all on camp_probe from anon, authenticated;

-- ==========================================================
-- 2  จังหวะที่หนึ่ง  ยิงคำถามไปที่ไลน์
-- ==========================================================
-- เลือกเฉพาะคนที่ยังไม่เคยตรวจ หรือตรวจไว้นานแล้ว
-- ทำทีละชุด ไม่ยิงทุกคนพร้อมกัน เพราะไลน์จำกัดจำนวนคำขอต่อนาที

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
  if camp_cfg('campEnabled', 'false')::boolean is not true then
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
    -- ยังเป็นเพื่อนกับบัญชีทางการอยู่ไหม
    select net.http_get(
             url := 'https://api.line.me/v2/bot/profile/' || r.line_user_id,
             headers := jsonb_build_object('Authorization', 'Bearer ' || v_tok)
           ) into v_req;
    insert into camp_probe (req_id, line_user_id, kind)
    values (v_req, r.line_user_id, 'friend')
    on conflict (req_id) do nothing;

    -- ยังอยู่ในกลุ่มอยู่ไหม
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

-- ==========================================================
-- 3  จังหวะที่สอง  เก็บคำตอบมาบันทึก
-- ==========================================================
-- 200 คือใช่  404 คือไม่ใช่  อย่างอื่นถือว่ายังไม่รู้ ปล่อยไว้ให้รอบหน้าถามใหม่
-- สำคัญ ห้ามตีความรหัสอื่นว่าเป็นไม่ใช่
-- เพราะโทเคนหมดอายุหรือไลน์ล่มชั่วคราวจะทำให้ทุกคนหลุดสิทธิ์พร้อมกันทั้งระบบ

create or replace function camp_check_collect()
returns int
language plpgsql
volatile
security definer
set search_path = public
as $fn$
declare
  v_n int := 0;
  r   record;
begin
  for r in
    select p.req_id, p.line_user_id, p.kind, x.status_code
      from camp_probe p
      join net._http_response x on x.id = p.req_id
     where p.done = false
  loop
    if r.status_code = 200 then
      if r.kind = 'friend' then
        update camp_members set is_friend = true, checked_at = now()
         where line_user_id = r.line_user_id;
      else
        update camp_members set in_group = true, checked_at = now()
         where line_user_id = r.line_user_id;
      end if;
      v_n := v_n + 1;

    elsif r.status_code = 404 then
      if r.kind = 'friend' then
        update camp_members set is_friend = false, checked_at = now()
         where line_user_id = r.line_user_id;
      else
        update camp_members set in_group = false, checked_at = now()
         where line_user_id = r.line_user_id;
      end if;
      v_n := v_n + 1;
    end if;

    update camp_probe set done = true where req_id = r.req_id;
  end loop;

  -- เก็บกวาดคำขอเก่าที่ไม่เคยได้คำตอบ กันตารางบวม
  delete from camp_probe
   where fired_at < now() - interval '2 days';

  return v_n;
end;
$fn$;

-- ==========================================================
-- 4  ให้สิทธิ์รับของรางวัล
-- ==========================================================
-- ให้ตามลำดับก่อนหลัง จนเต็มโควตาของเดือนนั้นแล้วหยุด
-- เมื่อได้สิทธิ์แล้วจะไม่หลุด แม้เพื่อนจะออกจากกลุ่มทีหลัง
-- เพราะตอนที่ให้สิทธิ์ เขาทำครบตามกติกาจริง ๆ

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
  v_quota  int := camp_cfg('campMonthlyQuota', '5')::int;
  v_used   int;
  v_new    int := 0;
  r        record;
begin
  if camp_cfg('campEnabled', 'false')::boolean is not true then
    return jsonb_build_object('success', false, 'message', 'กิจกรรมยังไม่เปิด');
  end if;

  -- เดือนตามปีพุทธศักราช เวลาไทย
  v_period := (extract(year from (now() at time zone 'Asia/Bangkok'))::int + 543)::text
              || '-' || to_char(now() at time zone 'Asia/Bangkok', 'MM');

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
    'message', 'ให้สิทธิ์ใหม่ ' || v_new || ' คน  รวมเดือนนี้ ' || v_used || ' จาก ' || v_quota
  );
end;
$fn$;

-- ==========================================================
-- 5  ตั้งเวลาทำงาน
-- ==========================================================
-- ยิงกับเก็บต้องอยู่คนละรอบ เพราะ pg_net ยิงจริงหลังทรานแซกชันปิด
-- ยิงนาทีที่ 0 และ 30  เก็บนาทีที่ 5 และ 35  ให้สิทธิ์นาทีที่ 10 และ 40
-- ทุกฟังก์ชันเช็ค campEnabled เองอยู่แล้ว ตอนนี้ปิดอยู่จึงยังไม่มีอะไรเกิดขึ้น

select cron.unschedule(jobname)
  from cron.job
 where jobname in ('camp-fire', 'camp-collect', 'camp-award');

select cron.schedule('camp-fire',    '0,30 * * * *',  'select camp_check_fire()');
select cron.schedule('camp-collect', '5,35 * * * *',  'select camp_check_collect()');
select cron.schedule('camp-award',   '10,40 * * * *', 'select camp_award()');

-- ==========================================================
-- ตรวจผล  คำสั่งสุดท้ายคำสั่งเดียวที่จะแสดงผล
-- ==========================================================

select 'ฟังก์ชันที่สร้าง' as รายการ,
       coalesce((select string_agg(p.proname, ', ' order by p.proname)
                 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                 where n.nspname = 'public'
                   and p.proname in ('camp_check_fire', 'camp_check_collect', 'camp_award')),
                'ไม่มี') as ผล
union all
select 'งานตั้งเวลาของกิจกรรม',
       coalesce((select string_agg(jobname || ' = ' || schedule, '   ' order by jobname)
                 from cron.job where jobname like 'camp-%'), 'ไม่มี')
union all
select 'สวิตช์กิจกรรม',
       camp_cfg('campEnabled', 'ไม่พบ')
union all
select 'รหัสกลุ่มที่ตั้งไว้',
       case when camp_cfg('campGroupId', '') = ''
            then 'ยังว่าง  ตัวตรวจจะยังไม่ทำงานจนกว่าจะใส่'
            else left(camp_cfg('campGroupId', ''), 6) || ' ตามด้วยอีกหลายตัว' end
union all
select 'จำนวนผู้เข้าร่วมตอนนี้',
       (select count(*)::text from camp_members) || ' คน'
union all
select 'ขั้นต่อไป',
       'ใส่รหัสกลุ่ม แล้ว deploy Edge Function ใหม่ แล้วค่อยเปิด campEnabled เป็น true';
