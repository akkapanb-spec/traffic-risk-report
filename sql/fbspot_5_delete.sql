-- ============================================================
-- คลังรูปจุดเสี่ยง  ไฟล์ 5 จาก 5  ลบรูปหนึ่งจุด
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
-- ลบแถวออกจากคลัง ไฟล์รูปในถังยังอยู่
-- ตั้งใจไม่ลบไฟล์ เพราะถ้าเคยโพสต์ขึ้นเพจไปแล้ว ลบไฟล์จะทำให้โพสต์เก่าภาพหาย

create or replace function spot_photo_delete(p_token text, p_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_err jsonb;
  v_n   int;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;

  delete from fb_spot_photos where id = p_id;
  get diagnostics v_n = row_count;

  if v_n = 0 then
    return jsonb_build_object('success', false, 'message', 'ไม่พบรูปที่จะลบ');
  end if;
  return jsonb_build_object('success', true, 'message', 'ลบแล้ว');
end;
$fn$;

grant execute on function spot_photo_delete(text, bigint) to anon;

-- ตรวจ  ต้องได้ฟังก์ชันครบสี่ตัว
select
  (select count(*) from pg_proc where proname = 'fb_spot_photo')      as ตัวเลือกรูป,
  (select count(*) from pg_proc where proname = 'spot_photo_list')    as รายการ,
  (select count(*) from pg_proc where proname = 'spot_photo_save')    as บันทึก,
  (select count(*) from pg_proc where proname = 'spot_photo_delete')  as ลบ;

-- จบไฟล์  อย่าเคาะบรรทัดใหม่ต่อท้ายบรรทัดนี้ ->