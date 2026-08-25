-- แก้บั๊กการต่ออาเรย์ในข้อความสถานะ
-- รันหลัง camp_8_period.sql
-- ถ้ามี $0 ต่อท้ายไฟล์ ให้ลบออกก่อนกด Run
--
-- อาการ
--   malformed array literal ตอนเรียก camp_msg_status
--
-- สาเหตุ
--   เขียนไว้ว่า  v_lines := v_lines || '' || ('ข้อความ')
--   Postgres อ่านจากซ้ายไปขวา จึงเจอ  text[] || ''  ก่อน
--   และ '' เป็นค่าที่ยังไม่ระบุชนิด ตัวเลือกที่มันหยิบคือ anyarray || anyarray
--   มันจึงพยายามแปลง '' เป็นอาเรย์แล้วพัง
--
-- ทำไมเพิ่งเจอตอนนี้
--   บรรทัดที่พังบรรทัดแรกอยู่ในเงื่อนไข ครบ 5 คนแล้ว ซึ่งตอนทดสอบไม่มีใครถึง
--   ถ้าไม่เจอวันนี้ คนแรกที่ชวนครบจริงจะได้ error แทนคำแสดงความยินดี
--
-- วิธีแก้
--   ต่อด้วย array[...] ทั้งก้อน  text[] || text[] ไม่กำกวม ไม่ต้องเดาชนิด

create or replace function camp_msg_status(p_user_id text)
returns text
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_code   text;
  v_need   int  := camp_cfg('campNeedFriends', '5')::int;
  v_have   int;
  v_share  text := camp_cfg('campShareBase', 'https://line.me/R/oaMessage/%40690vodvg/?');
  v_group  text := camp_cfg('campGroupUrl', '');
  v_prize  text := camp_cfg('campPrizeName', 'ของรางวัล');
  v_end    date := nullif(camp_cfg('campEndDate', ''), '')::date;
  v_left   int;
  v_lines  text[];
begin
  select ref_code into v_code from camp_members where line_user_id = p_user_id;
  if v_code is null then return null; end if;

  v_have := camp_friend_count(p_user_id);

  v_lines := array[
    '🎁 กิจกรรมแจก' || v_prize,
    '',
    'รหัสของคุณ  ' || v_code,
    '',
    'ส่งลิงก์นี้ให้เพื่อน เพื่อนกดแล้วกดส่งข้อความได้เลย ไม่ต้องพิมพ์อะไร',
    v_share || v_code,
    '',
    'จากนั้นให้เพื่อนเข้ากลุ่มนี้ด้วย',
    v_group,
    '',
    'ต้องครบทั้งสองอย่าง เพิ่มเพื่อนและเข้ากลุ่ม จึงจะนับให้',
    'ตอนนี้นับได้ ' || v_have || ' จาก ' || v_need || ' คน'
  ];

  if v_end is not null then
    v_left := (v_end - camp_today());
    v_lines := v_lines || array[
      '',
      '⏳ กิจกรรมถึง ' || camp_thai_date(v_end) ||
      case when v_left > 0 then '  เหลืออีก ' || v_left || ' วัน'
           when v_left = 0 then '  วันนี้วันสุดท้าย'
           else '  หมดเขตแล้ว' end
    ];
  end if;

  if v_have >= v_need then
    v_lines := v_lines || array[
      '',
      '🎉 ครบแล้ว ติดต่อรับ' || v_prize || ' ได้ที่ สภ.เมืองนครสวรรค์',
      'นำข้อความนี้พร้อมรหัส ' || v_code || ' มาแสดงต่อเจ้าหน้าที่'
    ];
  end if;

  return array_to_string(v_lines, chr(10));
end;
$fn$;

-- ==========================================================
-- ตรวจผล  คำสั่งสุดท้ายคำสั่งเดียวที่จะแสดงผล
-- ==========================================================
-- เรียกของจริงกับผู้เข้าร่วมทุกคนที่มีอยู่ ถ้าพังจะพังตรงนี้ให้เห็นทันที
-- ไม่ใช่ไปพังใส่ประชาชนคนแรกที่ทำสำเร็จ

select coalesce(m.display_name, m.ref_code) as ผู้เข้าร่วม,
       camp_msg_status(m.line_user_id)      as ข้อความที่จะได้รับ
from camp_members m
order by m.created_at;
