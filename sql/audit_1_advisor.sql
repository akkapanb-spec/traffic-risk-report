-- ============================================================
-- ตรวจว่า warning ของ Security Advisor มาจากไหน
-- ============================================================
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
--
-- ไฟล์นี้ "อ่านอย่างเดียว" ไม่แก้ ไม่สร้าง ไม่ลบอะไรทั้งสิ้น
-- รันซ้ำกี่ครั้งก็ได้ ปลอดภัย
--
-- ที่มาของคำถาม
--   Security Advisor ขึ้น 214 warnings ซึ่งเยอะผิดปกติ
--   สแกนไฟล์ sql/ ทั้งหมดแล้วพบว่าฟังก์ชันที่เราเขียนเอง 108 ตัว
--   ตั้ง search_path ครบทุกตัว จึงไม่น่าใช่ต้นเหตุ
--
--   สมมติฐาน: PostGIS ติดตั้งฟังก์ชันหลายร้อยตัวลงใน schema public
--   ฟังก์ชันพวกนั้นไม่ได้ตั้ง search_path และเราแก้ไม่ได้เพราะเป็นของ extension
--
-- อ่านผลยังไง
--   ถ้าเกือบทั้งหมดอยู่แถวที่เป็นชื่อ extension (postgis / pg_net / ...)
--   แปลว่าเป็นเสียงรบกวน ไม่ต้องทำอะไร
--   ถ้ามีจำนวนมากอยู่แถว "ของเราเอง" แปลว่ามีของตกหล่นจริง ต้องไล่แก้
-- ============================================================

set search_path = public, extensions;

-- ============================================================
-- 1) ฟังก์ชันใน public ที่ไม่ได้ตั้ง search_path — แยกตามที่มา
-- ============================================================
select
  coalesce(e.extname, '>>> ของเราเอง <<<')            as ที่มา,
  count(*)                                            as ไม่ได้ตั้ง_search_path,
  count(*) filter (where p.prosecdef)                 as ในนั้นเป็น_security_definer
from pg_proc p
join pg_namespace n  on n.oid = p.pronamespace and n.nspname = 'public'
left join pg_depend d on d.objid = p.oid and d.deptype = 'e'
left join pg_extension e on e.oid = d.refobjid
where not exists (
  select 1 from unnest(coalesce(p.proconfig, '{}'::text[])) c
   where c like 'search_path=%'
)
group by 1
order by 2 desc;

-- ============================================================
-- 2) ถ้าข้อ 1 มีแถว "ของเราเอง" ให้ดูว่าตัวไหนบ้าง
-- ============================================================
-- ตัวที่เป็น security definer ต้องแก้ก่อน เพราะรันด้วยสิทธิ์เจ้าของฟังก์ชัน
select
  p.proname                                       as ชื่อฟังก์ชัน,
  pg_get_function_identity_arguments(p.oid)       as พารามิเตอร์,
  p.prosecdef                                     as เป็น_security_definer
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace and n.nspname = 'public'
where not exists (
    select 1 from unnest(coalesce(p.proconfig, '{}'::text[])) c
     where c like 'search_path=%'
  )
  and not exists (
    select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e'
  )
order by p.prosecdef desc, p.proname;

-- ============================================================
-- 3) ตารางใน public ที่เปิด RLS แล้วแต่ยังไม่มี policy สักอัน
-- ============================================================
-- ไม่ใช่ความผิดพลาดเสมอไป — officers / officer_sessions ตั้งใจให้เป็นแบบนี้
-- (เปิด RLS ไม่ใส่ policy = ไม่มีใครอ่านได้เลย เข้าถึงผ่าน RPC เท่านั้น)
-- ที่ต้องระวังคือตารางที่ "ตั้งใจให้อ่านได้" แต่ลืมใส่ policy แล้วหน้าเว็บว่างเปล่า
select
  c.relname                                         as ตาราง,
  c.relrowsecurity                                  as เปิด_rls,
  (select count(*) from pg_policies pol
    where pol.schemaname = 'public' and pol.tablename = c.relname) as จำนวน_policy
from pg_class c
join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'public'
where c.relkind = 'r'
order by จำนวน_policy, c.relname;

-- ============================================================
-- 4) ตารางที่ยังไม่ได้เปิด RLS เลย — ตัวนี้ต้องดูให้ดี
-- ============================================================
-- ตารางที่ไม่เปิด RLS = ใครก็อ่านได้ถ้ามีสิทธิ์ select
-- spatial_ref_sys ของ PostGIS จะโผล่ตรงนี้ ซึ่งไม่เป็นไร
-- แต่ถ้ามีตารางของเราโผล่มาด้วย ต้องรีบตรวจว่ามีข้อมูลส่วนบุคคลไหม
select
  c.relname                                          as ตาราง,
  coalesce(e.extname, '>>> ของเราเอง <<<')           as ที่มา
from pg_class c
join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'public'
left join pg_depend d on d.objid = c.oid and d.deptype = 'e'
left join pg_extension e on e.oid = d.refobjid
where c.relkind = 'r' and not c.relrowsecurity
order by 2, 1;
