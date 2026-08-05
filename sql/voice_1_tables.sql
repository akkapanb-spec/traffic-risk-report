-- ============================================================
-- เสียงจากประชาชน - ตาราง (1 ของ 2)
--   แบบสอบถาม/ความคิดเห็น · บันทึกการใช้งาน · ปุ่มความรู้สึกในคลิป
-- ============================================================
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
-- ถ้าบรรทัดแรกเป็นข้อความไทยลอย ๆ แปลว่า paste ขาดหัว ให้วางใหม่
--
-- หลักความเป็นส่วนตัวของทั้งชุดนี้
--   ไม่เก็บ IP ไม่เก็บ user agent ไม่ใช้คุกกี้ติดตาม
--   session_key เป็นรหัสสุ่มที่อยู่ใน sessionStorage ปิดแท็บก็หาย
--   ตามรายบุคคลข้ามวันไม่ได้ จึงไม่ต้องขึ้นแบนเนอร์ขอความยินยอมคุกกี้
--   ทุกตารางในไฟล์นี้ประชาชน "เขียนได้ อ่านไม่ได้" เพราะอาจมีคำร้องเรียน
--   หรือเบอร์ติดต่อที่เจ้าตัวไม่ได้ตั้งใจให้คนอื่นเห็น
-- ============================================================

-- ============================================================
-- 1) แบบสอบถามและความคิดเห็น
-- ============================================================
create table if not exists vc_feedback (
  id           bigserial primary key,
  rating       int check (rating between 1 and 5),
  topic        text,                          -- ความถูกต้องของข้อมูล / ใช้งานง่าย / อยากให้เพิ่ม / แจ้งปัญหา / อื่นๆ
  message      text,
  contact      text,                          -- ไม่บังคับ เผื่ออยากให้ติดต่อกลับ
  page         text,                          -- หน้าที่กดส่งมา
  session_key  text,
  status       text not null default 'ใหม่',   -- ใหม่ / รับทราบ / ดำเนินการแล้ว / ปิดเรื่อง
  admin_note   text,
  handled_by   text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index if not exists vc_feedback_new_idx on vc_feedback (status, created_at desc);

-- ============================================================
-- 2) บันทึกการใช้งาน - ไม่ระบุตัวตน
--    ตอบคำถามว่าคนเข้ามาดูเรื่องอะไร และ "ไม่ดู" เรื่องอะไร
--    ฝั่งเว็บสะสมเหตุการณ์ไว้ในหน่วยความจำแล้วส่งทีเดียวตอนปิดหน้า
--    ถ้ายิงทุกการเลื่อนจอ ฐานข้อมูลจะเต็มเร็วมาก
-- ============================================================
create table if not exists vc_events (
  id           bigserial primary key,
  session_key  text not null,
  event        text not null,                 -- view / reach / click
  page         text,                          -- home / report / data / cctv / videos
  section      text,                          -- ชื่อหัวข้อที่เลื่อนไปถึงหรือกด
  device       text,                          -- mobile / desktop
  meta         jsonb,
  created_at   timestamptz not null default now()
);
create index if not exists vc_events_time_idx on vc_events (created_at desc);
create index if not exists vc_events_page_idx on vc_events (page, section);

-- ============================================================
-- 3) ปุ่มความรู้สึกในคลิปรณรงค์
--    ไม่มีปุ่ม "ถูกใจ" โดยตั้งใจ เพราะคลิปหลายอันเป็นเรื่องผู้เสียชีวิต
--    หัวใจในความหมาย "เป็นกำลังใจ" เหมาะกว่า
-- ============================================================
create table if not exists vc_reactions (
  id           bigserial primary key,
  target_type  text not null default 'video',
  target_id    text not null,
  kind         text not null,                 -- heart / sad / idea / share
  session_key  text not null,
  created_at   timestamptz not null default now(),
  unique (target_type, target_id, session_key)   -- หนึ่งคนหนึ่งความรู้สึกต่อหนึ่งคลิป เปลี่ยนใจได้
);
create index if not exists vc_reactions_target_idx on vc_reactions (target_type, target_id);

-- ยอดรวมสำหรับแสดงหน้าเว็บ - เห็นเฉพาะจำนวน ไม่เห็นว่าใครกด
create or replace view vc_reaction_totals as
  select target_type, target_id, kind, count(*)::int as n
    from vc_reactions group by target_type, target_id, kind;

-- ============================================================
-- 4) ยอดสรุปรายวัน - เก็บไว้หลังลบข้อมูลดิบทิ้ง
--    ข้อมูลดิบเก็บ 90 วันพอ หลังจากนั้นเหลือแค่ยอดรวมก็ตอบคำถามได้แล้ว
-- ============================================================
create table if not exists vc_daily (
  day        date not null,
  page       text not null,
  section    text,
  device     text,
  n          int not null default 0,
  sessions   int not null default 0,
  primary key (day, page, section, device)
);

-- ============================================================
-- Row Level Security - เขียนได้ อ่านไม่ได้
--   ไม่สร้าง policy สำหรับ select เลย ประชาชนจึงอ่านตารางเหล่านี้ไม่ได้ทุกทาง
--   การเขียนทำผ่าน RPC ที่เป็น security definer ในไฟล์ที่ 2 เท่านั้น
--   จึงไม่ต้องเปิด insert policy ให้ anon ด้วยซ้ำ
-- ============================================================
alter table vc_feedback  enable row level security;
alter table vc_events    enable row level security;
alter table vc_reactions enable row level security;
alter table vc_daily     enable row level security;

-- ยอดรวม reaction เปิดให้อ่านได้ เพราะเป็นตัวเลขล้วน ไม่บอกว่าใครกด
grant select on vc_reaction_totals to anon, authenticated;
