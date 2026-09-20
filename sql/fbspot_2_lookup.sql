-- ============================================================
-- คลังรูปจุดเสี่ยง  ไฟล์ 2 จาก 5  ตัวเลือกรูปจากพิกัด
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
-- รับพิกัดของจุดเข้าไป คืนลิงก์รูปที่ใกล้ที่สุดภายในรัศมี
-- ไม่มีรูปในรัศมีนั้นคืนค่าว่าง การ์ดจะไม่ใส่รูปให้แถวนั้น
-- ตั้งใจไม่ขยายรัศมีเองเมื่อหาไม่เจอ เพราะรูปผิดจุดบนเพจราชการแย่กว่าไม่มีรูป

create or replace function fb_spot_photo(p_lat double precision, p_lng double precision)
returns text
language sql
stable
security definer
set search_path = public, extensions
as $fn$
  select p.url
    from fb_spot_photos p
   where p.active
     and p_lat is not null
     and p_lng is not null
     and st_dwithin(
           st_setsrid(st_makepoint(p.lng, p.lat), 4326)::geography,
           st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography,
           coalesce((select (val #>> array[]::text[])::float8 from bs_settings
                      where key = 'spotPhotoRadiusM'), 100))
   order by st_distance(
           st_setsrid(st_makepoint(p.lng, p.lat), 4326)::geography,
           st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography)
   limit 1
$fn$;

-- หน้าเว็บสาธารณะไม่ต้องเรียก  ตัววาดภาพเรียกด้วยสิทธิ์ของระบบ
revoke execute on function fb_spot_photo(double precision, double precision) from public, anon, authenticated;

-- ตรวจ  ต้องได้ฟังก์ชัน 1 และลองเรียกด้วยพิกัดกลางเมืองแล้วไม่พัง
-- คลังยังว่างจึงคืนค่าว่าง ซึ่งถูกต้อง
select
  (select count(*) from pg_proc where proname = 'fb_spot_photo')  as ฟังก์ชัน,
  coalesce(fb_spot_photo(15.7047, 100.1372), 'ไม่มีรูปในรัศมี')    as ลองเรียก;

-- จบไฟล์  อย่าเคาะบรรทัดใหม่ต่อท้ายบรรทัดนี้ ->