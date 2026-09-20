-- ============================================================
-- คลังรูปจุดเสี่ยง  ไฟล์ 1 จาก 5  ตารางคลังรูป
-- ============================================================
-- รันเรียง 1 2 3 4 5  ห้ามข้าม
--
-- รูปของแต่ละจุดผูกกับพิกัด ไม่ได้ผูกกับชื่อ
-- ชื่อจุดที่ระบบคำนวณได้เปลี่ยนไปตามข้อมูลในแต่ละรอบ ถ้าจับคู่ด้วยชื่อจะหยิบผิดจุด
-- จับคู่ด้วยพิกัดจึงถูกเสมอ ต่อให้ชื่อสะกดต่างกัน
--
-- ห้ามมีปีกกาในไฟล์นี้ ตัวแก้ไขจะเติมแบ็กสแลชให้
-- ก่อนกด Run ให้ลบสิ่งที่ตัวแก้ไขเติมไว้ท้ายสุดออกก่อน เป็นดอลลาร์ตามด้วยเลขศูนย์
--
-- หนึ่งจุดเก็บรูปเดียว ตามที่ตกลงไว้
-- อยากเปลี่ยนรูปของจุดเดิม ให้แก้แถวเดิม ไม่ใช่เพิ่มแถวใหม่
-- ถ้าเผลอเพิ่มสองแถวที่จุดเดียวกัน ตัวเลือกรูปจะหยิบแถวที่ใกล้กว่ามาใช้
--
-- ตารางนี้ปิดสิทธิ์ทุกทาง เข้าถึงผ่านฟังก์ชันในไฟล์ถัดไปเท่านั้น
-- ลิงก์รูปชี้ไปที่ถังรูปเดิมของระบบ จึงไม่ต้องตั้งถังใหม่

create table if not exists fb_spot_photos (
  id         bigint generated always as identity primary key,
  name       text             not null,
  lat        double precision not null,
  lng        double precision not null,
  url        text             not null,
  note       text,
  active     boolean          not null default true,
  created_by text,
  created_at timestamptz      not null default now(),
  updated_at timestamptz
);

-- ดัชนีเชิงพื้นที่  คลังนี้มีไม่กี่สิบแถว แต่ใส่ไว้ให้ถูกหลักตั้งแต่แรก
create index if not exists fb_spot_photos_geo_idx on fb_spot_photos
  using gist (st_setsrid(st_makepoint(lng, lat), 4326));

alter table fb_spot_photos enable row level security;

-- รัศมีจับคู่รูปกับจุด  หน่วยเป็นเมตร
insert into bs_settings(key, val) values ('spotPhotoRadiusM', to_jsonb(100))
on conflict (key) do nothing;

-- ตรวจ  ต้องได้ตาราง 1 ดัชนี 1 และรัศมี 100
select
  (select count(*) from pg_class where relname = 'fb_spot_photos')            as ตาราง,
  (select count(*) from pg_class where relname = 'fb_spot_photos_geo_idx')    as ดัชนี,
  (select val from bs_settings where key = 'spotPhotoRadiusM')                as รัศมีเมตร,
  (select count(*) from fb_spot_photos)                                       as รูปในคลัง;

-- จบไฟล์  อย่าเคาะบรรทัดใหม่ต่อท้ายบรรทัดนี้ ->