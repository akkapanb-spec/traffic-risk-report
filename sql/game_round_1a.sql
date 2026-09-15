-- ============================================================
-- เกมทดสอบการตัดสินใจ  ไฟล์ที่ 1a จาก 4  ตารางเก็บผล
-- ============================================================
-- รันเรียงตามลำดับ 1a 1b 1c 1d  ห้ามข้าม
-- แยกเป็นไฟล์เล็กเพราะไฟล์รวมสามฟังก์ชันรันไม่ผ่านในตัวแก้ไข
-- ไฟล์ละหนึ่งฟังก์ชัน จึงมีตัวคั่นคู่เดียว และรู้ได้ทันทีว่าพังไฟล์ไหน
--
-- ห้ามมีปีกกาในไฟล์นี้ ตัวแก้ไขจะเติมแบ็กสแลชให้
-- ก่อนกด Run ให้ลบสิ่งที่ตัวแก้ไขเติมไว้ท้ายสุดออกก่อน เป็นดอลลาร์ตามด้วยเลขศูนย์
--
-- ลบของเดิมจากไฟล์ game_score_1.sql ทิ้งด้วย ถ้าเคยรันไปแล้ว
-- ของเดิมยังไม่ได้เปิดใช้จริง จึงไม่มีอะไรสำคัญหาย

drop function if exists game_score_save(uuid, text, int, int);
drop function if exists game_score_top(int);
drop table if exists game_scores;

create table if not exists game_rounds (
  id          bigint generated always as identity primary key,
  device_key  uuid         not null,
  player_name text         not null,
  cycle       int          not null,
  answers     jsonb        not null,
  asked       int          not null,
  correct     int          not null,
  total_ms    bigint       not null,
  points      numeric(8,2) not null,
  played_at   timestamptz  not null default now()
);

create index if not exists game_rounds_device_idx on game_rounds (device_key, cycle);
create index if not exists game_rounds_played_idx on game_rounds (played_at desc);

-- ตั้งใจไม่สร้างนโยบายใด ๆ  ทุกทางเข้าออกผ่านฟังก์ชันในไฟล์ถัดไปเท่านั้น
alter table game_rounds enable row level security;

-- ตรวจ  ต้องได้ตาราง 1 และดัชนี 2
select
  (select count(*) from pg_class where relname = 'game_rounds')                as ตาราง,
  (select count(*) from pg_class
    where relname in ('game_rounds_device_idx', 'game_rounds_played_idx'))    as ดัชนี;

-- จบไฟล์  อย่าเคาะบรรทัดใหม่ต่อท้ายบรรทัดนี้ ->