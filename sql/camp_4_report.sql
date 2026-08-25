-- กิจกรรมแจกหมวกนิรภัย  ส่วนของเจ้าหน้าที่
-- รันหลัง camp_3_verify.sql
-- ถ้ามี $0 ต่อท้ายไฟล์ ให้ลบออกก่อนกด Run
--
-- ทุกฟังก์ชันในไฟล์นี้ต้องผ่าน admin_check_ ก่อน
-- ตาราง camp_ ปิด RLS ตายสนิทไม่มี policy ทางเดียวที่เข้าถึงได้คือผ่านฟังก์ชันเหล่านี้
-- คืนค่าเป็น jsonb รูปแบบ success message เหมือน RPC อื่นในระบบ ไม่โยน exception

-- ==========================================================
-- 1  เดือนปัจจุบัน ตามปีพุทธศักราช เวลาไทย
-- ==========================================================
-- ต้องให้ค่าตรงกับที่ camp_award ใช้ ไม่งั้นจะมองไม่เห็นสิทธิ์ที่เพิ่งให้ไป

create or replace function camp_period()
returns text
language sql
stable
security definer
set search_path = public
as $fn$
  select (extract(year from (now() at time zone 'Asia/Bangkok'))::int + 543)::text
         || '-' || to_char(now() at time zone 'Asia/Bangkok', 'MM')
$fn$;

-- ==========================================================
-- 2  ภาพรวม
-- ==========================================================

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
  v_quota  int  := camp_cfg('campMonthlyQuota', '5')::int;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;

  return jsonb_build_object(
    'success', true,
    'period',  v_period,
    'enabled', camp_cfg('campEnabled', 'false')::boolean,
    'prize',   camp_cfg('campPrizeName', 'ของรางวัล'),
    'need',    v_need,
    'quota',   v_quota,
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

-- ==========================================================
-- 3  รายชื่อผู้เข้าร่วม
-- ==========================================================
-- เรียงคนที่ใกล้ได้สิทธิ์ที่สุดขึ้นก่อน เจ้าหน้าที่จะได้เห็นว่าใครกำลังจะครบ

create or replace function camp_admin_people(p_token text, p_limit int default 200)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $fn$
declare
  v_err  jsonb;
  v_rows jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;

  select coalesce(jsonb_agg(x order by x->>'n' desc), jsonb_build_array())
    into v_rows
  from (
    select jsonb_build_object(
             'code',      m.ref_code,
             'name',      coalesce(m.display_name, 'ไม่ทราบชื่อ'),
             'n',         camp_friend_count(m.line_user_id),
             'isFriend',  m.is_friend,
             'inGroup',   m.in_group,
             'invitedBy', (select i.ref_code from camp_members i where i.line_user_id = m.referred_by),
             'checkedAt', m.checked_at,
             'joinedAt',  m.created_at
           ) as x
      from camp_members m
     order by camp_friend_count(m.line_user_id) desc, m.created_at
     limit greatest(coalesce(p_limit, 200), 1)
  ) t;

  return jsonb_build_object('success', true, 'rows', v_rows);
end;
$fn$;

-- ==========================================================
-- 4  รายชื่อผู้ได้สิทธิ์
-- ==========================================================

create or replace function camp_admin_claims(p_token text, p_period text default null)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $fn$
declare
  v_err  jsonb;
  v_p    text := coalesce(nullif(btrim(coalesce(p_period, '')), ''), camp_period());
  v_rows jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;

  select coalesce(jsonb_agg(jsonb_build_object(
           'id',       c.id,
           'code',     m.ref_code,
           'name',     coalesce(m.display_name, 'ไม่ทราบชื่อ'),
           'friends',  c.friends_at_claim,
           'status',   c.status,
           'note',     c.note,
           'at',       c.qualified_at,
           'handledBy', c.handled_by,
           'handledAt', c.handled_at
         ) order by c.qualified_at), jsonb_build_array())
    into v_rows
  from camp_claims c
  join camp_members m on m.line_user_id = c.line_user_id
  where c.period = v_p;

  return jsonb_build_object('success', true, 'period', v_p, 'rows', v_rows);
end;
$fn$;

-- ==========================================================
-- 5  บันทึกว่ารับของไปแล้ว
-- ==========================================================
-- จำกัดสถานะไว้สามค่า กันพิมพ์ผิดแล้วรายงานเพี้ยน

create or replace function camp_admin_set_status(
  p_token    text,
  p_claim_id bigint,
  p_status   text,
  p_note     text default null
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $fn$
declare
  v_err  jsonb;
  v_user jsonb;
  v_n    int;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;

  if p_status not in ('รอรับของ', 'รับแล้ว', 'ยกเลิก') then
    return jsonb_build_object('success', false,
      'message', 'สถานะต้องเป็น รอรับของ หรือ รับแล้ว หรือ ยกเลิก เท่านั้น');
  end if;

  -- officer_session_user คืน rank firstName lastName มา ไม่มีฟิลด์ชื่อเต็ม
  -- ต้องประกอบเอง และไม่เก็บเลขบัตรประชาชนลงในบันทึกนี้
  v_user := officer_session_user(p_token);

  update camp_claims
     set status     = p_status,
         note       = coalesce(nullif(btrim(coalesce(p_note, '')), ''), note),
         handled_by = coalesce(
                        nullif(btrim(concat_ws(' ',
                          nullif(btrim(coalesce(v_user->>'rank', '')), ''),
                          nullif(btrim(coalesce(v_user->>'firstName', '')), ''),
                          nullif(btrim(coalesce(v_user->>'lastName', '')), '')
                        )), ''),
                        'เจ้าหน้าที่'),
         handled_at = now()
   where id = p_claim_id;

  get diagnostics v_n = row_count;

  if v_n = 0 then
    return jsonb_build_object('success', false, 'message', 'ไม่พบรายการนี้');
  end if;

  return jsonb_build_object('success', true, 'message', 'บันทึกเป็น ' || p_status || ' แล้ว');
end;
$fn$;

-- ==========================================================
-- 6  แก้กติกาและเปิดปิดกิจกรรม
-- ==========================================================
-- ยอมให้แก้เฉพาะคีย์ที่ขึ้นต้นด้วย camp เท่านั้น
-- กันไม่ให้ประตูนี้ถูกใช้ไปแก้ค่าวิเคราะห์จุดเสี่ยงซึ่งเป็นคนละเรื่องกัน

create or replace function camp_admin_set(p_token text, p_key text, p_value text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $fn$
declare
  v_err jsonb;
  v_val jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;

  if p_key is null or left(p_key, 4) <> 'camp' then
    return jsonb_build_object('success', false,
      'message', 'แก้ได้เฉพาะค่าตั้งของกิจกรรมที่ขึ้นต้นด้วย camp');
  end if;

  -- ตัวเลขและ true false เก็บเป็นชนิดของมันเอง ที่เหลือเก็บเป็นข้อความ
  if p_value in ('true', 'false') then
    v_val := to_jsonb(p_value = 'true');
  elsif p_value ~ '^[0-9]+$' then
    v_val := to_jsonb(p_value::int);
  else
    v_val := to_jsonb(p_value);
  end if;

  insert into bs_settings (key, val) values (p_key, v_val)
  on conflict (key) do update set val = excluded.val;

  return jsonb_build_object('success', true,
    'message', 'ตั้ง ' || p_key || ' เป็น ' || p_value || ' แล้ว');
end;
$fn$;

-- ==========================================================
-- 7  สิทธิ์เรียกใช้
-- ==========================================================
-- หน้าเจ้าหน้าที่เรียกด้วย anon key แล้วส่ง token ไปให้ตรวจในตัวฟังก์ชันเอง
-- รูปแบบเดียวกับ RPC อื่นของ officer.html

grant execute on function camp_admin_overview(text)                     to anon, authenticated;
grant execute on function camp_admin_people(text, int)                  to anon, authenticated;
grant execute on function camp_admin_claims(text, text)                 to anon, authenticated;
grant execute on function camp_admin_set_status(text, bigint, text, text) to anon, authenticated;
grant execute on function camp_admin_set(text, text, text)              to anon, authenticated;

notify pgrst, 'reload schema';

-- ==========================================================
-- ตรวจผล  คำสั่งสุดท้ายคำสั่งเดียวที่จะแสดงผล
-- ==========================================================

select 'ฟังก์ชันสำหรับเจ้าหน้าที่' as รายการ,
       coalesce((select string_agg(p.proname, ', ' order by p.proname)
                 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                 where n.nspname = 'public' and p.proname like 'camp_admin%'), 'ไม่มี') as ผล
union all
select 'เดือนปัจจุบันที่ระบบใช้', camp_period()
union all
select 'เรียกโดยไม่มี token ต้องถูกปฏิเสธ',
       left(camp_admin_overview('ไม่มีสิทธิ์')::text, 120)
union all
select 'ขั้นต่อไป',
       'deploy Edge Function แล้วทดสอบด้วยบัญชีตัวเอง ก่อนเปิด campEnabled';
