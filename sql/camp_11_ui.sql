-- กิจกรรมแจกหมวกนิรภัย  สองฟังก์ชันที่หน้าเคาน์เตอร์ต้องใช้
-- รันหลัง camp_9_fix_msg.sql
-- ถ้ามี $0 ต่อท้ายไฟล์ ให้ลบออกก่อนกด Run
--
-- ทำไมต้องมีสองตัวนี้เพิ่ม
--   camp_admin_people คืนรายชื่อทั้งหมดสูงสุด 200 คน ใช้ค้นทีละคนหน้าเคาน์เตอร์ไม่ไหว
--   และถ้ามีคนชวนครบพอดีระหว่างรอบ cron เขาจะยังไม่มีสิทธิ์ในระบบ
--   เจ้าหน้าที่ต้องสั่งออกสิทธิ์ได้ทันที ไม่ใช่บอกประชาชนให้รออีกครึ่งชั่วโมง

-- ==========================================================
-- 1  ค้นผู้เข้าร่วมด้วยรหัส
-- ==========================================================
-- คืนสถานะครบทุกอย่างที่ต้องดูก่อนยื่นหมวกให้
-- รวมรายชื่อเพื่อนที่เขาชวนมา เพื่อให้ตรวจสอบย้อนได้ถ้ามีข้อสงสัย

create or replace function camp_admin_find(p_token text, p_code text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $fn$
declare
  v_err    jsonb;
  v_code   text := upper(btrim(coalesce(p_code, '')));
  v_m      camp_members;
  v_need   int  := camp_cfg('campNeedFriends', '5')::int;
  v_period text := camp_period();
  v_claim  camp_claims;
  v_friends jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;

  if v_code = '' then
    return jsonb_build_object('success', false, 'message', 'ยังไม่ได้ใส่รหัส');
  end if;

  select * into v_m from camp_members where ref_code = v_code;
  if v_m.line_user_id is null then
    return jsonb_build_object('success', false, 'message', 'ไม่พบรหัส ' || v_code || ' ในระบบ');
  end if;

  select * into v_claim
    from camp_claims
   where line_user_id = v_m.line_user_id and period = v_period;

  select coalesce(jsonb_agg(jsonb_build_object(
           'code',     f.ref_code,
           'name',     coalesce(f.display_name, 'ไม่ทราบชื่อ'),
           'isFriend', f.is_friend,
           'inGroup',  f.in_group,
           'counts',   (f.is_friend is true and f.in_group is true)
         ) order by f.created_at), jsonb_build_array())
    into v_friends
  from camp_members f
  where f.referred_by = v_m.line_user_id;

  return jsonb_build_object(
    'success',   true,
    'code',      v_m.ref_code,
    'name',      coalesce(v_m.display_name, 'ไม่ทราบชื่อ'),
    'isFriend',  v_m.is_friend,
    'inGroup',   v_m.in_group,
    'checkedAt', v_m.checked_at,
    'joinedAt',  v_m.created_at,
    'need',      v_need,
    'have',      camp_friend_count(v_m.line_user_id),
    'friends',   v_friends,
    'claimId',   v_claim.id,
    'status',    v_claim.status,
    'note',      v_claim.note,
    'handledBy', v_claim.handled_by,
    'handledAt', v_claim.handled_at
  );
end;
$fn$;

-- ==========================================================
-- 2  สั่งออกสิทธิ์เดี๋ยวนี้
-- ==========================================================
-- เรียก camp_award ตัวเดิม แค่ห่อด่านตรวจสิทธิ์ผู้ดูแลไว้ข้างนอก
-- ตรรกะการให้สิทธิ์และเพดานโควตายังเป็นชุดเดียวกับที่ cron ใช้
-- จะได้ไม่มีทางที่กดเองแล้วได้ผลต่างจากที่ระบบทำอัตโนมัติ

create or replace function camp_admin_award(p_token text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $fn$
declare
  v_err jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  return camp_award();
end;
$fn$;

grant execute on function camp_admin_find(text, text) to anon, authenticated;
grant execute on function camp_admin_award(text)      to anon, authenticated;

notify pgrst, 'reload schema';

-- ==========================================================
-- ตรวจผล  คำสั่งสุดท้ายคำสั่งเดียวที่จะแสดงผล
-- ==========================================================

select 'ฟังก์ชันที่เพิ่ม' as รายการ,
       coalesce((select string_agg(p.proname, ', ' order by p.proname)
                 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                 where n.nspname = 'public'
                   and p.proname in ('camp_admin_find', 'camp_admin_award')), 'ไม่มี') as ผล
union all
select 'ค้นด้วยรหัสที่ไม่มีอยู่ ต้องบอกว่าไม่พบ',
       left(camp_admin_find('ไม่มีสิทธิ์', 'ZZZZZZ')::text, 90)
union all
select 'ฟังก์ชันของกิจกรรมทั้งหมดตอนนี้',
       coalesce((select string_agg(p.proname, ', ' order by p.proname)
                 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                 where n.nspname = 'public' and p.proname like 'camp_%'), 'ไม่มี');
