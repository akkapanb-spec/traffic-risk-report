-- ============================================================
-- คลังรูปจุดเสี่ยง  ไฟล์ 4 จาก 5  บันทึกหรือแก้ไขรูปหนึ่งจุด
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
-- ส่ง p_id เป็นค่าว่างคือเพิ่มใหม่  ส่งเลขมาคือแก้แถวเดิม
-- หนึ่งจุดเก็บรูปเดียว การเปลี่ยนรูปจึงเป็นการแก้แถวเดิม ไม่ใช่เพิ่มแถวใหม่
--
-- เตือนเรื่องพิกัดซ้อนกัน  ถ้าปักหมุดใหม่ใกล้ของเดิมกว่ารัศมี จะคืนคำเตือนกลับไป
-- แต่ยังบันทึกให้ เพราะบางแยกใหญ่มีหลายขา และคนปักหมุดรู้หน้างานดีกว่าระบบ

create or replace function spot_photo_save(
  p_token text,
  p_id    bigint,
  p_name  text,
  p_lat   double precision,
  p_lng   double precision,
  p_url   text,
  p_note  text
) returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $fn$
declare
  v_err  jsonb;
  v_user jsonb;
  v_id   bigint;
  v_near text;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  v_user := officer_session_user(p_token);

  if coalesce(btrim(p_name), '') = '' then
    return jsonb_build_object('success', false, 'message', 'ยังไม่ได้ตั้งชื่อจุด');
  end if;
  if p_lat is null or p_lng is null then
    return jsonb_build_object('success', false, 'message', 'ยังไม่ได้ปักหมุดพิกัด');
  end if;
  if coalesce(btrim(p_url), '') = '' then
    return jsonb_build_object('success', false, 'message', 'ยังไม่ได้แนบรูป');
  end if;

  -- มีรูปอื่นอยู่ใกล้กว่ารัศมีหรือไม่  ไม่นับแถวที่กำลังแก้อยู่
  select string_agg(q.name, chr(10)) into v_near
    from fb_spot_photos q
   where q.active
     and (p_id is null or q.id <> p_id)
     and st_dwithin(
           st_setsrid(st_makepoint(q.lng, q.lat), 4326)::geography,
           st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography,
           coalesce((select (val #>> array[]::text[])::float8 from bs_settings
                      where key = 'spotPhotoRadiusM'), 100));

  if p_id is null then
    insert into fb_spot_photos (name, lat, lng, url, note, created_by)
    values (btrim(p_name), p_lat, p_lng, btrim(p_url), nullif(btrim(coalesce(p_note, '')), ''),
            concat_ws(' ', v_user->>'rank', v_user->>'firstName', v_user->>'lastName'))
    returning id into v_id;
  else
    update fb_spot_photos
       set name = btrim(p_name), lat = p_lat, lng = p_lng, url = btrim(p_url),
           note = nullif(btrim(coalesce(p_note, '')), ''), updated_at = now()
     where id = p_id
    returning id into v_id;

    if v_id is null then
      return jsonb_build_object('success', false, 'message', 'ไม่พบรูปที่จะแก้');
    end if;
  end if;

  return jsonb_build_object('success', true, 'id', v_id,
    'message', case when v_near is null then 'บันทึกแล้ว'
                    else 'บันทึกแล้ว  แต่มีรูปของจุดอื่นอยู่ในรัศมีเดียวกัน ' || chr(10) || v_near
                         || chr(10) || 'ระบบจะหยิบรูปที่ใกล้จุดที่คำนวณได้มากที่สุด' end);
end;
$fn$;

grant execute on function spot_photo_save(text, bigint, text, double precision, double precision, text, text) to anon;

-- ตรวจ  ต้องได้ฟังก์ชัน 1 และเรียกด้วยโทเคนมั่วแล้วต้องถูกปฏิเสธ
select
  (select count(*) from pg_proc where proname = 'spot_photo_save') as ฟังก์ชัน,
  spot_photo_save('ไม่ใช่โทเคนจริง', null, 'ทดสอบ', 15.7, 100.1, 'x', null) as ลองเรียกแบบไม่มีสิทธิ์;

-- จบไฟล์  อย่าเคาะบรรทัดใหม่ต่อท้ายบรรทัดนี้ ->