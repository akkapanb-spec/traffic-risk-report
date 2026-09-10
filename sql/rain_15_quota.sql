-- แยกโควตาข้อความเตือนฝน  วันละ 1 ครั้งนอกช่วงเร่งด่วน  บวกช่วงเร่งด่วนอีกช่วงละ 1
-- ถ้ามีอักขระแปลกปลอมต่อท้ายบรรทัดสุดท้าย ให้ลบออกก่อนกด Run
-- ใช้แทน rain_14_gates.sql  สามประตูและด่านอื่นยังอยู่ครบทุกอย่าง
--
-- ============================================================
-- เหตุที่ต้องแก้  หลักฐานจากคืนวันที่ 9 ก.ย. 2569
-- ============================================================
--   20:43   ep:2026-09-09:1
--   21:29   ep:2026-09-09:2
--
-- สองข้อความห่างกัน 46 นาที ผ่านด่าน 45 นาทีมาแบบเฉียดฉิว
-- และผ่านด่านรอบฝนใหม่ได้ด้วย เพราะฝนตกลงต่ำกว่าเกณฑ์คั่นกลางจริง ๆ
-- ทุกด่านทำงานถูกตามที่เขียนไว้ แต่ผลรวมคือรบกวนคนสองครั้งในชั่วโมงเดียว
--
-- ความผิดอยู่ที่การนับ  เพดานเดิมคือสามข้อความต่อวันแบบกองรวมกัน
-- ใครมาก่อนได้ก่อน ฝนกลางดึกจึงกินโควตาที่ควรเป็นของชั่วโมงเร่งด่วนได้
--
-- ------------------------------------------------------------
-- โควตาใหม่  แบ่งตามวัตถุประสงค์ ไม่ใช่กองรวม
-- ------------------------------------------------------------
--   นอกช่วงเร่งด่วน       วันละ 1 ครั้ง
--   เร่งด่วนเช้า 06:45 ถึง 08:00   วันละ 1 ครั้ง
--   เร่งด่วนเย็น 15:20 ถึง 18:00   วันละ 1 ครั้ง
--
-- รวมยังไม่เกินสามเหมือนเดิม แต่สองช่องหลังถูกกันไว้ให้ชั่วโมงที่คนอยู่บนถนนหนาแน่น
-- ใครมาก่อนไม่ได้สิทธิ์ไปทั้งหมดอีกแล้ว
--
-- ถ้าใช้กติกานี้ ข้อความ 21:29 ของคืนวันที่ 9 ก.ย. จะไม่ออกไป
--
-- ------------------------------------------------------------
-- ผลข้างเคียงที่ต้องรู้ และผมไม่ปิดบัง
-- ------------------------------------------------------------
-- ช่องนอกช่วงเร่งด่วนมีช่องเดียว ใครมาก่อนได้ก่อนภายในกลุ่มนั้น
-- ฝนเล็กตอนตีสองจึงยังกินช่องของฝนใหญ่ตอนสิบเอ็ดโมงได้อยู่
-- ซึ่งเป็นอาการเดียวกับที่เจอเมื่อ 31 ส.ค. เพียงแต่ขอบเขตแคบลงมาก
-- เพราะสองชั่วโมงที่คนอยู่บนถนนหนาแน่นที่สุดมีช่องของตัวเองแล้ว
--
-- แลกกันตรงนี้โดยตั้งใจ  เตือนน้อยแต่ตรงเวลา ดีกว่าเตือนบ่อยจนคนปิดการแจ้งเตือน
-- เพราะคนที่ปิดไปแล้วจะไม่ได้ยินอีกเลย แม้ในวันที่เราเตือนถูก
--
-- ------------------------------------------------------------
-- เขียนใหม่ทั้งฟังก์ชัน คัดจากไฟล์เดิมด้วยเครื่อง ไม่ได้พิมพ์ใหม่
-- ------------------------------------------------------------
-- เนื้อในทั้งหมดมาจาก rain_14_gates.sql ที่ติดตั้งอยู่จริง
-- แก้เฉพาะส่วนนับโควตา ที่เหลือไม่แตะแม้แต่ตัวอักษรเดียว

-- ============================================================
-- เหตุที่ต้องเพิ่ม  หลักฐานจาก 2 ก.ย. 2569 บ่าย
-- ============================================================
-- ก้อนฝนเดี่ยวก่อตัวคาเมือง ฝนเกือบทั้งหมดในรัศมี 30 กม. อยู่ในวง 8 กม. ของเรา
--
--   13:08   วง 8 กม. 13.2 เปอร์เซ็นต์   แรงสุด 40 dBZ   ฝนหนัก 1.4 ตร.กม.
--   13:22   วง 8 กม. 14.6 เปอร์เซ็นต์   แรงสุด 48 dBZ   ฝนหนัก 7.2 ตร.กม.
--   13:29   วง 8 กม. 15.9 เปอร์เซ็นต์   ระบบส่งข้อความ
--
-- 48 dBZ คือค่าแรงที่สุดที่ระบบเคยอ่านได้ แรงกว่าวันที่ฝนคลุมเมือง 84 เปอร์เซ็นต์
-- เมื่อ 31 ส.ค. ซึ่งวันนั้นแรงสุดแค่ 32 dBZ
--
-- ข้อความออกไปตอน 13:29 ก็จริง แต่ออกเพราะฝนบังเอิญขยายพอดี
-- ถ้ามันหยุดอยู่ที่ 14.6 ระบบจะเงียบทั้งที่ฝนหนักตกคาเทศบาลอยู่ยี่สิบนาที
-- เราไม่ควรฝากความปลอดภัยของคนไว้กับความบังเอิญแบบนั้น
--
-- ------------------------------------------------------------
-- ทำไมเกณฑ์เดียวไม่พอ  วัดคนละอย่างกัน
-- ------------------------------------------------------------
-- วง 8 กม. มีพื้นที่ 199 ตร.กม. เกณฑ์ 15 เปอร์เซ็นต์จึงเท่ากับ 30 ตร.กม.
-- ซึ่งใหญ่มาก ฝนต้องคลุมเกือบทั้งเมืองกว่าจะถึง
--
-- แต่คนส่วนใหญ่อยู่ในเขตเทศบาล ซึ่งเป็นวงเล็กกลางวงใหญ่
-- วัดเมื่อ 13:35 น. ของวันเดียวกัน ภาพเรดาร์ใบเดียวกัน
--
--   วง 8 กม.  อ่านได้ 15.9 เปอร์เซ็นต์
--   วง 3 กม.  อ่านได้ 25.9 เปอร์เซ็นต์
--
-- ฝนก้อนเดียวกัน ต่างกันสิบจุด เพราะก้อนมันคาอยู่กลางเมืองพอดี
-- วงเล็กจึงตอบตรงคำถามที่เราอยากรู้จริง ๆ ว่าฝนตกใส่คนอยู่หรือเปล่า
--
-- และเปอร์เซ็นต์ไม่ว่าวงไหนก็ไม่ได้วัดความแรง ประตูที่สองจึงจำเป็นแยกต่างหาก
--
-- ============================================================
-- กติกาใหม่  สามประตู เข้าได้ทางใดทางหนึ่งก็ส่ง
-- ============================================================
--   ประตู 1  ฝนคลุมวง 8 กม. ตั้งแต่ 15 เปอร์เซ็นต์      ของเดิม ไม่แตะ
--   ประตู 2  มีจุดฝนหนักตั้งแต่ 3 จุด คือแรงกว่า 36 dBZ   ของใหม่
--   ประตู 3  ฝนคลุมวง 3 กม. ตั้งแต่ 15 เปอร์เซ็นต์      ของใหม่
--
-- ด่านกันส่งซ้ำทั้งสามข้อที่ตกลงกันไว้ยังบังคับใช้กับทุกประตูเท่ากัน
--   ช่วงเร่งด่วนจันทร์ถึงศุกร์ได้สิทธิ์ของตัวเอง
--   นอกช่วงเร่งด่วนต้องเป็นรอบฝนใหม่ และเว้นอย่างน้อย 45 นาที
--   ไม่เกินสามข้อความต่อวัน
-- ประตูใหม่แค่เปิดทางให้เข้ามาได้ ไม่ได้ยกเว้นด่านไหนเลย
--
-- ถ้าใช้กติกานี้ วันนี้ระบบจะส่งตั้งแต่ 13:08 เร็วกว่าที่เป็นจริง 21 นาที
--
-- ------------------------------------------------------------
-- ตัวเลขสองตัวนี้ผมเดา และบอกไว้ตรงนี้ว่าเดา
-- ------------------------------------------------------------
-- ฝนหนัก 3 จุด เท่ากับ 1.1 ตร.กม.  และวงเล็ก 15 เปอร์เซ็นต์ เท่ากับ 4.4 ตร.กม.
-- ทดสอบย้อนหลังไม่ได้ เพราะไม่เคยเก็บทั้งความแรงและวงเล็กลงตารางเลย
-- ไฟล์นี้เริ่มเก็บทั้งสามค่า คือ heavyPixels maxDbz และเปอร์เซ็นต์วงเล็ก
-- อีกสองสามสัปดาห์จะมีของจริงให้ปรับตัวเลขแทนการเดา
--
-- ทุกค่าอยู่ใน bs_settings เปลี่ยนได้ด้วย update บรรทัดเดียว
--   update bs_settings set val = to_jsonb(5)  where key = 'rainHeavyMinPx';
--   update bs_settings set val = to_jsonb(20) where key = 'rainYolkMinPct';
--
-- ------------------------------------------------------------
-- ไม่ต้อง deploy Edge Function
-- ------------------------------------------------------------
-- ตัวอ่านเรดาร์รับพารามิเตอร์ km อยู่แล้วตั้งแต่แรก ขอวงไหนก็ได้
-- จึงยิงคำถามสองครั้งต่อรอบ วง 8 กม. กับวง 3 กม. แล้วอ่านทั้งคู่
-- ไม่ต้องแตะโค้ดฝั่ง Edge Function ซึ่งเป็นขั้นที่พังง่ายที่สุดในระบบนี้

-- ==========================================================
-- 1  แยกให้ออกว่าคำถามไหนถามวงไหน
-- ==========================================================
-- เดิมมีคำถามเดียวต่อรอบ จึงไม่ต้องแยก พอมีสองคำถามแล้วต้องมีป้ายกำกับ
-- ถ้าไม่มีป้าย ตัวอ่านผลจะหยิบคำตอบของวงเล็กมาใช้เป็นวงใหญ่แบบสุ่ม
-- แล้วตัวเลขจะเพี้ยนเป็นบางรอบโดยไม่มีรูปแบบให้จับได้

alter table rain_probe add column if not exists km int not null default 8;

alter table rain_track add column if not exists heavy_px int;
alter table rain_track add column if not exists max_dbz  numeric;
alter table rain_track add column if not exists yolk_pct numeric;

-- ==========================================================
-- 2  ค่าตั้ง
-- ==========================================================

insert into bs_settings (key, val) values
  ('rainHeavyMinPx', to_jsonb(3)),
  ('rainYolkMinPct', to_jsonb(15)),
  ('rainFreeMaxPerDay', to_jsonb(1)),
  ('rainYolkUrl',    to_jsonb('https://ftpruljwwsmvipfcedyk.supabase.co/functions/v1/rain?km=3'::text))
on conflict (key) do nothing;

-- ต้องเขียน ::text ต่อท้ายข้อความ  ห้ามตัดออก
-- to_jsonb รับได้ทุกชนิด Postgres จึงต้องรู้ก่อนว่าที่ส่งมาเป็นชนิดอะไร
-- ข้อความเปล่า ๆ ในคำสั่งยังไม่มีชนิด มันจึงตอบว่า could not determine polymorphic type
-- ตัวเลขไม่มีปัญหาเพราะรู้อยู่แล้วว่าเป็นจำนวนเต็ม

-- ==========================================================
-- 3  ตัวยิงคำถาม  ยิงสองวง
-- ==========================================================
-- ยิงวงใหญ่ก่อนเสมอ และคืนค่าของวงใหญ่ เพื่อให้ผู้เรียกเดิมได้ผลเหมือนเดิม
-- วงเล็กยิงแบบไม่บังคับ ถ้าล้มเหลวไม่ทำให้วงใหญ่พังไปด้วย
-- เพราะวงใหญ่คือเกณฑ์หลักที่ใช้มาตลอด ห้ามพังเพราะของใหม่

create or replace function rain_alert_fire()
returns bigint
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_req  bigint;
  v_yreq bigint;
begin
  if coalesce((select (val #>> array[]::text[])::boolean from bs_settings
                where key = 'rainAlertEnabled'), false) is not true then
    return null;
  end if;

  /* ต้องยืดเวลารอเป็น 20 วินาที ค่าปริยายของ pg_net คือ 5 วินาที
     วัดจริงแล้วตัวอ่านเรดาร์ใช้เวลา 5.2 วินาที เพราะต้องโหลดภาพและถอดรหัส
     ถ้าใช้ค่าปริยาย คำขอจะหมดเวลาพอดี แล้วระบบจะเงียบโดยไม่มีอะไรฟ้อง
     ซึ่งเป็นความพังชนิดที่หายากที่สุด เพราะทุกอย่างดูเหมือนทำงานปกติ */
  select net.http_get(
           url := coalesce((select val #>> array[]::text[] from bs_settings where key = 'rainRadarUrl'), ''),
           timeout_milliseconds := 20000
         ) into v_req;

  insert into rain_probe (req_id, km) values (v_req, 8) on conflict (req_id) do nothing;

  -- วงเล็ก เขตเทศบาล  ล้มเหลวได้โดยไม่กระทบวงใหญ่
  begin
    select net.http_get(
             url := coalesce((select val #>> array[]::text[] from bs_settings where key = 'rainYolkUrl'), ''),
             timeout_milliseconds := 20000
           ) into v_yreq;
    insert into rain_probe (req_id, km) values (v_yreq, 3) on conflict (req_id) do nothing;
  exception when others then
    raise notice 'ยิงคำถามวงเล็กไม่สำเร็จ ข้ามไป';
  end;

  return v_req;
end;
$fn$;

-- ==========================================================
-- 4  ตัวอ่านผลและตัวตัดสินใจส่ง
-- ==========================================================

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
  v_dbz    numeric;
  v_yolk   numeric;
  v_yreq   bigint;
  v_ybody  text;
  v_ystat  int;
  v_min    numeric := coalesce((select (val #>> array[]::text[])::numeric from bs_settings where key = 'rainMinPct'), 15);
  v_hmin   int     := coalesce((select (val #>> array[]::text[])::int     from bs_settings where key = 'rainHeavyMinPx'), 3);
  v_ymin   numeric := coalesce((select (val #>> array[]::text[])::numeric from bs_settings where key = 'rainYolkMinPct'), 15);
  v_fdef   int     := coalesce((select (val #>> array[]::text[])::int     from bs_settings where key = 'rainFreeMaxPerDay'), 1);
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
  v_free   int;
  v_fmax   int;
  v_last   timestamptz;
  v_why    text;
begin
  if coalesce((select (val #>> array[]::text[])::boolean from bs_settings
                where key = 'rainAlertEnabled'), false) is not true then
    return jsonb_build_object('success', true, 'message', 'ปิดอยู่');
  end if;

  select p.req_id, x.content, x.status_code
    into v_req, v_body, v_status
  from rain_probe p join net._http_response x on x.id = p.req_id
  where p.done = false and p.km = 8
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
  v_dbz   := nullif(v_j->>'maxDbz', '')::numeric;

  -- ------------------------------------------------------------
  -- อ่านวงเล็ก  อ่านไม่ได้ก็ไม่เป็นไร ปล่อยเป็นค่าว่างแล้วไปต่อ
  -- ------------------------------------------------------------
  -- ห่อด้วยตัวดักความผิดพลาดทั้งก้อน เพราะของใหม่ต้องไม่ทำให้ของเดิมพัง
  -- ถ้าวงเล็กพัง ระบบจะทำงานเหมือนก่อนมีไฟล์นี้ทุกประการ ไม่ใช่หยุดทำงาน
  begin
    select p.req_id, x.content, x.status_code
      into v_yreq, v_ybody, v_ystat
    from rain_probe p join net._http_response x on x.id = p.req_id
    where p.done = false and p.km = 3
    order by p.req_id desc
    limit 1;

    if v_yreq is not null then
      update rain_probe set done = true where km = 3 and req_id <= v_yreq;
      if v_ystat = 200 and v_ybody is not null then
        v_yolk := nullif(v_ybody::jsonb ->> 'rainPercent', '')::numeric;
      end if;
    end if;
  exception when others then
    v_yolk := null;
  end;

  -- บันทึกร่องรอยทุกรอบ ไม่ว่าจะส่งข้อความหรือไม่
  -- เก็บความแรงและวงเล็กด้วย เพราะเกณฑ์จะปรับได้ก็ต่อเมื่อมีของจริงให้ดูย้อนหลัง
  insert into rain_track (pct8, nearest_km, outer_px, clat, clng,
                          east_kmh, north_kmh, near_east, near_north, spread_kmh,
                          heavy_px, max_dbz, yolk_pct)
  values (v_pct,
          nullif(v_j->>'nearestKm', '')::numeric,
          nullif(v_j->>'outerRainPixels', '')::int,
          nullif(v_j->>'centroidLat', '')::float8,
          nullif(v_j->>'centroidLng', '')::float8,
          nullif(v_j#>>array['motion','eastKmh'], '')::numeric,
          nullif(v_j#>>array['motion','northKmh'], '')::numeric,
          nullif(v_j->>'nearestEastKm', '')::numeric,
          nullif(v_j->>'nearestNorthKm', '')::numeric,
          nullif(v_j#>>array['motion','spreadKmh'], '')::numeric,
          v_heavy, v_dbz, v_yolk);

  delete from rain_track where seen_at < now() - interval '30 days';

  v_src   := coalesce(v_j->>'source', 'ไม่ระบุ');
  v_hash  := v_j->>'imageHash';
  v_when  := coalesce(v_j->>'frameThai', '');

  -- ------------------------------------------------------------
  -- ตรวจภาพค้าง ใช้ลายนิ้วมือของวงใหญ่เท่านั้น
  -- ------------------------------------------------------------
  -- วงเล็กอ่านภาพใบเดียวกัน ถ้าเอามานับด้วยจะกลายเป็นนับซ้ำสองเท่า
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

  -- ============================================================
  -- สามประตู  เข้าได้ทางใดทางหนึ่งก็พอ
  -- ============================================================
  -- เก็บเหตุผลไว้ใน v_why เพื่อให้ตรวจย้อนหลังได้ว่าข้อความไหนเข้ามาทางไหน
  -- ถ้าไม่เก็บ จะแยกไม่ออกว่าประตูใหม่ยิงบ่อยแค่ไหน แล้วปรับเกณฑ์ไม่ถูก

  if v_pct >= v_min then
    v_why := 'คลุมวง 8 กม. ' || v_pct || ' เปอร์เซ็นต์';
  elsif v_yolk is not null and v_yolk >= v_ymin then
    v_why := 'คลุมเขตเทศบาลวง 3 กม. ' || v_yolk || ' เปอร์เซ็นต์';
  elsif v_heavy >= v_hmin then
    v_why := 'ฝนหนัก ' || v_heavy || ' จุด แรงสุด ' || coalesce(v_dbz::text, '-') || ' dBZ';
  else
    return jsonb_build_object('success', true, 'source', v_src,
      'rainPercent', v_pct, 'yolkPercent', v_yolk, 'heavyPixels', v_heavy, 'maxDbz', v_dbz,
      'message', 'ยังไม่ถึงเกณฑ์ทั้งสามทาง  วง 8 กม. ' || v_pct || ' จาก ' || v_min
                 || '  วง 3 กม. ' || coalesce(v_yolk::text, '-') || ' จาก ' || v_ymin
                 || '  ฝนหนัก ' || v_heavy || ' จาก ' || v_hmin || ' จุด');
  end if;

  -- ============================================================
  -- ด่านกันส่งซ้ำ  ใช้กับทุกประตูเหมือนกัน ไม่ได้ยกเว้นให้ประตูใหม่
  -- ============================================================
  -- นับด้วย distinct ref_id ไม่ใช่นับแถว เพราะหนึ่งข้อความสร้างหนึ่งแถวต่อปลายทาง

  -- ต้องรู้ก่อนว่าตอนนี้อยู่ช่วงไหน จึงจะรู้ว่าใช้โควตาช่องไหน
  -- ลำดับนี้สลับจากของเดิมโดยตั้งใจ ของเดิมนับเพดานรวมก่อนแล้วค่อยดูช่วง
  -- ซึ่งทำให้ฝนนอกเวลากินโควตาที่ควรเป็นของชั่วโมงเร่งด่วนได้
  -- ช่วงเร่งด่วน จันทร์ถึงศุกร์  isodow 1 คือจันทร์ 5 คือศุกร์
  v_rush := case
    when extract(isodow from (now() at time zone 'Asia/Bangkok')) between 1 and 5
     and (now() at time zone 'Asia/Bangkok')::time >= time '06:45'
     and (now() at time zone 'Asia/Bangkok')::time <  time '08:00' then 'am'
    when extract(isodow from (now() at time zone 'Asia/Bangkok')) between 1 and 5
     and (now() at time zone 'Asia/Bangkok')::time >= time '15:20'
     and (now() at time zone 'Asia/Bangkok')::time <  time '18:00' then 'pm'
    else null
  end;

  v_fmax := greatest(v_fdef, 0);

  -- นับสองอย่างแยกกัน  ทั้งหมดของวัน และเฉพาะที่ส่งนอกช่วงเร่งด่วน
  -- นับด้วย distinct ref_id ไม่ใช่นับแถว เพราะหนึ่งข้อความสร้างหนึ่งแถวต่อปลายทาง
  -- ถ้าวันหนึ่งมีสองกลุ่ม การนับแถวจะทำให้โควตาหมดเร็วเป็นเท่าตัวโดยไม่มีใครรู้
  v_today := (select count(distinct ref_id) from line_sent
              where kind = 'rain'
                and sent_at >= date_trunc('day', now() at time zone 'Asia/Bangkok')
                              at time zone 'Asia/Bangkok');

  v_free := (select count(distinct ref_id) from line_sent
             where kind = 'rain'
               and ref_id like 'ep:%'
               and sent_at >= date_trunc('day', now() at time zone 'Asia/Bangkok')
                             at time zone 'Asia/Bangkok');

  -- เพดานรวมกันไว้เป็นตาข่ายชั้นสุดท้าย ปกติจะไม่ถึงเพราะแต่ละช่องคุมตัวเองอยู่แล้ว
  if v_today >= 3 then
    return jsonb_build_object('success', true, 'source', v_src, 'rainPercent', v_pct,
      'yolkPercent', v_yolk, 'heavyPixels', v_heavy,
      'message', 'ครบสามข้อความแล้ววันนี้ จึงไม่ส่งเพิ่ม');
  end if;

  if v_rush is not null then
    -- ช่วงเร่งด่วนมีช่องของตัวเอง รหัสผูกกับช่วง ตัวกระจายข้อความกันซ้ำให้เองช่วงละครั้ง
    -- ไม่ไปแตะโควตานอกช่วงเร่งด่วน และโควตานั้นก็มาแย่งช่องนี้ไม่ได้เช่นกัน
    v_ref := 'rush:' || to_char(now() at time zone 'Asia/Bangkok', 'YYYY-MM-DD') || ':' || v_rush;
  else
    -- นอกช่วงเร่งด่วนมีวันละหนึ่งช่อง ใช้แล้วคือหมด
    -- ด่านนี้เองที่จะกันข้อความ 21:29 ของคืนวันที่ 9 ก.ย. ไว้
    if v_free >= v_fmax then
      return jsonb_build_object('success', true, 'source', v_src, 'rainPercent', v_pct,
        'yolkPercent', v_yolk, 'heavyPixels', v_heavy,
        'message', 'ใช้โควตานอกช่วงเร่งด่วนไปแล้ววันนี้ ' || v_free || ' จาก ' || v_fmax
                   || ' ครั้ง  ที่เหลือกันไว้ให้ชั่วโมงเร่งด่วน');
    end if;

    select max(sent_at) into v_last from line_sent where kind = 'rain';

    if v_last is not null and v_last > now() - interval '45 minutes' then
      return jsonb_build_object('success', true, 'source', v_src, 'rainPercent', v_pct,
        'yolkPercent', v_yolk, 'heavyPixels', v_heavy,
        'message', 'เพิ่งส่งไปยังไม่ถึง 45 นาที จึงยังไม่ส่งซ้ำ');
    end if;

    -- รอบใหม่แปลว่าเคยเงียบทั้งสามทาง ไม่ใช่แค่ทางใดทางหนึ่ง
    -- ถ้าดูแต่วงใหญ่ ฝนก้อนเดิมที่หนักตลอดจะถูกนับเป็นรอบใหม่ทุกครั้งที่พื้นที่แกว่ง
    if v_last is not null
       and not exists (select 1 from rain_track
                       where seen_at > v_last
                         and pct8 < v_min
                         and coalesce(yolk_pct, 0) < v_ymin
                         and coalesce(heavy_px, 0) < v_hmin) then
      return jsonb_build_object('success', true, 'source', v_src, 'rainPercent', v_pct,
        'yolkPercent', v_yolk, 'heavyPixels', v_heavy,
        'message', 'ยังเป็นฝนรอบเดิม ยังไม่เคยเงียบเลยตั้งแต่ข้อความที่แล้ว');
    end if;

    v_ref := 'ep:' || to_char(now() at time zone 'Asia/Bangkok', 'YYYY-MM-DD')
             || ':' || (v_free + 1);
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
    'yolkPercent', v_yolk,
    'heavyPixels', v_heavy,
    'maxDbz',  v_dbz,
    'gate',    v_why,
    'ref',     v_ref,
    'countToday', v_today,
    'countFree', v_free,
    'sent',    v_sent,
    'message', case when v_sent > 0 then 'ส่งแล้ว ' || v_sent || ' กลุ่ม เพราะ ' || v_why
                    else 'รหัส ' || v_ref || ' ส่งไปแล้วก่อนหน้านี้ จึงเงียบ' end
  );
end;
$fn$;

-- ==========================================================
-- ตรวจผล  คำสั่งสุดท้ายคำสั่งเดียวที่จะแสดงผล
-- ==========================================================
-- บรรทัดที่เขียนว่า ของเดิม สำคัญที่สุด ถ้าขึ้นว่าหายไปแปลว่าเขียนทับพัง
-- ให้บอกทันที อย่าปล่อยไว้ เพราะจะเงียบไปเป็นวันโดยไม่มีอาการ

select 'โควตานอกช่วงเร่งด่วน' as รายการ,
  coalesce((select case when prosrc like '%v_free >= v_fmax%' then 'แยกแล้ว วันละ 1 ครั้ง' else 'ยังไม่แยก' end
            from pg_proc p join pg_namespace n on n.oid=p.pronamespace
            where n.nspname='public' and p.proname='rain_alert_collect'),'ไม่พบ') as ผล
union all
select 'ดูช่วงเวลาก่อนนับโควตา',
  coalesce((select case when position('v_rush := case' in prosrc) < position('v_today :=' in prosrc)
                        then 'ลำดับถูกแล้ว' else 'ลำดับยังผิด ต้องแก้' end
            from pg_proc p join pg_namespace n on n.oid=p.pronamespace
            where n.nspname='public' and p.proname='rain_alert_collect'),'ไม่พบ')
union all
select 'ของเดิม ประตู 1 วง 8 กม.',
  coalesce((select case when prosrc like '%v_pct >= v_min%' then 'อยู่ครบ' else 'หายไปแล้ว ต้องแก้' end
            from pg_proc p join pg_namespace n on n.oid=p.pronamespace
            where n.nspname='public' and p.proname='rain_alert_collect'),'ไม่พบ')
union all
select 'ของเดิม ประตู 2 ฝนหนัก',
  coalesce((select case when prosrc like '%rainHeavyMinPx%' then 'อยู่ครบ' else 'หายไปแล้ว ต้องแก้' end
            from pg_proc p join pg_namespace n on n.oid=p.pronamespace
            where n.nspname='public' and p.proname='rain_alert_collect'),'ไม่พบ')
union all
select 'ของเดิม ประตู 3 วง 3 กม.',
  coalesce((select case when prosrc like '%rainYolkMinPct%' then 'อยู่ครบ' else 'หายไปแล้ว ต้องแก้' end
            from pg_proc p join pg_namespace n on n.oid=p.pronamespace
            where n.nspname='public' and p.proname='rain_alert_collect'),'ไม่พบ')
union all
select 'ของเดิม ช่วงเร่งด่วน',
  coalesce((select case when prosrc like '%rush:%' then 'อยู่ครบ' else 'หายไปแล้ว ต้องแก้' end
            from pg_proc p join pg_namespace n on n.oid=p.pronamespace
            where n.nspname='public' and p.proname='rain_alert_collect'),'ไม่พบ')
union all
select 'ของเดิม ตรวจภาพเรดาร์ค้าง',
  coalesce((select case when prosrc like '%rainSameCount%' then 'อยู่ครบ' else 'หายไปแล้ว ต้องแก้' end
            from pg_proc p join pg_namespace n on n.oid=p.pronamespace
            where n.nspname='public' and p.proname='rain_alert_collect'),'ไม่พบ')
union all
select 'ของเดิม บันทึกวงเล็กลงตาราง',
  coalesce((select case when prosrc like '%yolk_pct%' then 'อยู่ครบ' else 'หายไปแล้ว ต้องแก้' end
            from pg_proc p join pg_namespace n on n.oid=p.pronamespace
            where n.nspname='public' and p.proname='rain_alert_collect'),'ไม่พบ')
union all
select 'ของเดิม ตัวยิงสองวง',
  coalesce((select case when prosrc like '%rainYolkUrl%' then 'อยู่ครบ' else 'หายไปแล้ว ต้องแก้' end
            from pg_proc p join pg_namespace n on n.oid=p.pronamespace
            where n.nspname='public' and p.proname='rain_alert_fire'),'ไม่พบ')
union all
select 'แบ็กสแลชแปลกปลอม',
  coalesce((select 'พบ ต้องแก้' from pg_proc p join pg_namespace n on n.oid=p.pronamespace
            where n.nspname='public' and p.proname in ('rain_alert_collect','rain_alert_fire')
              and position(chr(92) in p.prosrc) > 0 limit 1), 'สะอาด ไม่มีเลย')
union all
select 'โควตาวันนี้ใช้ไปแล้ว',
  coalesce((select string_agg(distinct ref_id, '  ') from line_sent
            where kind='rain'
              and sent_at >= date_trunc('day', now() at time zone 'Asia/Bangkok')
                            at time zone 'Asia/Bangkok'), 'ยังไม่ส่ง')
union all
select 'ทดสอบย้อนหลัง คืน 9 ก.ย.',
  'ข้อความ 21:29 รหัส ep:2026-09-09:2 จะไม่ออกไปถ้าใช้กติกาใหม่'
;
