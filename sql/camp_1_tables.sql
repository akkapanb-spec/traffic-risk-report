-- กิจกรรมแจกหมวกนิรภัย  ตารางและค่าตั้งต้น
-- รันไฟล์นี้เป็นไฟล์แรกของชุด camp_
-- ถ้ามี $0 ต่อท้ายไฟล์ ให้ลบออกก่อนกด Run
--
-- กติกาที่ระบบจะบังคับ
--   ผู้เข้าร่วมจะได้หมวก ก็ต่อเมื่อมีเพื่อนที่เขาชวนมา ครบตามจำนวนที่กำหนด
--   และเพื่อนแต่ละคนต้องผ่านสองข้อพร้อมกัน
--     1 ยังเป็นเพื่อนกับบัญชีทางการอยู่
--     2 ยังอยู่ในกลุ่มไลน์อยู่
--   ตรวจ ณ เวลาที่ตัดสิน ไม่ใช่นับสะสม ใครออกไปแล้วยอดจะลดลงเอง

-- ==========================================================
-- 1  ผู้เข้าร่วม
-- ==========================================================
-- เก็บทุกคนที่บอทรู้จัก ไม่ว่าจะมาเองหรือมีคนชวน
-- line_user_id คือรหัสที่ไลน์ออกให้ ใช้ร่วมกันได้ทั้งตอนเช็คว่าเป็นเพื่อน
-- และตอนเช็คว่าอยู่ในกลุ่ม เพราะมาจากช่องทาง Messaging API เดียวกัน

create table if not exists camp_members (
  line_user_id  text primary key,
  display_name  text,
  ref_code      text not null,
  referred_by   text,
  is_friend     boolean,
  in_group      boolean,
  checked_at    timestamptz,
  created_at    timestamptz not null default now()
);

create unique index if not exists camp_members_code_uq on camp_members (ref_code);
create index if not exists camp_members_ref_idx on camp_members (referred_by);

comment on column camp_members.ref_code is
  'รหัสประจำตัวที่เอาไปชวนเพื่อน ไม่ใช้ตัวอักษรที่อ่านสับสน';
comment on column camp_members.referred_by is
  'line_user_id ของคนที่ชวนคนนี้มา ว่างแปลว่ามาเอง ไม่นับให้ใคร';
comment on column camp_members.is_friend is
  'ผลการถามไลน์ครั้งล่าสุด null คือยังไม่เคยตรวจ';

-- ==========================================================
-- 2  สิทธิ์รับของรางวัล
-- ==========================================================
-- แยกตารางเพราะสิทธิ์เป็นของถาวร ต่างจากยอดเพื่อนที่ขึ้นลงได้ตลอด
-- เมื่อได้สิทธิ์แล้วต้องไม่หลุดเพราะเพื่อนออกจากกลุ่มทีหลัง
-- unique กันไม่ให้คนเดียวได้สิทธิ์ซ้ำในเดือนเดียวกัน

create table if not exists camp_claims (
  id            bigint generated always as identity primary key,
  line_user_id  text not null references camp_members (line_user_id),
  period        text not null,
  friends_at_claim int not null,
  status        text not null default 'รอรับของ',
  note          text,
  qualified_at  timestamptz not null default now(),
  handled_by    text,
  handled_at    timestamptz
);

create unique index if not exists camp_claims_person_period_uq
  on camp_claims (line_user_id, period);

comment on column camp_claims.period is 'เดือนที่ได้สิทธิ์ ตามปีพุทธศักราช เช่น 2569-08';
comment on column camp_claims.status is 'รอรับของ หรือ รับแล้ว หรือ ยกเลิก';
comment on column camp_claims.friends_at_claim is 'จำนวนเพื่อนที่ผ่านครบ ณ วินาทีที่ได้สิทธิ์ เก็บไว้เป็นหลักฐาน';

-- ==========================================================
-- 3  ปิดตายไม่ให้ใครอ่านตรง
-- ==========================================================
-- ทั้งสองตารางมีรหัสผู้ใช้ไลน์ซึ่งเป็นข้อมูลส่วนบุคคล
-- เปิด RLS โดยไม่ใส่ policy สักข้อ แปลว่า anon เข้าไม่ถึงทุกทาง
-- การเข้าถึงทั้งหมดต้องผ่าน RPC ที่เป็น security definer เท่านั้น
-- รูปแบบเดียวกับตาราง officers และ officer_sessions

alter table camp_members enable row level security;
alter table camp_claims  enable row level security;

revoke all on camp_members from anon, authenticated;
revoke all on camp_claims  from anon, authenticated;

-- ==========================================================
-- 4  ตัวออกรหัสชวนเพื่อน
-- ==========================================================
-- ตัดตัวอักษรที่อ่านสับสนออกหมด ไม่มี O กับ 0 ไม่มี I กับ 1 ไม่มี S กับ 5
-- เพราะรหัสนี้คนต้องอ่านจากหน้าจอแล้วบอกต่อ
-- วนจนกว่าจะได้รหัสที่ยังไม่มีใครใช้ ปกติได้ตั้งแต่รอบแรก

create or replace function camp_new_code()
returns text
language plpgsql
volatile
as $fn$
declare
  v_alphabet constant text := 'ACDEFGHJKLMNPQRTUVWXY34679';
  v_code text;
  v_i    int;
  v_try  int := 0;
begin
  loop
    v_try := v_try + 1;
    v_code := '';
    for v_i in 1..6 loop
      v_code := v_code || substr(v_alphabet, 1 + floor(random() * length(v_alphabet))::int, 1);
    end loop;

    if not exists (select 1 from camp_members where ref_code = v_code) then
      return v_code;
    end if;

    -- กันวนไม่รู้จบถ้าวันหนึ่งรหัสเต็ม ซึ่งต้องมีสมาชิกหลายร้อยล้านคนถึงจะเกิด
    if v_try > 50 then
      raise exception 'ออกรหัสชวนเพื่อนไม่สำเร็จหลังพยายาม 50 ครั้ง';
    end if;
  end loop;
end;
$fn$;

-- ==========================================================
-- 5  ค่าตั้งของกิจกรรม
-- ==========================================================
-- เก็บไว้ใน bs_settings เหมือนค่าอื่นในระบบ
-- จะได้แก้กติกาด้วย update บรรทัดเดียว ไม่ต้องกลับมาแก้ฟังก์ชัน
--
-- campGroupId ยังว่างอยู่ ต้องเอารหัสกลุ่มที่ขึ้นต้นด้วย C มาใส่ก่อนระบบจึงจะตรวจได้
-- รหัสนั้นได้จากการเชิญบอทเข้ากลุ่มแล้วบอทตอบกลับมาเท่านั้น
-- ลิงก์เชิญกลุ่มแปลงเป็นรหัสกลุ่มไม่ได้

insert into bs_settings (key, val) values
  ('campEnabled',      to_jsonb(false)),
  ('campNeedFriends',  to_jsonb(5)),
  ('campMonthlyQuota', to_jsonb(5)),
  ('campGroupId',      to_jsonb(''::text)),
  ('campOaUrl',        to_jsonb('https://line.me/R/ti/p/@690vodvg'::text)),
  ('campGroupUrl',     to_jsonb('https://line.me/R/ti/g/jPPvVrVU_r'::text)),
  ('campPrizeName',    to_jsonb('หมวกนิรภัย'::text))
on conflict (key) do nothing;

-- ==========================================================
-- ตรวจผลการติดตั้ง  คำสั่งสุดท้ายคำสั่งเดียวที่จะแสดงผล
-- ==========================================================

select 'ตาราง camp_members'  as รายการ,
       (select count(*)::text from camp_members) || ' แถว' as ผล
union all
select 'ตาราง camp_claims',
       (select count(*)::text from camp_claims) || ' แถว'
union all
select 'RLS ปิดตายแล้วหรือยัง',
       (select string_agg(relname || ' = ' || relrowsecurity::text, ', ')
        from pg_class where relname in ('camp_members', 'camp_claims'))
union all
select 'ตัวออกรหัสชวนเพื่อน ทดลองสุ่มมาสามรหัส',
       (select string_agg(camp_new_code(), '  ') from generate_series(1, 3))
union all
select 'ค่าตั้งที่ใส่ไว้',
       (select string_agg(key || ' = ' || val::text, '   ' order by key)
        from bs_settings where key like 'camp%')
union all
select 'สิ่งที่ยังขาด',
       case when coalesce((select val #>> array[]::text[] from bs_settings where key = 'campGroupId'), '') = ''
            then 'ยังไม่มี campGroupId ต้องเชิญบอทเข้ากลุ่มเพื่อเอารหัสที่ขึ้นต้นด้วย C มาใส่ก่อน'
            else 'ครบแล้ว' end;
