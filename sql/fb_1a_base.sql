-- ============================================================
-- โพสต์เฟซบุ๊กอัตโนมัติ  ไฟล์ 1a  ตารางกันโพสต์ซ้ำ และค่าตั้งต้น
-- ============================================================
-- รันเรียงตามเลขหน้าไฟล์  1a 1b 1c 2a 2b 2c  ห้ามข้าม
--
-- ห้ามมีปีกกาในไฟล์นี้ ตัวแก้ไขจะเติมแบ็กสแลชให้
-- ก่อนกด Run ให้ลบสิ่งที่ตัวแก้ไขเติมไว้ท้ายสุดออกก่อน เป็นดอลลาร์ตามด้วยเลขศูนย์
--
-- รันไฟล์นี้แล้วยังโพสต์ไม่ได้ และยังไม่ต้องมีโทเคน
-- fbEnabled ตั้งเป็นเท็จไว้ ทุกทางเข้าออกต้องผ่านค่านี้
-- ระบบจึงนิ่งสนิทจนกว่าจะเปิดเอง แบบเดียวกับแคมเปญหมวกนิรภัย

-- ตารางกันโพสต์ซ้ำ  คู่ของชนิดกับรหัสอ้างอิงต้องไม่ซ้ำ
-- ทำแบบเดียวกับ line_sent ซึ่งเป็นตัวที่กันข้อความย้อนหลังไม่ให้ถล่มออกไปทีเดียว
--
-- req_id คือเลขคำขอที่ pg_net คืนมา  ต้องเก็บไว้ ไม่ใช่ของประดับ
-- เพราะ pg_net ยิงแล้วไม่รอผล คำตอบจริงจากเฟซบุ๊กไปโผล่อีกตารางหนึ่ง
-- ถ้าไม่เก็บเลขนี้ไว้ จะจับคู่ไม่ได้ว่าคำตอบไหนเป็นของโพสต์ไหน
create table if not exists fb_sent (
  id        bigint generated always as identity primary key,
  kind      text        not null,
  ref_id    text        not null,
  req_id    bigint,
  post_id   text,
  ok        boolean     not null default false,
  note      text,
  posted_at timestamptz not null default now()
);

-- เผื่อกรณีเคยรันไฟล์รุ่นก่อนหน้าไปแล้ว ซึ่งยังไม่มีคอลัมน์นี้
alter table fb_sent add column if not exists req_id bigint;

create unique index if not exists fb_sent_key_idx  on fb_sent (kind, ref_id);
create index        if not exists fb_sent_time_idx on fb_sent (posted_at desc);

-- ตั้งใจไม่สร้างนโยบายใด ๆ  หน้าเว็บสาธารณะไม่ต้องเห็นตารางนี้เลย
alter table fb_sent enable row level security;

-- ค่าตั้งต้น  ใส่เฉพาะคีย์ที่ยังไม่มี รันซ้ำไม่ทับค่าที่ปรับไว้แล้ว
-- เลขเพจมาจากผู้ใช้ ยังไม่ได้ตรวจกับเฟซบุ๊ก จะรู้ว่าถูกหรือไม่ตอนยิงครั้งแรก
insert into bs_settings(key, val) values
  ('fbEnabled',    'false'::jsonb),
  ('fbPageId',     '"147045742304847"'::jsonb),
  ('fbApiVersion', '"v21.0"'::jsonb),
  ('fbWeeklyDays', '7'::jsonb)
on conflict (key) do nothing;

-- ตรวจ  ต้องได้ตาราง 1 ดัชนี 2 ค่าตั้งต้น 4 และยังไม่เปิดใช้งาน
select
  (select count(*) from pg_class where relname = 'fb_sent')                as ตาราง,
  (select count(*) from pg_class
    where relname in ('fb_sent_key_idx', 'fb_sent_time_idx'))              as ดัชนี,
  (select count(*) from bs_settings
    where key in ('fbEnabled','fbPageId','fbApiVersion','fbWeeklyDays'))   as ค่าตั้งต้น,
  (select val from bs_settings where key = 'fbEnabled')                    as เปิดใช้งานแล้วหรือยัง;

-- จบไฟล์  อย่าเคาะบรรทัดใหม่ต่อท้ายบรรทัดนี้ ->