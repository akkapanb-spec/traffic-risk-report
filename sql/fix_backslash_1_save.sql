-- ============================================================
-- ซ่อมคำสั่งบันทึกอุบัติเหตุ — เขียนใหม่โดยไม่ใช้วงเล็บปีกกาเลย
-- ============================================================
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
-- ถ้ามี $0 ค้างอยู่บรรทัดสุดท้าย ให้ลบทิ้งก่อนกด Run
--
-- อาการ
--   บันทึกข้อมูลอุบัติเหตุไม่ได้ ขึ้นว่า
--   invalid input syntax for type json — Token "\" is invalid
--
-- สาเหตุ
--   ช่องแก้ไข SQL ของ Supabase เติมแบ็กสแลชหน้าวงเล็บปีกกาปิดทุกตัว
--   เวลาลากไฟล์ไปวาง เพราะเข้าใจผิดว่าเป็นแม่แบบโค้ด ไม่ใช่ข้อความธรรมดา
--
--   ตอนติดตั้งครั้งก่อน ค่าว่างของ jsonb ที่เขียนด้วยปีกกาเปิดปิดติดกัน
--   จึงถูกแทรกแบ็กสแลชคั่นกลาง แล้วถูกบันทึกลงฐานข้อมูลไปแบบนั้น
--   คำสั่งจึงพังทุกครั้งที่ทำงานถึงบรรทัดนั้น
--
--   ตรวจแล้วพบ 4 บรรทัดที่เสียหาย คือบรรทัด 23, 38, 48 และ 63
--   ทุกบรรทัดเป็นบรรทัดที่มีค่าว่างของ jsonb ทั้งหมด
--   ส่วนบรรทัดที่ใช้วงเล็บเหลี่ยมไม่โดนเลย เพราะตัวแก้ไขสนใจแค่ปีกกาปิด
--
-- วิธีซ่อม
--   เขียนคำสั่งใหม่ทั้งตัวโดยไม่พิมพ์วงเล็บปีกกาเลยแม้แต่ตัวเดียว
--   ใช้ jsonb_build_object() ซึ่งคืนค่าวัตถุว่าง แทนการพิมพ์ปีกกาเปิดปิด
--   และใช้ jsonb_build_array() ซึ่งคืนค่าอาเรย์ว่าง แทนวงเล็บเหลี่ยม
--   ผลลัพธ์เหมือนเดิมทุกประการ แต่ไม่มีอะไรให้ตัวแก้ไขแทรกได้อีก
--
--   ตรรกะการทำงานคงเดิมทุกบรรทัด รวมถึงการแตกข้อมูลลงตารางผู้เสียชีวิต
--   และผู้บาดเจ็บ กับการเติมค่า "เสียชีวิตที่เกิดเหตุ" ที่เพิ่มไว้ก่อนหน้านี้
-- ============================================================

create or replace function officer_save_accident(p_token text, p_payload jsonb, p_images jsonb)
returns jsonb
language plpgsql security definer set search_path = public as $osa$
declare
  v_user jsonb;
  v_code text;
  v_occurred timestamptz;
  v_loc jsonb;
  v_persons jsonb := jsonb_build_array();
  v_p jsonb;
  v_pass jsonb;
  v_vehicle text;
  v_injury text;
  i int;
begin
  v_user := officer_session_user(p_token);
  if v_user is null then
    return jsonb_build_object('success', false, 'code', 'AUTH_REQUIRED',
      'message', 'เซสชันหมดอายุ กรุณาเข้าสู่ระบบอีกครั้ง');
  end if;

  v_occurred := (p_payload->>'occurredAt')::timestamptz;
  if v_occurred is null then
    return jsonb_build_object('success', false, 'message', 'วันที่และเวลาเกิดเหตุไม่ถูกต้อง');
  end if;

  v_loc := coalesce(p_payload->'location', jsonb_build_object());
  v_code := 'ACC-' || to_char(now() at time zone 'Asia/Bangkok', 'YYYYMMDD-HH24MISS')
            || '-' || lpad(floor(random() * 9000 + 1000)::text, 4, '0');

  insert into accidents(
    incident_datetime, recorded_at, accident_code,
    officer_rank, officer_name, officer_national_id, officer_code,
    party1, party2,
    place, road_character, road_character_other, road, local_authority,
    subdistrict, district, province, cause, latitude, longitude, details,
    images, verify_status
  ) values (
    v_occurred, now(), v_code,
    v_user->>'rank', (v_user->>'firstName') || ' ' || (v_user->>'lastName'),
    v_user->>'nationalId', v_user->>'policeCode',
    coalesce(p_payload->'party1', jsonb_build_object()),
    coalesce(p_payload->'party2', jsonb_build_object()),
    v_loc->>'place', v_loc->>'roadCharacter', v_loc->>'roadCharacterOther',
    v_loc->>'road', v_loc->>'localAuthority', v_loc->>'subdistrict',
    coalesce(v_loc->>'district', 'เมืองนครสวรรค์'),
    coalesce(v_loc->>'province', 'นครสวรรค์'),
    v_loc->>'cause', nullif(v_loc->>'latitude', '')::double precision,
    nullif(v_loc->>'longitude', '')::double precision, v_loc->>'details',
    coalesce(p_images, jsonb_build_array()), 'รอตรวจสอบ'
  );

  -- รวมรายชื่อบุคคลทั้งหมด ฝ่าย 1 กับผู้โดยสาร แล้วต่อด้วยฝ่าย 2 กับผู้โดยสาร
  v_p := coalesce(p_payload->'party1', jsonb_build_object());
  v_vehicle := case when v_p->>'vehicle' = 'อื่นๆ' and coalesce(v_p->>'vehicleOther', '') <> ''
                    then v_p->>'vehicleOther' else coalesce(v_p->>'vehicle', '') end;
  v_persons := v_persons || jsonb_build_array(jsonb_build_object(
    'party', 'ฝ่ายที่1', 'type', coalesce(v_p->>'status', 'ผู้ขับขี่'), 'gender', v_p->>'gender',
    'age', v_p->>'age', 'injury', v_p->>'injury', 'safety', v_p->>'safety', 'vehicle', v_vehicle));

  i := 0;
  for v_pass in select value from jsonb_array_elements(coalesce(v_p->'passengers', jsonb_build_array()))
  loop
    i := i + 1;
    v_persons := v_persons || jsonb_build_array(jsonb_build_object(
      'party', 'ฝ่ายที่1', 'type', 'ผู้โดยสารที่' || i, 'gender', v_pass->>'gender',
      'age', v_pass->>'age', 'injury', v_pass->>'injury', 'safety', v_pass->>'safety',
      'vehicle', v_vehicle));
  end loop;

  v_p := coalesce(p_payload->'party2', jsonb_build_object());
  if coalesce(v_p->>'status', 'ไม่มี') <> 'ไม่มี' then
    v_vehicle := case when v_p->>'vehicle' = 'อื่นๆ' and coalesce(v_p->>'vehicleOther', '') <> ''
                      then v_p->>'vehicleOther' else coalesce(v_p->>'vehicle', '') end;
    v_persons := v_persons || jsonb_build_array(jsonb_build_object(
      'party', 'ฝ่ายที่2', 'type', coalesce(v_p->>'status', 'ผู้ขับขี่'), 'gender', v_p->>'gender',
      'age', v_p->>'age', 'injury', v_p->>'injury', 'safety', v_p->>'safety', 'vehicle', v_vehicle));

    i := 0;
    for v_pass in select value from jsonb_array_elements(coalesce(v_p->'passengers', jsonb_build_array()))
    loop
      i := i + 1;
      v_persons := v_persons || jsonb_build_array(jsonb_build_object(
        'party', 'ฝ่ายที่2', 'type', 'ผู้โดยสารที่' || i, 'gender', v_pass->>'gender',
        'age', v_pass->>'age', 'injury', v_pass->>'injury', 'safety', v_pass->>'safety',
        'vehicle', v_vehicle));
    end loop;
  end if;

  -- แยกลงตารางผู้เสียชีวิตและผู้บาดเจ็บ ตรรกะเดิมทุกบรรทัด
  for v_pass in select value from jsonb_array_elements(v_persons)
  loop
    v_injury := coalesce(v_pass->>'injury', '');
    if v_injury = 'เสียชีวิต' then
      insert into deaths(incident_datetime, age, gender, status, vehicle_type,
        safety_equipment, road_name, subdistrict, coordinates, cause, col_g)
      values (v_occurred, nullif(v_pass->>'age', '')::int, v_pass->>'gender', v_pass->>'type',
        v_pass->>'vehicle', v_pass->>'safety', v_loc->>'road', v_loc->>'subdistrict',
        coalesce(v_loc->>'latitude', '') || ', ' || coalesce(v_loc->>'longitude', ''),
        v_loc->>'cause', 'เสียชีวิตที่เกิดเหตุ');
    elsif v_injury in ('หมดสติ', 'สาหัส', 'เล็กน้อย') then
      insert into injuries(incident_datetime, raw)
      values (v_occurred, jsonb_build_object(
        'severity', v_injury, 'gender', v_pass->>'gender', 'age', v_pass->>'age',
        'vehicle', v_pass->>'vehicle', 'safety', v_pass->>'safety',
        'person_type', v_pass->>'type', 'place', v_loc->>'place', 'road', v_loc->>'road',
        'subdistrict', v_loc->>'subdistrict', 'lat', v_loc->>'latitude',
        'lng', v_loc->>'longitude', 'acc_code', v_code,
        'image_url', coalesce(p_images->>0, '')));
    end if;
  end loop;

  return jsonb_build_object('success', true, 'message', 'บันทึกข้อมูลอุบัติเหตุสำเร็จ',
    'accidentId', v_code, 'imageUrls', coalesce(p_images, jsonb_build_array()));
end $osa$;

grant execute on function officer_save_accident(text, jsonb, jsonb) to anon, authenticated;

-- ============================================================
-- ตรวจผลหลังรัน
-- ============================================================
-- กลับไปที่หน้าบันทึกข้อมูลอุบัติเหตุ กรอกเคสแล้วกดบันทึกได้เลย
--
-- ถ้าอยากยืนยันว่าซ่อมติดจริง ให้รัน sql/find_backslash_damage.sql อีกครั้ง
-- ชื่อ officer_save_accident ต้องหายไปจากรายการ
-- ส่วนชื่ออื่นที่ยังอยู่ เป็นแบ็กสแลชที่ถูกต้องของรูปแบบการตรวจข้อมูล ไม่ต้องแก้
-- ============================================================
