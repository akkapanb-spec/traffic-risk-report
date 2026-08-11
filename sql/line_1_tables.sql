-- ============================================================
-- LINE Bot ระบบแจ้งข้อมูลจุดเสี่ยงอุบัติเหตุ — ตารางพื้นฐาน
-- ============================================================
-- ไฟล์ที่ 1 จาก 3  ลำดับ: line_1_tables → line_2_messages → line_3_send
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
--
-- ไฟล์นี้ยังไม่ส่งอะไรออก LINE ทั้งสิ้น แค่สร้างที่เก็บข้อมูล
-- รันแล้วระบบเดิมไม่กระทบอะไรเลย
--
-- ใช้ LINE OA คนละตัวกับบอทเวร เพราะ OA หนึ่งตัวตั้ง webhook ได้ที่เดียว
-- ถ้าใช้ตัวเดียวกันจะแย่ง webhook กัน บอทเวรจะตอบคำสั่งไม่ได้
-- ============================================================

set search_path = public, extensions;

-- ============================================================
-- 1) ปลายทางที่จะส่งข้อความไป
-- ============================================================
-- เก็บ group id / user id ของ LINE
-- แยกได้ว่าปลายทางไหนรับการแจ้งเตือนชนิดใดบ้าง เช่น
--   กลุ่มสายตรวจรับเฉพาะผู้เสียชีวิตรายใหม่ (ด่วน)
--   กลุ่มผู้บังคับบัญชารับสรุปประจำวันด้วย
create table if not exists line_targets (
  id           bigint generated always as identity primary key,
  label        text not null,                    -- ชื่อที่คนอ่านเข้าใจ เช่น "กลุ่มงานจราจร สภ.เมืองนว."
  target_id    text not null unique,             -- group id หรือ user id จาก LINE
  target_type  text not null default 'group',    -- group / room / user
  want_death   boolean not null default true,    -- ผู้เสียชีวิตรายใหม่
  want_daily   boolean not null default true,    -- สรุปประจำวัน
  want_weekly  boolean not null default true,    -- สรุปประจำสัปดาห์
  enabled      boolean not null default true,
  note         text,
  created_at   timestamptz not null default now()
);

-- ============================================================
-- 2) คีย์เวิร์ดที่บอทตอบได้
-- ============================================================
-- เก็บเป็นตาราง ไม่ฝังในโค้ด เพราะคำที่คนพิมพ์จริงจะรู้ก็ต่อเมื่อใช้ไปสักพัก
-- แก้คำ เพิ่มคำ ปิดคำ ทำได้ด้วย SQL บรรทัดเดียว ไม่ต้อง deploy อะไรใหม่
--
-- action คือสิ่งที่บอทจะไปทำ ส่วน keyword คือคำที่คนพิมพ์
-- หนึ่ง action มีได้หลายคำ เช่น #ac-d กับ #acc-d ให้ผลเดียวกัน
--
-- ทุกคำขึ้นต้นด้วย # และต้องพิมพ์ตรงตัว ไม่ใช่แค่มีคำนั้นอยู่ในประโยค
-- ตอนแรกใช้คำไทยธรรมดาอย่าง "ตาย" "ประกาศ" แล้วจับแบบมีคำนั้นในประโยค ซึ่งใช้ไม่ได้
-- เพราะกลุ่มนี้คนคุยงานกันจริง ประโยคอย่าง "เมื่อวานมีคนตายแถวสะพาน"
-- จะไปโดนคำว่า ตาย แล้วบอทเด้งสถิติขึ้นมากลางวงสนทนา
create table if not exists line_keywords (
  id         bigint generated always as identity primary key,
  keyword    text not null,                      -- ตัวพิมพ์เล็ก ไม่มีช่องว่างหัวท้าย
  action     text not null,                      -- help / ac-d / ac-w / id
  sort_order int  not null default 100,          -- คำที่เจาะจงกว่าต้องมาก่อน
  enabled    boolean not null default true,
  unique (keyword)
);

-- ============================================================
-- 3) บันทึกสิ่งที่ส่งไปแล้ว
-- ============================================================
-- กันส่งซ้ำเป็นหลัก ไม่ใช่แค่ไว้ดูย้อนหลัง
--
-- ทำไมต้องมี: การแจ้งผู้เสียชีวิตรายใหม่ทำงานด้วยการถามว่า
-- "มีแถวไหนที่ยังไม่เคยแจ้ง" ถ้าไม่จดว่าแจ้งไปแล้ว พอ cron เดินรอบถัดไป
-- มันจะแจ้งรายเดิมซ้ำทุกรอบ ญาติผู้เสียชีวิตไม่ได้อ่าน แต่เจ้าหน้าที่อ่าน
-- และการแจ้งซ้ำจะทำให้คนเลิกเชื่อถือข้อความจากบอทไปเลย
create table if not exists line_sent (
  id         bigint generated always as identity primary key,
  kind       text not null,                      -- death / daily / weekly / reply
  ref_id     text,                               -- id ของแถวต้นทาง เช่น deaths.id
  target_id  text,
  ok         boolean not null default true,
  detail     text,                               -- ข้อความ หรือเหตุผลที่ส่งไม่สำเร็จ
  sent_at    timestamptz not null default now()
);

-- หนึ่งเรื่อง ต่อ หนึ่งปลายทาง ส่งได้ครั้งเดียว
-- ใช้ unique index แทน constraint เพราะ ref_id เป็น null ได้ (สรุปประจำวันไม่มี ref)
create unique index if not exists line_sent_once_idx
  on line_sent (kind, ref_id, target_id) where ref_id is not null;

create index if not exists line_sent_at_idx on line_sent (sent_at desc);

-- ============================================================
-- 4) RLS — ปิดหมด
-- ============================================================
-- group id ของ LINE ต้องไม่หลุด ใครได้ไปแล้วมี token จะยิงข้อความเข้ากลุ่มได้
-- ทั้งสามตารางจึงเปิด RLS โดยไม่สร้าง policy เลย = anon แตะไม่ได้ทุกทาง
-- การเข้าถึงทั้งหมดไปผ่าน SECURITY DEFINER function เท่านั้น
-- (รูปแบบเดียวกับ officers / officer_sessions)
alter table line_targets  enable row level security;
alter table line_keywords enable row level security;
alter table line_sent     enable row level security;

-- ============================================================
-- 5) คีย์เวิร์ดตั้งต้น
-- ============================================================
-- เริ่มแค่ 3 คำที่ใช้งานจริง เพิ่มทีหลังได้ด้วย insert แถวเดียว ไม่ต้อง deploy อะไร
-- #help อ่านรายการจากตารางนี้เอง คำที่เพิ่มใหม่จึงโผล่ในเมนูอัตโนมัติ
-- on conflict do nothing = รันไฟล์นี้ซ้ำได้ ไม่พัง ไม่ทับคำที่แก้ไว้เอง
insert into line_keywords (keyword, action, sort_order) values
  ('#help',  'help',  10),
  ('#ac-d',  'ac-d',  20),
  ('#ac-w',  'ac-w',  30),
  ('#id',    'id',    90)
on conflict (keyword) do nothing;

-- ============================================================
-- ตรวจผลหลังรัน
-- ============================================================
-- ต้องได้ 4 คำ และ 0 ปลายทาง (ยังไม่ได้เพิ่มกลุ่ม เป็นเรื่องปกติ)
-- select count(*) as จำนวนคีย์เวิร์ด from line_keywords;
-- select count(*) as จำนวนปลายทาง from line_targets;
--
-- ปลายทางจะเพิ่มทีหลัง หลังจากเชิญบอทเข้ากลุ่มแล้วพิมพ์ #id ในกลุ่ม
-- เพื่อให้บอทบอก group id ออกมา แล้วค่อยเอามาใส่ที่นี่
