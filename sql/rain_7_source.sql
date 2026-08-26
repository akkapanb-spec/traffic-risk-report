-- จับภาพเรดาร์ค้าง และบันทึกว่าใช้ข้อมูลจากแหล่งไหน
-- ถ้ามีอักขระแปลกปลอมต่อท้ายบรรทัดสุดท้าย ให้ลบออกก่อนกด Run
-- รันหลัง deploy Edge Function ชื่อ rain ฉบับใหม่
--
-- ทำไมต้องมีไฟล์นี้
--   ตัวอ่านย้ายไปใช้เรดาร์ตาคลีของกรมฝนหลวงเป็นหลัก ละเอียดกว่าเดิมเกือบเท่าตัว
--   แต่ภาพของเขาชื่อ latest เฉย ๆ ไม่มีเวลากำกับ และเซิร์ฟเวอร์ไม่ส่งเวลาแก้ไขมาด้วย
--   ถ้าวันไหนระบบเขาค้าง เราจะดึงภาพเก่ามาอ่านโดยไม่รู้ตัว แล้วบอกว่าฟ้าใส
--   ทั้งที่ความจริงคือเราไม่รู้ ซึ่งเป็นความพังชนิดที่มองไม่เห็น
--
--   ตัวอ่านจึงส่งลายนิ้วมือของภาพมาด้วย ไฟล์นี้เก็บไว้เทียบกับรอบก่อน
--   เหมือนเดิมติดกันสี่รอบ คือหนึ่งชั่วโมง ถือว่าค้าง แล้วหยุดเตือน
--   เรดาร์ออกภาพใหม่ทุกไม่กี่นาที หนึ่งชั่วโมงที่ภาพไม่ขยับเลยไม่ใช่เรื่องปกติ
--
-- ข้อความแจ้งเตือนไม่ถูกแตะ ยังเป็นถ้อยคำเดิมทุกตัวอักษร

insert into bs_settings (key, val) values
  ('rainLastHash',  to_jsonb(''::text)),
  ('rainSameCount', to_jsonb(0))
on conflict (key) do nothing;

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
  v_src    text;
  v_hash   text;
  v_prev   text;
  v_same   int;
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
  v_src   := coalesce(v_j->>'source', 'ไม่ระบุ');
  v_hash  := v_j->>'imageHash';
  v_when  := coalesce(v_j->>'frameThai', '');

  -- ------------------------------------------------------------
  -- ตรวจภาพค้าง ทำเฉพาะกับตาคลี เพราะ RainViewer บอกเวลาของภาพมาเองอยู่แล้ว
  -- ------------------------------------------------------------
  if v_hash is not null then
    select coalesce(val #>> array[]::text[], '') into v_prev
      from bs_settings where key = 'rainLastHash';
    select coalesce((val #>> array[]::text[])::int, 0) into v_same
      from bs_settings where key = 'rainSameCount';

    if v_hash = coalesce(v_prev, '') then
      v_same := v_same + 1;
    else
      v_same := 0;
      update bs_settings set val = to_jsonb(v_hash) where key = 'rainLastHash';
    end if;
    update bs_settings set val = to_jsonb(v_same) where key = 'rainSameCount';

    if v_same >= 4 then
      return jsonb_build_object(
        'success', false,
        'source',  v_src,
        'message', 'ภาพเรดาร์ไม่เปลี่ยนมา ' || v_same || ' รอบติดกัน ถือว่าค้าง จึงไม่เตือน');
    end if;
  end if;

  if v_pct < v_min then
    return jsonb_build_object('success', true, 'source', v_src, 'rainPercent', v_pct,
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
    'source',  v_src,
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

select 'แหล่งข้อมูลหลัก' as รายการ, 'เรดาร์ตาคลี กรมฝนหลวงและการบินเกษตร' as ผล
union all
select 'แหล่งสำรอง', 'RainViewer ใช้อัตโนมัติเมื่อตาคลีอ่านไม่ได้'
union all
select 'จับภาพค้าง', 'ภาพไม่เปลี่ยนสี่รอบติดกัน คือหนึ่งชั่วโมง แล้วหยุดเตือน'
union all
select 'เกณฑ์ฝน', coalesce((select val #>> array[]::text[] from bs_settings where key = 'rainMinPct'), '-')
                  || ' เปอร์เซ็นต์ของวง 8 กม.'
union all
select 'สวิตช์', coalesce((select val #>> array[]::text[] from bs_settings where key = 'rainAlertEnabled'), '-')
union all
select 'ข้อความแจ้งเตือน', 'ไม่ถูกแก้ ยังเป็นถ้อยคำเดิมทุกตัวอักษร';
