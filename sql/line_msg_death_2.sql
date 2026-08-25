-- ============================================================
-- รูปแบบข้อความแจ้งผู้เสียชีวิต ตามที่กำหนดใหม่
-- ============================================================
-- เขียนทับฟังก์ชัน line_msg_death เดิมทั้งตัว ไม่แตะส่วนอื่น
-- ไม่แตะงานตั้งเวลา ไม่ส่งอะไรออกไปตอนรัน
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
-- ถ้ามี $0 ค้างอยู่บรรทัดสุดท้าย ให้ลบทิ้งก่อนกด Run
-- ไฟล์นี้ไม่มีวงเล็บปีกกาเลยแม้แต่ตัวเดียว
--
-- ข้อมูลมาจากสองตาราง
--   ตารางผู้เสียชีวิต ให้ วันเวลา เพศ อายุ สถานะ ยานพาหนะ อุปกรณ์นิรภัย ถนน ตำบล พิกัด
--   ตารางอุบัติเหตุ  ให้ สถานที่ ลักษณะถนน และยานพาหนะของคู่กรณีทั้งสองฝ่าย
--
--   สองตารางนี้ไม่มีรหัสผูกกันโดยตรง เพราะตอนออกแบบไม่ได้เผื่อไว้
--   จึงจับคู่ด้วยเวลาเกิดเหตุที่ตรงกันพอดี แล้วเลือกเคสที่พิกัดใกล้ที่สุด
--   ใช้ได้กับเคสที่บันทึกผ่านหน้าเจ้าหน้าที่ เพราะสองตารางเขียนพร้อมกันจากค่าเดียวกัน
--   ส่วนข้อมูลเก่าที่นำเข้าจากระบบเดิมอาจจับคู่ไม่ได้ บรรทัดที่ต้องใช้เคสจะถูกข้ามไป
--
-- ข้อจำกัดที่ต้องรู้
--   ทิศทางการเดินรถ ขาขึ้น ขาล่อง ขาเข้า ขาออก ไม่มีช่องเก็บในระบบเลย
--   จึงพิมพ์ชื่อถนนตามที่เจ้าหน้าที่กรอกมาทั้งก้อน ถ้าเขาพิมพ์ทิศทางไว้เองก็จะติดมาด้วย
--   ถ้าต้องการให้เป็นข้อมูลจริงจัง ต้องเพิ่มช่องในฟอร์มก่อน
--
--   ทุกบรรทัดที่ไม่มีข้อมูลจะถูกข้ามไปทั้งบรรทัด ไม่พิมพ์หัวข้อทิ้งไว้ให้รก
-- ============================================================

-- ============================================================
-- ตัวช่วยเลือกรูปยานพาหนะ
-- ============================================================
-- แยกออกมาเป็นฟังก์ชันเพราะใช้สองที่ในข้อความเดียว ทั้งฝ่ายที่ 1 และฝ่ายที่ 2
-- เทียบด้วยการค้นคำในชื่อ ไม่ใช่เทียบเท่ากันเป๊ะ
-- เพราะชื่อที่เจ้าหน้าที่กรอกมีหลายแบบ เช่น จักรยานยนต์ กับ รถจักรยานยนต์
-- ไม่รู้จักก็คืนรูปกลาง ๆ ไม่ปล่อยว่าง
create or replace function line_veh_icon(p_name text)
returns text
language sql immutable as $lvi$
  select case
    when p_name is null then '🚘'
    when p_name like '%จักรยานยนต์%' then '🏍️'
    when p_name like '%จักรยาน%'     then '🚲'
    when p_name like '%กระบะ%'       then '🛻'
    when p_name like '%บรรทุก%'      then '🚛'
    when p_name like '%พ่วง%'        then '🚛'
    when p_name like '%โดยสาร%'      then '🚌'
    when p_name like '%ตู้%'          then '🚐'
    when p_name like '%สามล้อ%'      then '🛺'
    when p_name like '%เดินเท้า%'     then '🚶'
    when p_name like '%เก๋ง%'        then '🚗'
    when p_name like '%รถยนต์%'      then '🚗'
    else '🚘' end;
$lvi$;

create or replace function line_msg_death(p_id bigint)
returns text
language plpgsql stable security definer set search_path = public, extensions as $lmd$
declare
  d record;
  a record;
  v_lines text[];
  v_n int;
  v_lat text; v_lng text; v_pos int;
  v_latn double precision; v_lngn double precision;
  v_site text;
  v_veh1 text; v_veh2 text;
  v_line text;
begin
  select * into d from deaths where id = p_id;
  if d.id is null then return null; end if;

  -- แยกพิกัดออกมาก่อน ใช้ทั้งทำลิงก์แผนที่และใช้จับคู่กับเคสอุบัติเหตุ
  if coalesce(btrim(d.coordinates), '') <> '' and strpos(d.coordinates, ',') > 0 then
    v_pos := strpos(d.coordinates, ',');
    v_lat := btrim(left(d.coordinates, v_pos - 1));
    v_lng := btrim(substr(d.coordinates, v_pos + 1));
    begin
      v_latn := v_lat::double precision;
      v_lngn := v_lng::double precision;
    exception when others then
      v_latn := null; v_lngn := null;
    end;
  end if;

  -- จับคู่กับเคสอุบัติเหตุ เวลาต้องตรงกันพอดี แล้วเลือกอันที่พิกัดใกล้สุด
  select * into a from accidents ac
   where ac.incident_datetime = d.incident_datetime
   order by case when v_latn is null or ac.latitude is null then 1 else 0 end,
            abs(coalesce(ac.latitude, 0) - coalesce(v_latn, 0))
          + abs(coalesce(ac.longitude, 0) - coalesce(v_lngn, 0))
   limit 1;

  -- ผู้เสียชีวิตในเหตุการณ์เดียวกันอาจมีหลายราย นับจากเวลาและพิกัดที่ตรงกัน
  select count(*) into v_n from deaths dd
   where dd.incident_datetime = d.incident_datetime
     and coalesce(btrim(dd.coordinates), '') = coalesce(btrim(d.coordinates), '');

  v_site := coalesce(
    (select (val #>> array[]::text[]) from bs_settings where key = 'publicSiteUrl'), '');

  -- แบ่งข้อความเป็นสามช่วง หัวเรื่อง รายละเอียด และคำลงท้าย คั่นด้วยบรรทัดว่าง
  -- อ่านในไลน์แล้วสายตาแยกช่วงได้เอง ไม่ต้องไล่อ่านทั้งก้อน
  v_lines := array[
    '🚨 ผู้เสียชีวิตจากอุบัติเหตุจราจร',
    '🚑 เสียชีวิต ' || greatest(v_n, 1) || ' ราย',
    '',
    '🗓️ ' || to_char(timezone('Asia/Bangkok', d.incident_datetime), 'DD/MM/') ||
      (extract(year from timezone('Asia/Bangkok', d.incident_datetime))::int + 543)::text ||
      ' เวลา ' || to_char(timezone('Asia/Bangkok', d.incident_datetime), 'HH24:MI') || ' น.'
  ];

  -- สถานที่กับลักษณะถนน มาจากเคสอุบัติเหตุ ถ้าจับคู่ไม่ได้ใช้เท่าที่มีในตารางผู้เสียชีวิต
  v_line := concat_ws(' · ',
              nullif(btrim(coalesce(a.place, '')), ''),
              nullif(btrim(coalesce(a.road_character, d.road_type, '')), ''));
  if v_line <> '' then
    v_lines := v_lines || array['📍 ' || v_line];
  end if;

  -- ชื่อถนนตามที่กรอกมาทั้งก้อน ทิศทางจะติดมาด้วยถ้าเจ้าหน้าที่พิมพ์ไว้
  v_line := concat_ws(' · ',
              nullif(btrim(coalesce(d.road_name, a.road, '')), ''),
              case when coalesce(btrim(d.subdistrict), '') <> '' then 'ต.' || btrim(d.subdistrict)
                   when coalesce(btrim(coalesce(a.subdistrict, '')), '') <> '' then 'ต.' || btrim(a.subdistrict)
              end);
  if v_line <> '' then
    v_lines := v_lines || array['🛣️ ' || v_line];
  end if;

  -- อายุ 0 คือยังไม่ได้กรอก ไม่ใช่ทารก ต้องไม่พิมพ์ว่า อายุ 0 ปี
  v_lines := v_lines || array[concat_ws(' · ',
    case when btrim(coalesce(d.gender, '')) = 'ชาย' then '👨 ชาย'
         when btrim(coalesce(d.gender, '')) = 'หญิง' then '👩 หญิง'
         else 'ไม่ระบุเพศ' end,
    case when coalesce(d.age, 0) > 0 then 'อายุ ' || d.age || ' ปี' else 'ไม่ระบุอายุ' end,
    nullif(btrim(coalesce(d.status, '')), ''))];

  -- ยานพาหนะคู่กรณีสองฝ่าย มาจากเคสอุบัติเหตุ ฝ่ายที่ 2 อาจไม่มีก็ได้
  v_veh1 := nullif(btrim(coalesce(a.party1->>'vehicle', d.vehicle_type, '')), '');
  v_veh2 := case when btrim(coalesce(a.party2->>'status', 'ไม่มี')) <> 'ไม่มี'
                 then nullif(btrim(coalesce(a.party2->>'vehicle', '')), '') end;
  if v_veh1 is not null then
    v_lines := v_lines || array[
      line_veh_icon(v_veh1) || ' ' || v_veh1 ||
      case when v_veh2 is not null then ' กับ ' || line_veh_icon(v_veh2) || ' ' || v_veh2
           else '' end];
  end if;

  if coalesce(btrim(d.safety_equipment), '') <> '' then
    v_lines := v_lines || array['🦺 อุปกรณ์นิรภัย ' || btrim(d.safety_equipment)];
  end if;

  if v_lat is not null and v_lng is not null then
    v_lines := v_lines || array['🗺️ https://www.google.com/maps?q=' || v_lat || ',' || v_lng];
  end if;

  v_lines := v_lines || array[
    '',
    'งานจราจร สภ.เมืองนครสวรรค์',
    'ขอแสดงความเสียใจมา ณ ที่นี้'
  ];

  if v_site <> '' then
    v_lines := v_lines || array['', 'ติดตามรายละเอียดเพิ่มเติม ได้ที่นี่', v_site];
  end if;

  v_lines := v_lines || array['', 'การสัญจรปลอดภัย คือความห่วงใยของเรา ❤️'];

  return array_to_string(v_lines, chr(10));
end $lmd$;

-- ============================================================
-- ตรวจผลหลังรัน โดยยังไม่ส่งอะไรออกไป
-- ============================================================
-- ดูข้อความของรายล่าสุด เปลี่ยนเลขได้ตามต้องการ
--   select line_msg_death(id) from deaths order by id desc limit 1;
--
-- ถ้าบรรทัดสถานที่หรือยานพาหนะคู่กรณีหายไป แปลว่าจับคู่กับเคสอุบัติเหตุไม่ได้
-- ซึ่งเกิดกับข้อมูลเก่าที่นำเข้าจากระบบเดิมเป็นปกติ ไม่ใช่ความผิดพลาด
-- เคสที่บันทึกผ่านหน้าเจ้าหน้าที่จะจับคู่ได้เสมอ
-- ============================================================
