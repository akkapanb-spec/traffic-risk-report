-- ============================================================
-- แก้ข้อความแจ้งผู้เสียชีวิต 2 จุด เพศ และยานพาหนะอื่นๆ
-- ============================================================
-- ต้องรัน line_msg_death_2.sql มาก่อน ไฟล์นี้เขียนทับฟังก์ชันเดิมทั้งตัว
-- ไม่แตะงานตั้งเวลา ไม่ส่งอะไรออกไปตอนรัน
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
-- ถ้ามี $0 ค้างอยู่บรรทัดสุดท้าย ให้ลบทิ้งก่อนกด Run
-- ไฟล์นี้ไม่มีวงเล็บปีกกาเลยแม้แต่ตัวเดียว
--
-- จุดที่ 1 เพศขึ้นว่าไม่ระบุ ทั้งที่กรอกไว้แล้ว
--   ฟอร์มบันทึกเก็บค่าเป็น ผู้ชาย กับ ผู้หญิง
--   แต่ข้อมูลเก่าที่นำเข้าจากระบบเดิมเก็บเป็น ชาย กับ หญิง
--   ผมไปเทียบแบบตรงตัวกับชุดหลัง ค่าที่มาจากฟอร์มจึงไม่ตรงและตกไปที่ไม่ระบุ
--
--   แก้เป็นค้นคำแทนการเทียบตรงตัว และพิมพ์ค่าที่เก็บไว้จริงออกมาตามนั้น
--   รองรับทั้งสองชุดคำโดยไม่ต้องไปไล่แก้ข้อมูลเก่า
--   จะขึ้นว่าไม่ระบุเพศก็ต่อเมื่อช่องนั้นว่างจริง ๆ เท่านั้น
--
-- จุดที่ 2 ยานพาหนะขึ้นว่า อื่นๆ แทนที่จะเป็นสิ่งที่พิมพ์เพิ่ม
--   ตอนเลือก อื่นๆ ในฟอร์ม จะมีช่องให้พิมพ์ระบุเองอีกช่อง
--   หน้าเว็บมีตรรกะนี้อยู่แล้ว ถ้าเลือกอื่นๆ และพิมพ์ระบุไว้ ให้ใช้สิ่งที่พิมพ์แทน
--   แต่ผมไม่ได้ทำตามตอนเขียนฝั่งฐานข้อมูล จึงหยิบคำว่า อื่นๆ มาแสดงตรง ๆ
--
--   ยานพาหนะของผู้เสียชีวิตเองไม่มีปัญหา เพราะคำสั่งบันทึกแปลงให้ตั้งแต่ต้นทางแล้ว
--   ที่พลาดคือฝั่งคู่กรณี ซึ่งอ่านจากข้อมูลดิบของเคสโดยตรง
-- ============================================================

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

  select count(*) into v_n from deaths dd
   where dd.incident_datetime = d.incident_datetime
     and coalesce(btrim(dd.coordinates), '') = coalesce(btrim(d.coordinates), '');

  v_site := coalesce(
    (select (val #>> array[]::text[]) from bs_settings where key = 'publicSiteUrl'), '');

  v_lines := array[
    '🚨 ผู้เสียชีวิตจากอุบัติเหตุจราจร',
    '🚑 เสียชีวิต ' || greatest(v_n, 1) || ' ราย',
    '',
    '🗓️ ' || to_char(timezone('Asia/Bangkok', d.incident_datetime), 'DD/MM/') ||
      (extract(year from timezone('Asia/Bangkok', d.incident_datetime))::int + 543)::text ||
      ' เวลา ' || to_char(timezone('Asia/Bangkok', d.incident_datetime), 'HH24:MI') || ' น.'
  ];

  v_line := concat_ws(' · ',
              nullif(btrim(coalesce(a.place, '')), ''),
              nullif(btrim(coalesce(a.road_character, d.road_type, '')), ''));
  if v_line <> '' then
    v_lines := v_lines || array['📍 ' || v_line];
  end if;

  v_line := concat_ws(' · ',
              nullif(btrim(coalesce(d.road_name, a.road, '')), ''),
              case when coalesce(btrim(d.subdistrict), '') <> '' then 'ต.' || btrim(d.subdistrict)
                   when coalesce(btrim(coalesce(a.subdistrict, '')), '') <> '' then 'ต.' || btrim(a.subdistrict)
              end);
  if v_line <> '' then
    v_lines := v_lines || array['🛣️ ' || v_line];
  end if;

  -- เพศ ค้นคำแทนการเทียบตรงตัว รองรับทั้ง ผู้ชาย ผู้หญิง และ ชาย หญิง
  -- แล้วพิมพ์ค่าที่เก็บไว้จริงออกมา ไม่แปลงคำให้เอง
  v_lines := v_lines || array[concat_ws(' · ',
    case when coalesce(btrim(d.gender), '') = '' then 'ไม่ระบุเพศ'
         when d.gender like '%หญิง%' then '👩 ' || btrim(d.gender)
         when d.gender like '%ชาย%'  then '👨 ' || btrim(d.gender)
         else btrim(d.gender) end,
    case when coalesce(d.age, 0) > 0 then 'อายุ ' || d.age || ' ปี' else 'ไม่ระบุอายุ' end,
    nullif(btrim(coalesce(d.status, '')), ''))];

  -- ยานพาหนะ ถ้าเลือก อื่นๆ ให้ใช้ข้อความที่เจ้าหน้าที่พิมพ์ระบุไว้แทน
  -- ตรรกะเดียวกับ displayVehicleOf ที่หน้าเว็บใช้อยู่
  v_veh1 := nullif(btrim(coalesce(
              case when btrim(coalesce(a.party1->>'vehicle', '')) = 'อื่นๆ'
                        and coalesce(btrim(a.party1->>'vehicleOther'), '') <> ''
                   then a.party1->>'vehicleOther'
                   else a.party1->>'vehicle' end,
              d.vehicle_type, '')), '');

  v_veh2 := case when btrim(coalesce(a.party2->>'status', 'ไม่มี')) <> 'ไม่มี'
                 then nullif(btrim(coalesce(
                        case when btrim(coalesce(a.party2->>'vehicle', '')) = 'อื่นๆ'
                                  and coalesce(btrim(a.party2->>'vehicleOther'), '') <> ''
                             then a.party2->>'vehicleOther'
                             else a.party2->>'vehicle' end, '')), '')
            end;

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
-- ดูข้อความของรายล่าสุดที่เพิ่งบันทึก
--   select line_msg_death(id) from deaths order by id desc limit 1;
--
-- บรรทัดเพศต้องขึ้นตามที่กรอกจริง เช่น ผู้หญิง ไม่ใช่ ไม่ระบุเพศ
-- บรรทัดยานพาหนะต้องขึ้นสิ่งที่พิมพ์ระบุไว้ ไม่ใช่คำว่า อื่นๆ
--
-- ข้อความที่ส่งไปแล้วแก้ย้อนหลังไม่ได้ ระบบส่งครั้งเดียวต่อหนึ่งราย
-- เคสถัดไปจะใช้รูปแบบที่แก้แล้ว
-- ============================================================
