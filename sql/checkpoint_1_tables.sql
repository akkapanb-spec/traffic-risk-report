-- ============================================================
-- จุดตรวจกวดขันวินัยจราจร และชุดตรวจวัดแอลกอฮอล์ - ตาราง (1 ของ 2)
-- ============================================================
-- ต้องรัน blackspot_1..4 ก่อน (ใช้ bs_settings) และควรรัน roadnet_1 ก่อน
-- ถ้าอยากผูกจุดตรวจกับถนนในโครงข่าย
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
-- ถ้าบรรทัดแรกเป็นข้อความไทยลอย ๆ แปลว่า paste ขาดหัว ให้วางใหม่
--
-- เก็บวันที่เป็น date ตามปฏิทินสากล (ค.ศ.) เหมือนทั้งระบบ
-- ส่วนการแสดงผลเป็น พ.ศ. ทำที่ฝั่งเว็บ จะได้คำนวณช่วงวันที่ได้ตรง
-- ============================================================

create table if not exists cp_checkpoints (
  id              bigserial primary key,
  kind            text not null,                     -- จุดตรวจกวดขันวินัยจราจร / ชุดตรวจวัดปริมาณแอลกอฮอล์
  duty_date       date not null,                     -- วันที่ตั้งจุดตรวจ
  start_time      time,
  end_time        time,
  place           text,                              -- ชื่อจุด เช่น หน้าโรงพยาบาลสวรรค์ประชารักษ์
  road_id         bigint references rn_roads(id) on delete set null,
  road_name       text,                              -- เผื่อกรณีถนนยังไม่มีในโครงข่าย
  subdistrict     text,
  in_municipality boolean not null default false,
  latitude        double precision,
  longitude       double precision,
  commander       text,                              -- หัวหน้าชุด
  officer_count   int,
  vehicles_checked int,                              -- จำนวนรถที่เรียกตรวจ
  breath_tested   int,                               -- จำนวนที่เป่าวัดแอลกอฮอล์
  arrest_count    int not null default 0,            -- ระบบนับให้จาก cp_arrests
  note            text,
  created_by      text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index if not exists cp_checkpoints_date_idx on cp_checkpoints (duty_date desc);
create index if not exists cp_checkpoints_kind_idx on cp_checkpoints (kind);

-- ============================================================
-- ผลการดำเนินการรายคน - 10 รสขม และข้อหาอื่น
--   หนึ่งแถวคือผู้ถูกจับหนึ่งราย หนึ่งข้อหา
--   คนเดียวโดนหลายข้อหาให้บันทึกหลายแถว person_ref เดียวกัน
-- ============================================================
create table if not exists cp_arrests (
  id            bigserial primary key,
  checkpoint_id bigint not null references cp_checkpoints(id) on delete cascade,
  person_ref    text,                                -- รหัสอ้างอิงคนเดียวกันเมื่อโดนหลายข้อหา
  gender        text,                                -- ชาย / หญิง
  age           int,
  vehicle       text,                                -- จักรยานยนต์ / รถยนต์เก๋ง / กระบะ / รถตู้ / รถบรรทุก / อื่นๆ
  charge        text not null,                       -- ข้อหา หนึ่งใน 10 รสขม หรือข้อความที่ระบุเอง
  charge_group  text,                                -- รสขม หรือ อื่นๆ ใช้แยกสถิติ
  alcohol_mg    numeric(6,1),                        -- ปริมาณแอลกอฮอล์ มก.% เฉพาะข้อหาเมาสุรา
  fine_amount   numeric(10,2),
  note          text,
  created_at    timestamptz not null default now()
);
create index if not exists cp_arrests_cp_idx on cp_arrests (checkpoint_id);
create index if not exists cp_arrests_charge_idx on cp_arrests (charge);

-- ============================================================
-- รายการข้อหามาตรฐาน 10 รสขม - แก้เพิ่มลบได้จากหน้าเว็บ
--   sort_order คุมลำดับที่โผล่ใน dropdown
-- ============================================================
create table if not exists cp_charges (
  id         bigserial primary key,
  name       text not null unique,
  grp        text not null default 'รสขม',
  sort_order int not null default 99,
  active     boolean not null default true
);

insert into cp_charges(name, grp, sort_order) values
  ('ขับรถเร็วเกินกำหนด',              'รสขม', 1),
  ('เมาสุรา',                          'รสขม', 2),
  ('ไม่สวมหมวกนิรภัย',                'รสขม', 3),
  ('ไม่คาดเข็มขัดนิรภัย',             'รสขม', 4),
  ('ไม่มีใบอนุญาตขับขี่',             'รสขม', 5),
  ('ฝ่าฝืนสัญญาณไฟจราจร',            'รสขม', 6),
  ('ขับรถย้อนศร',                      'รสขม', 7),
  ('แซงในที่คับขัน',                   'รสขม', 8),
  ('ใช้โทรศัพท์ขณะขับรถ',             'รสขม', 9),
  ('รถจักรยานยนต์ไม่ปลอดภัย',        'รสขม', 10),
  ('ดัดแปลงสภาพรถ',                    'อื่นๆ', 20),
  ('ไม่ติดแผ่นป้ายทะเบียน',           'อื่นๆ', 21),
  ('ท่อไอเสียเสียงดัง',                'อื่นๆ', 22),
  ('บรรทุกเกินอัตรา',                  'อื่นๆ', 23)
on conflict (name) do nothing;

-- ============================================================
-- นับจำนวนผู้ถูกจับกลับไปที่หัวจุดตรวจอัตโนมัติ
--   เก็บเป็นจำนวนคน ไม่ใช่จำนวนข้อหา คนเดียวหลายข้อหานับหนึ่ง
-- ============================================================
create or replace function cp_sync_arrest_count() returns trigger
language plpgsql as $$
declare v_cp bigint;
begin
  v_cp := coalesce(new.checkpoint_id, old.checkpoint_id);
  update cp_checkpoints c
     set arrest_count = (
       select count(distinct coalesce(a.person_ref, a.id::text))
         from cp_arrests a where a.checkpoint_id = v_cp)
   where c.id = v_cp;
  return null;
end $$;

drop trigger if exists cp_arrests_count_trg on cp_arrests;
create trigger cp_arrests_count_trg after insert or update or delete
  on cp_arrests for each row execute function cp_sync_arrest_count();

-- ============================================================
-- Row Level Security
--   ข้อมูลผู้ถูกจับเป็นข้อมูลส่วนบุคคล ปิดการอ่านจาก anon ทั้งหมด
--   หน้าประชาชนไม่ต้องเห็น เจ้าหน้าที่เข้าผ่าน RPC เท่านั้น
-- ============================================================
alter table cp_checkpoints enable row level security;
alter table cp_arrests     enable row level security;
alter table cp_charges     enable row level security;

drop policy if exists "public read" on cp_charges;
create policy "public read" on cp_charges for select using (true);
-- cp_checkpoints / cp_arrests: ไม่สร้าง policy = ปิดการอ่านตรงจาก anon ทั้งหมด
