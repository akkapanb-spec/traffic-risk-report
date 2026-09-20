-- ============================================================
-- คลังรูปจุดเสี่ยง  ไฟล์ 3 จาก 5  รายการรูปในคลัง สำหรับผู้ดูแล
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
-- คืนทุกแถวพร้อมพิกัดและลิงก์รูป ให้หน้าจัดการเอาไปแสดงบนแผนที่
-- ผู้ดูแลระบบเท่านั้น ตามที่ตกลงไว้

create or replace function spot_photo_list(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_err jsonb;
  v_rows jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;

  select coalesce(jsonb_agg(jsonb_build_object(
           'id', p.id, 'name', p.name, 'lat', p.lat, 'lng', p.lng,
           'url', p.url, 'note', p.note, 'active', p.active,
           'createdBy', p.created_by,
           'createdAt', to_char(p.created_at at time zone 'Asia/Bangkok', 'DD/MM/YYYY HH24:MI'))
         order by p.name), jsonb_build_array())
    into v_rows
    from fb_spot_photos p;

  return jsonb_build_object('success', true, 'rows', v_rows,
    'radiusM', coalesce((select (val #>> array[]::text[])::int from bs_settings
                          where key = 'spotPhotoRadiusM'), 100));
end;
$fn$;

grant execute on function spot_photo_list(text) to anon;

-- ตรวจ  ต้องได้ฟังก์ชัน 1 และเรียกด้วยโทเคนมั่วแล้วต้องถูกปฏิเสธ
select
  (select count(*) from pg_proc where proname = 'spot_photo_list') as ฟังก์ชัน,
  spot_photo_list('ไม่ใช่โทเคนจริง')                                as ลองเรียกแบบไม่มีสิทธิ์;

-- จบไฟล์  อย่าเคาะบรรทัดใหม่ต่อท้ายบรรทัดนี้ ->