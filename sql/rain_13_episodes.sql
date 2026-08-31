-- เปลี่ยนกติกาการส่งข้อความเตือนฝน จากวันละหนึ่งครั้ง เป็นตามรอบฝนและช่วงเร่งด่วน
-- ถ้ามีอักขระแปลกปลอมต่อท้ายบรรทัดสุดท้าย ให้ลบออกก่อนกด Run
--
-- ------------------------------------------------------------
-- เหตุที่ต้องแก้  หลักฐานจากวันที่ 31 ส.ค. 2569
-- ------------------------------------------------------------
-- กติกาเดิมผูกรหัสกันส่งซ้ำไว้กับวัน จึงส่งได้วันละข้อความเดียว
-- วันนั้นฝนขึ้นถึงเกณฑ์ตอนตีหนึ่งสี่สิบสาม ที่ 15.0 เปอร์เซ็นต์ ระบบส่งไปหนึ่งครั้ง
-- รหัสของวันถูกใช้หมดตั้งแต่ตอนนั้น แล้วเกิดสิ่งต่อไปนี้โดยไม่มีข้อความออกไปเลย
--
--   05:36   ฝน 33.8 เปอร์เซ็นต์
--   06:01   ฝน 20.6 เปอร์เซ็นต์
--   08:08   ฝน 40.1 เปอร์เซ็นต์
--   08:36   ฝน 84.3 เปอร์เซ็นต์   หนักที่สุดเท่าที่เคยวัดได้
--
-- ระบบเตือนฝนเบาตอนคนหลับ แล้วเงียบตอนฝนหนักที่สุดในเวลาคนออกจากบ้านวันจันทร์
-- ความผิดพลาดอยู่ที่กติกา ไม่ใช่ที่การทำงาน ทุกส่วนทำถูกตามที่เขียนไว้ทุกประการ
--
-- และวันที่ 28 ส.ค. ก็เป็นแบบเดียวกัน ส่งไปแล้วตอนแปดโมงสี่สิบสาม
-- พอถึงเย็นฝนขึ้นถึง 67.3 เปอร์เซ็นต์ในเวลาคนกลับบ้าน ระบบเงียบสนิท
--
-- ------------------------------------------------------------
-- กติกาใหม่ สามข้อ
-- ------------------------------------------------------------
-- 1  ช่วงเร่งด่วน จันทร์ถึงศุกร์ 06:45 ถึง 08:00 และ 15:20 ถึง 17:30
--    ได้สิทธิ์ข้อความของตัวเองหนึ่งครั้งต่อหนึ่งช่วง แยกจากโควตาปกติ
--    เพราะคนที่ขึ้นถนนตอนเจ็ดโมง ไม่ได้เห็นข้อความที่ส่งไปตอนตีห้า
--    เกณฑ์ยังเป็น 15 เปอร์เซ็นต์เท่าเดิม ไม่ได้ลดให้ต่ำลง
--
-- 2  นอกช่วงเร่งด่วน ส่งได้เมื่อเป็นรอบฝนใหม่เท่านั้น
--    รอบใหม่แปลว่าฝนต้องเคยลดลงต่ำกว่าเกณฑ์ก่อน แล้วค่อยกลับขึ้นมา
--    บวกกับต้องเว้นจากข้อความก่อนหน้าอย่างน้อย 45 นาที
--    สองข้อนี้กันไม่ให้ฝนก้อนเดียวยิงข้อความรัวตอนค่าแกว่งขึ้นลงคร่อมเกณฑ์
--
-- 3  ไม่เกินสามข้อความต่อวัน
--    มากกว่านี้คนจะเริ่มปิดการแจ้งเตือน แล้วจะไม่ได้ยินอีกเลยแม้ตอนที่เตือนถูก
--
-- ถ้าใช้กติกานี้กับข้อมูลจริงของวันที่ 31 ส.ค. จะได้ข้อความสามครั้ง
-- คือ 01:43 ที่ 15.0  แล้ว 05:36 ที่ 33.8  แล้ว 08:08 ที่ 40.1
-- ข้อความสุดท้ายออกก่อนฝนขึ้นถึงยอด 84.3 อยู่ยี่สิบแปดนาที
--
-- ------------------------------------------------------------
-- สิ่งที่ตั้งใจไม่ทำ
-- ------------------------------------------------------------
-- ไม่ลดเกณฑ์ในช่วงเร่งด่วน  ตัดสินใจไว้ว่าคง 15 เปอร์เซ็นต์
--   ผลคือเช้าวันที่ 31 ส.ค. ช่วง 06:45 ถึง 08:00 ฝนสูงสุด 9.9 เปอร์เซ็นต์
--   จึงยังไม่ถึงเกณฑ์และไม่มีข้อความในช่วงนั้น  ข้อ 2 เป็นตัวรับแทนตอน 08:08
--
-- ไม่รู้จักวันหยุดนักขัตฤกษ์  จันทร์ถึงศุกร์ถือเป็นวันทำงานทั้งหมด
--   วันหยุดที่ตรงกับวันธรรมดาจะยังใช้สิทธิ์ช่วงเร่งด่วน ซึ่งยอมรับได้
--   การทำตารางวันหยุดต้องมีคนคอยปรับทุกปี แล้ววันที่ลืมปรับจะพังเงียบ ๆ
--
-- ------------------------------------------------------------
-- เขียนใหม่ทั้งฟังก์ชัน ไม่ได้ค้นแล้วแทนที่
-- ------------------------------------------------------------
-- เนื้อในทั้งหมดคัดมาจากนิยามที่ติดตั้งอยู่จริง ดึงด้วย pg_get_functiondef
-- ส่วนที่ต่อเติมไว้ก่อนหน้าอยู่ครบทั้งสองส่วน คือการบันทึกลง rain_track
-- และการตรวจภาพเรดาร์ค้าง  ตรวจนับแล้วในคำสั่งท้ายไฟล์
--
-- ที่ไม่ใช้วิธีค้นแล้วแทนที่เพราะข้อความที่จะแทรกมีเครื่องหมายคำพูดจำนวนมาก
-- ต้องพิมพ์ซ้อนสองชั้น ซึ่งพลาดง่ายและพลาดแล้วเงียบ เคยเกิดมาแล้วกับ
-- deaths_infographic_default.sql ที่รันผ่านแต่ไม่ได้แก้อะไรเลย

create or replace function rain_alert_collect()
returns jsonb
language plpgsql
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
  v_rush   text;
  v_today  int;
  v_last   timestamptz;
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

  -- บันทึกร่องรอยทุกรอบ ไม่ว่าจะส่งข้อความหรือไม่
  -- เก็บไว้ให้ตรวจย้อนหลังได้ว่าที่ทำนายไว้ตรงกับที่เกิดจริงแค่ไหน
  insert into rain_track (pct8, nearest_km, outer_px, clat, clng,
                          east_kmh, north_kmh, near_east, near_north, spread_kmh)
  values (v_pct,
          nullif(v_j->>'nearestKm', '')::numeric,
          nullif(v_j->>'outerRainPixels', '')::int,
          nullif(v_j->>'centroidLat', '')::float8,
          nullif(v_j->>'centroidLng', '')::float8,
          nullif(v_j#>>array['motion','eastKmh'], '')::numeric,
          nullif(v_j#>>array['motion','northKmh'], '')::numeric,
          nullif(v_j->>'nearestEastKm', '')::numeric,
          nullif(v_j->>'nearestNorthKm', '')::numeric,
          nullif(v_j#>>array['motion','spreadKmh'], '')::numeric);

  delete from rain_track where seen_at < now() - interval '30 days';

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

  -- ============================================================
  -- ตัดสินว่าข้อความนี้ส่งได้หรือไม่ และนับเป็นครั้งไหน
  -- ============================================================
  -- นับด้วย distinct ref_id ไม่ใช่นับแถว เพราะหนึ่งข้อความสร้างหนึ่งแถวต่อปลายทาง
  -- ถ้าวันหนึ่งมีสองกลุ่ม การนับแถวจะทำให้โควตาหมดเร็วเป็นเท่าตัวโดยไม่มีใครรู้

  v_today := (select count(distinct ref_id) from line_sent
              where kind = 'rain'
                and sent_at >= date_trunc('day', now() at time zone 'Asia/Bangkok')
                              at time zone 'Asia/Bangkok');

  if v_today >= 3 then
    return jsonb_build_object('success', true, 'source', v_src, 'rainPercent', v_pct,
      'message', 'ครบสามข้อความแล้ววันนี้ จึงไม่ส่งเพิ่ม');
  end if;

  -- ช่วงเร่งด่วน จันทร์ถึงศุกร์  isodow 1 คือจันทร์ 5 คือศุกร์
  v_rush := case
    when extract(isodow from (now() at time zone 'Asia/Bangkok')) between 1 and 5
     and (now() at time zone 'Asia/Bangkok')::time >= time '06:45'
     and (now() at time zone 'Asia/Bangkok')::time <  time '08:00' then 'am'
    when extract(isodow from (now() at time zone 'Asia/Bangkok')) between 1 and 5
     and (now() at time zone 'Asia/Bangkok')::time >= time '15:20'
     and (now() at time zone 'Asia/Bangkok')::time <  time '17:30' then 'pm'
    else null
  end;

  if v_rush is not null then
    -- ช่วงเร่งด่วนได้สิทธิ์ของตัวเอง ไม่ต้องรอให้เป็นรอบฝนใหม่
    -- รหัสผูกกับช่วง ตัวกระจายข้อความจึงกันซ้ำให้เองอยู่แล้ว ช่วงละหนึ่งครั้ง
    v_ref := 'rush:' || to_char(now() at time zone 'Asia/Bangkok', 'YYYY-MM-DD') || ':' || v_rush;
  else
    select max(sent_at) into v_last from line_sent where kind = 'rain';

    if v_last is not null and v_last > now() - interval '45 minutes' then
      return jsonb_build_object('success', true, 'source', v_src, 'rainPercent', v_pct,
        'message', 'เพิ่งส่งไปยังไม่ถึง 45 นาที จึงยังไม่ส่งซ้ำ');
    end if;

    -- ต้องเคยเห็นฝนต่ำกว่าเกณฑ์หลังข้อความล่าสุด จึงจะถือว่าเป็นรอบใหม่
    if v_last is not null
       and not exists (select 1 from rain_track
                       where seen_at > v_last and pct8 < v_min) then
      return jsonb_build_object('success', true, 'source', v_src, 'rainPercent', v_pct,
        'message', 'ยังเป็นฝนรอบเดิม ยังไม่เคยลดต่ำกว่าเกณฑ์เลยตั้งแต่ข้อความที่แล้ว');
    end if;

    v_ref := 'ep:' || to_char(now() at time zone 'Asia/Bangkok', 'YYYY-MM-DD')
             || ':' || (v_today + 1);
  end if;

  v_text := array_to_string(array[
    '🌧️ เตือนฝนกำลังตกในเขตเมืองนครสวรรค์',
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
    'ref',     v_ref,
    'countToday', v_today,
    'sent',    v_sent,
    'message', case when v_sent > 0 then 'ส่งแล้ว ' || v_sent || ' กลุ่ม รหัส ' || v_ref
                    else 'รหัส ' || v_ref || ' ส่งไปแล้วก่อนหน้านี้ จึงเงียบ' end
  );
end;
$fn$;

-- ==========================================================
-- ตรวจผล  คำสั่งสุดท้ายคำสั่งเดียวที่จะแสดงผล
-- ==========================================================
-- สองบรรทัดกลางสำคัญที่สุด ถ้าขึ้นว่าหายไปแปลว่าเขียนทับของเดิมพัง
-- ให้บอกทันที อย่าปล่อยไว้ เพราะมันจะเงียบไปเป็นวันโดยไม่มีอาการ

select 'กติกาช่วงเร่งด่วน' as รายการ,
  coalesce((select case when prosrc like '%rush:%' then 'ติดตั้งแล้ว' else 'ยังไม่มี' end
            from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname='public' and p.proname='rain_alert_collect'), 'ไม่พบฟังก์ชัน') as ผล
union all
select 'ส่วนบันทึกลง rain_track ยังอยู่',
  coalesce((select case when prosrc like '%rain_track%' then 'อยู่ครบ' else 'หายไปแล้ว ต้องแก้' end
            from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname='public' and p.proname='rain_alert_collect'), 'ไม่พบฟังก์ชัน')
union all
select 'ส่วนตรวจภาพเรดาร์ค้าง ยังอยู่',
  coalesce((select case when prosrc like '%rainSameCount%' then 'อยู่ครบ' else 'หายไปแล้ว ต้องแก้' end
            from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname='public' and p.proname='rain_alert_collect'), 'ไม่พบฟังก์ชัน')
union all
select 'จำนวนรุ่นของฟังก์ชัน',
  (select count(*)::text from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname='public' and p.proname='rain_alert_collect') || '   ต้องเป็น 1'
union all
select 'แบ็กสแลชแปลกปลอม',
  coalesce((select 'พบ ต้องแก้' from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname='public' and p.proname='rain_alert_collect'
              and position(chr(92) in p.prosrc) > 0), 'สะอาด ไม่มีเลย')
union all
select 'ข้อความฝนที่ส่งไปแล้ววันนี้',
  coalesce((select string_agg(distinct ref_id, '  ') from line_sent
            where kind='rain'
              and sent_at >= date_trunc('day', now() at time zone 'Asia/Bangkok')
                            at time zone 'Asia/Bangkok'), 'ยังไม่ส่ง')
  || '   เพดานวันละ 3'
union all
select 'ตอนนี้อยู่ในช่วงไหน',
  case
    when extract(isodow from (now() at time zone 'Asia/Bangkok')) between 1 and 5
     and (now() at time zone 'Asia/Bangkok')::time >= time '06:45'
     and (now() at time zone 'Asia/Bangkok')::time <  time '08:00' then 'เร่งด่วนเช้า'
    when extract(isodow from (now() at time zone 'Asia/Bangkok')) between 1 and 5
     and (now() at time zone 'Asia/Bangkok')::time >= time '15:20'
     and (now() at time zone 'Asia/Bangkok')::time <  time '17:30' then 'เร่งด่วนเย็น'
    else 'ช่วงปกติ'
  end || '   เวลา ' || to_char(now() at time zone 'Asia/Bangkok', 'Dy HH24:MI');
