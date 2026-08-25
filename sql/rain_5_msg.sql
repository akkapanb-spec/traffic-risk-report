-- แก้ข้อความแจ้งเตือนฝน
-- รันหลัง rain_2_radar.sql
-- ถ้ามี $0 ต่อท้ายไฟล์ ให้ลบออกก่อนกด Run
--
-- ไฟล์นี้สร้าง rain_alert_collect ใหม่ทั้งตัว แต่เปลี่ยนเฉพาะข้อความ
-- ตรรกะการตัดสินใจ เกณฑ์ และการกันส่งซ้ำ เหมือนเดิมทุกบรรทัด
-- เขียนทั้งตัวแทนการแทนที่เฉพาะข้อความ เพราะข้อความมีหลายบรรทัด
-- การไปแทนที่ทีละบรรทัดในโค้ดที่ติดตั้งอยู่ พลาดง่ายกว่าเขียนใหม่ทั้งก้อน
--
-- อีโมจิที่เลือกใช้ เปลี่ยนได้โดยแก้ไฟล์นี้แล้วรันซ้ำ
--   💧  แทนน้ำฝนผสมคราบน้ำมัน
--   ⚠️  แทนถนนลื่น เพราะยูนิโคดไม่มีอีโมจิป้ายถนนลื่นโดยตรง
--   2️⃣  แทนเลขสอง
--   👮  แทนเจ้าหน้าที่จราจร ยังไม่ได้รับภาพที่จะใช้แทน จึงใช้ตัวนี้ไปก่อน

create or replace function rain_alert_collect()
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $fn$
declare
  v_req    bigint;
  v_body   text;
  v_status int;
  v_j      jsonb;
  v_pct    numeric;
  v_heavy  int;
  v_min    numeric := coalesce((select (val #>> array[]::text[])::numeric from bs_settings where key = 'rainMinPct'), 15);
  v_when   text;
  v_ref    text;
  v_sent   int;
  v_text   text;
begin
  if coalesce((select (val #>> array[]::text[])::boolean from bs_settings
                where key = 'rainAlertEnabled'), false) is not true then
    return jsonb_build_object('success', true, 'message', 'ปิดอยู่');
  end if;

  select p.req_id, x.content, x.status_code
    into v_req, v_body, v_status
  from rain_probe p join net._http_response x on x.id = p.req_id
  where p.done = false
  order by p.req_id desc
  limit 1;

  if v_req is null then
    return jsonb_build_object('success', true, 'message', 'ยังไม่มีคำตอบให้อ่าน');
  end if;

  update rain_probe set done = true where req_id = v_req;
  delete from rain_probe where fired_at < now() - interval '2 days';

  -- อ่านไม่ได้ต้องบอกว่าอ่านไม่ได้ ห้ามตีความว่าไม่มีฝน
  -- ถ้าตีความว่าไม่มีฝนทุกครั้งที่พัง ระบบจะเงียบสนิทในวันที่ควรเตือนที่สุด
  if v_status <> 200 or v_body is null then
    return jsonb_build_object('success', false, 'message', 'อ่านเรดาร์ไม่สำเร็จ', 'status', v_status);
  end if;

  begin
    v_j := v_body::jsonb;
  exception when others then
    return jsonb_build_object('success', false, 'message', 'คำตอบไม่ใช่ json');
  end;

  if coalesce((v_j->>'ok')::boolean, false) is not true then
    return jsonb_build_object('success', false, 'message', 'ตัวอ่านเรดาร์แจ้งข้อผิดพลาด',
                              'error', v_j->>'error');
  end if;

  v_pct   := coalesce((v_j->>'rainPercent')::numeric, 0);
  v_heavy := coalesce((v_j->>'heavyPixels')::int, 0);
  v_when  := coalesce(v_j->>'frameThai', '');

  if v_pct < v_min then
    return jsonb_build_object('success', true, 'rainPercent', v_pct,
                              'message', 'ฝนยังไม่ถึงเกณฑ์ ' || v_min || ' เปอร์เซ็นต์');
  end if;

  -- กุญแจกันส่งซ้ำผูกกับวัน จึงส่งได้วันละข้อความเดียว
  v_ref := 'day:' || to_char(now() at time zone 'Asia/Bangkok', 'YYYY-MM-DD');

  v_text := array_to_string(array[
    '🌧️ เตือนฝนกำลังเข้าเขตเมืองนครสวรรค์',
    'เรดาร์ตรวจพบกลุ่มฝนในรัศมี 8 กม. รอบแยกเดชาติวงศ์'
      || case when v_heavy > 0 then '  มีฝนหนักปนอยู่ด้วย' else '' end,
    '',
    'ช่วงอันตรายที่สุด',
    'คือไม่กี่นาทีแรกที่ฝนเริ่มตก',
    '',
    '💧 น้ำผสมกับคราบน้ำมันบนผิวถนน',
    'กลายเป็นฟิล์มทำให้ถนนลื่น',
    'ยางเกาะถนนได้น้อยลงมาก',
    '⚠️ ทั้งที่ถนนยังดูเหมือนแค่ชื้น',
    '',
    'โปรดใช้ความระมัดระวังและลดความเร็ว',
    'ควรเพิ่มระยะห่างจากรถคันหน้าเป็น 2️⃣ เท่า',
    '',
    '👮 ด้วยความปรารถนาดี น้องจราจรชอนตะวัน'
  ], chr(10));

  v_sent := line_broadcast('rain', v_text, v_ref);

  return jsonb_build_object(
    'success', true,
    'frame',   v_when,
    'rainPercent', v_pct,
    'heavyPixels', v_heavy,
    'sent',    v_sent,
    'message', case when v_sent > 0 then 'ส่งแล้ว ' || v_sent || ' กลุ่ม'
                    else 'วันนี้ส่งไปแล้ว จึงเงียบ' end
  );
end;
$fn$;

-- ==========================================================
-- ตรวจผล  คำสั่งสุดท้ายคำสั่งเดียวที่จะแสดงผล
-- ==========================================================
-- ประกอบข้อความตัวจริงออกมาให้อ่านก่อนของจริงจะออกไปหาประชาชน
-- ประกอบจากค่าคงที่ชุดเดียวกับที่ฟังก์ชันใช้ จึงเห็นหน้าตาตรงกับที่จะส่งจริง

select 'ข้อความที่จะส่งเข้ากลุ่ม' as รายการ,
       array_to_string(array[
         '🌧️ เตือนฝนกำลังเข้าเขตเมืองนครสวรรค์',
         'เรดาร์ตรวจพบกลุ่มฝนในรัศมี 8 กม. รอบแยกเดชาติวงศ์',
         '',
         'ช่วงอันตรายที่สุด',
         'คือไม่กี่นาทีแรกที่ฝนเริ่มตก',
         '',
         '💧 น้ำผสมกับคราบน้ำมันบนผิวถนน',
         'กลายเป็นฟิล์มทำให้ถนนลื่น',
         'ยางเกาะถนนได้น้อยลงมาก',
         '⚠️ ทั้งที่ถนนยังดูเหมือนแค่ชื้น',
         '',
         'โปรดใช้ความระมัดระวังและลดความเร็ว',
         'ควรเพิ่มระยะห่างจากรถคันหน้าเป็น 2️⃣ เท่า',
         '',
         '👮 ด้วยความปรารถนาดี น้องจราจรชอนตะวัน'
       ], chr(10)) as ข้อความ
union all
select 'บรรทัดที่สองจะต่อท้ายอัตโนมัติ',
       'ถ้าเรดาร์เจอฝนหนัก จะเติมคำว่า  มีฝนหนักปนอยู่ด้วย  ท้ายบรรทัดที่สอง'
union all
select 'สวิตช์', coalesce((select val #>> array[]::text[] from bs_settings where key = 'rainAlertEnabled'), '-')
union all
select 'ส่งได้', 'วันละหนึ่งข้อความเท่านั้น';
