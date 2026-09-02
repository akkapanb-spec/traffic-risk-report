-- เพิ่มประตูที่สอง ส่งข้อความเมื่อฝนหนัก ถึงแม้จะยังคลุมพื้นที่ไม่ถึงเกณฑ์
-- ถ้ามีอักขระแปลกปลอมต่อท้ายบรรทัดสุดท้าย ให้ลบออกก่อนกด Run
-- เกณฑ์ 15 เปอร์เซ็นต์เดิมยังอยู่ทุกประการ ไฟล์นี้ไม่ได้เอาอะไรออก
--
-- ------------------------------------------------------------
-- เหตุที่ต้องเพิ่ม  หลักฐานจาก 2 ก.ย. 2569 บ่าย
-- ------------------------------------------------------------
-- ก้อนฝนเดี่ยวก่อตัวคาเมือง ไม่มีฝนที่อื่นในรัศมี 30 กม. เลย
--
--   13:08   คลุม 13.2 เปอร์เซ็นต์   แรงสุด 40 dBZ   ฝนหนัก 1.4 ตร.กม.
--   13:22   คลุม 14.6 เปอร์เซ็นต์   แรงสุด 48 dBZ   ฝนหนัก 7.2 ตร.กม.
--
-- 48 dBZ คือค่าแรงที่สุดที่ระบบเคยอ่านได้ แรงกว่าวันที่ฝนคลุมเมือง 84 เปอร์เซ็นต์
-- เมื่อ 31 ส.ค. ซึ่งวันนั้นแรงสุดแค่ 32 dBZ
--
-- แต่ระบบเงียบ เพราะ 14.6 ยังไม่ถึง 15  ขาดอยู่ 2 จุดภาพ คือ 0.7 ตร.กม.
--
-- ------------------------------------------------------------
-- ทำไมเกณฑ์เดิมมองไม่เห็น
-- ------------------------------------------------------------
-- เปอร์เซ็นต์วัดว่าฝนคลุมพื้นที่กว้างแค่ไหน ไม่ได้วัดว่าฝนตกหนักแค่ไหน
--   ฝนปรอยคลุมทั้งเมือง        อ่านได้สูง   ส่ง
--   ฝนกระหน่ำเป็นก้อนคาเมือง   อ่านได้ต่ำ   เงียบ
-- ก้อนหลังอันตรายกว่าสำหรับคนที่อยู่ใต้มัน
--
-- ตัวอ่านเรดาร์ส่งค่า heavyPixels มาให้ทุกรอบตั้งแต่วันแรก
-- คือจำนวนจุดภาพที่แรงตั้งแต่ 36 dBZ ขึ้นไป
-- แต่กติกาการส่งไม่เคยหยิบมาใช้เลย  ข้อมูลอยู่ในมือแต่ไม่ได้ใช้
--
-- ------------------------------------------------------------
-- ที่เลือกเกณฑ์ 3 จุด และเหตุผลที่ยังไม่มั่นใจ
-- ------------------------------------------------------------
-- 3 จุดภาพ เท่ากับ 1.1 ตร.กม. ที่มีฝนหนัก
--   ถ้าใช้ 1 จุด จะไวเกินไป จุดเดียวอาจเป็นค่าผิดปกติของภาพ
--   ถ้าใช้ 10 จุด ก็กลับไปเป็นปัญหาเดิม คือรอจนฝนคลุมกว้างเสียก่อน
-- ถ้าใช้เกณฑ์นี้ วันนี้ระบบจะส่งตั้งแต่ 13:08 ซึ่งเร็วกว่าที่เป็นอยู่ 20 นาที
--
-- ต้องพูดตรง ๆ ว่า **ทดสอบย้อนหลังไม่ได้** เพราะไม่เคยเก็บ heavyPixels ลงตาราง
-- จึงไม่รู้ว่าเกณฑ์ 3 จุดจะยิงบ่อยแค่ไหนในวันที่ฝนไม่ได้หนักจริง
-- ไฟล์นี้เริ่มเก็บทั้ง heavyPixels และ maxDbz ตั้งแต่รอบแรกหลังติดตั้ง
-- อีกสองสามสัปดาห์จะมีข้อมูลพอให้ปรับตัวเลขจากของจริงแทนการเดา
--
-- ตัวเลขอยู่ใน bs_settings จึงเปลี่ยนได้ด้วย update บรรทัดเดียว ไม่ต้องมาแก้ไฟล์อีก
--   update bs_settings set val = to_jsonb(5) where key = 'rainHeavyMinPx';
--
-- ------------------------------------------------------------
-- สิ่งที่ไม่ได้เปลี่ยน
-- ------------------------------------------------------------
-- กติกาสามข้อที่ตกลงกันไว้ยังอยู่ครบ ใช้กับประตูใหม่ด้วยเหมือนกัน
--   ช่วงเร่งด่วนจันทร์ถึงศุกร์ได้สิทธิ์ของตัวเอง
--   นอกช่วงเร่งด่วนต้องเป็นรอบฝนใหม่ และเว้นอย่างน้อย 45 นาที
--   ไม่เกินสามข้อความต่อวัน
-- ประตูใหม่แค่เปิดทางให้เข้ามาได้ ไม่ได้ยกเลิกด่านไหนเลย

-- ==========================================================
-- 1  เก็บความแรงไว้ด้วย จะได้ปรับเกณฑ์จากของจริงในอนาคต
-- ==========================================================

alter table rain_track add column if not exists heavy_px int;
alter table rain_track add column if not exists max_dbz  numeric;

-- ==========================================================
-- 2  ค่าตั้ง
-- ==========================================================

insert into bs_settings (key, val) values ('rainHeavyMinPx', to_jsonb(3))
on conflict (key) do nothing;

-- ==========================================================
-- 3  ตัวอ่านผลและตัวตัดสินใจส่ง
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
  v_min    numeric := coalesce((select (val #>> array[]::text[])::numeric from bs_settings where key = 'rainMinPct'), 15);
  v_hmin   int     := coalesce((select (val #>> array[]::text[])::int     from bs_settings where key = 'rainHeavyMinPx'), 3);
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
  v_why    text;
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
  v_dbz   := nullif(v_j->>'maxDbz', '')::numeric;

  -- บันทึกร่องรอยทุกรอบ ไม่ว่าจะส่งข้อความหรือไม่
  -- เก็บความแรงไว้ด้วย เพราะเกณฑ์ความแรงจะปรับได้ก็ต่อเมื่อมีของจริงให้ดูย้อนหลัง
  insert into rain_track (pct8, nearest_km, outer_px, clat, clng,
                          east_kmh, north_kmh, near_east, near_north, spread_kmh,
                          heavy_px, max_dbz)
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
          v_heavy, v_dbz);

  delete from rain_track where seen_at < now() - interval '30 days';

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

  -- ============================================================
  -- สองประตู  เข้าได้ประตูใดประตูหนึ่งก็พอ
  -- ============================================================
  -- ประตูที่หนึ่ง  ฝนคลุมพื้นที่กว้าง  ของเดิม ไม่ได้แก้
  -- ประตูที่สอง   ฝนหนักเป็นก้อน      ของใหม่
  --
  -- เก็บเหตุผลไว้ใน v_why เพื่อให้ตอนตรวจย้อนหลังรู้ว่าเข้ามาทางไหน
  -- ถ้าไม่เก็บ จะแยกไม่ออกว่าข้อความไหนมาจากประตูใหม่ แล้วปรับเกณฑ์ไม่ถูก

  if v_pct >= v_min then
    v_why := 'คลุมพื้นที่ ' || v_pct || ' เปอร์เซ็นต์';
  elsif v_heavy >= v_hmin then
    v_why := 'ฝนหนัก ' || v_heavy || ' จุด แรงสุด ' || coalesce(v_dbz::text, '-') || ' dBZ';
  else
    return jsonb_build_object('success', true, 'source', v_src,
      'rainPercent', v_pct, 'heavyPixels', v_heavy, 'maxDbz', v_dbz,
      'message', 'ยังไม่ถึงเกณฑ์ทั้งสองทาง  พื้นที่ ' || v_pct || ' จาก ' || v_min
                 || '  ฝนหนัก ' || v_heavy || ' จาก ' || v_hmin || ' จุด');
  end if;

  -- ============================================================
  -- ด่านกันส่งซ้ำ  ใช้กับทั้งสองประตูเหมือนกัน ไม่ได้ยกเว้นให้ประตูใหม่
  -- ============================================================
  -- นับด้วย distinct ref_id ไม่ใช่นับแถว เพราะหนึ่งข้อความสร้างหนึ่งแถวต่อปลายทาง

  v_today := (select count(distinct ref_id) from line_sent
              where kind = 'rain'
                and sent_at >= date_trunc('day', now() at time zone 'Asia/Bangkok')
                              at time zone 'Asia/Bangkok');

  if v_today >= 3 then
    return jsonb_build_object('success', true, 'source', v_src, 'rainPercent', v_pct,
      'heavyPixels', v_heavy, 'message', 'ครบสามข้อความแล้ววันนี้ จึงไม่ส่งเพิ่ม');
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
    v_ref := 'rush:' || to_char(now() at time zone 'Asia/Bangkok', 'YYYY-MM-DD') || ':' || v_rush;
  else
    select max(sent_at) into v_last from line_sent where kind = 'rain';

    if v_last is not null and v_last > now() - interval '45 minutes' then
      return jsonb_build_object('success', true, 'source', v_src, 'rainPercent', v_pct,
        'heavyPixels', v_heavy, 'message', 'เพิ่งส่งไปยังไม่ถึง 45 นาที จึงยังไม่ส่งซ้ำ');
    end if;

    -- รอบใหม่แปลว่าเคยเงียบทั้งสองทาง ไม่ใช่แค่พื้นที่ลด
    -- ถ้าดูแต่พื้นที่ ฝนก้อนเดิมที่หนักตลอดจะถูกนับเป็นรอบใหม่ทุกครั้งที่พื้นที่แกว่ง
    if v_last is not null
       and not exists (select 1 from rain_track
                       where seen_at > v_last
                         and pct8 < v_min
                         and coalesce(heavy_px, 0) < v_hmin) then
      return jsonb_build_object('success', true, 'source', v_src, 'rainPercent', v_pct,
        'heavyPixels', v_heavy,
        'message', 'ยังเป็นฝนรอบเดิม ยังไม่เคยเงียบเลยตั้งแต่ข้อความที่แล้ว');
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
    'maxDbz',  v_dbz,
    'gate',    v_why,
    'ref',     v_ref,
    'countToday', v_today,
    'sent',    v_sent,
    'message', case when v_sent > 0 then 'ส่งแล้ว ' || v_sent || ' กลุ่ม เพราะ ' || v_why
                    else 'รหัส ' || v_ref || ' ส่งไปแล้วก่อนหน้านี้ จึงเงียบ' end
  );
end;
$fn$;

-- ==========================================================
-- ตรวจผล  คำสั่งสุดท้ายคำสั่งเดียวที่จะแสดงผล
-- ==========================================================
-- สามบรรทัดกลางสำคัญที่สุด ถ้าขึ้นว่าหายไปแปลว่าเขียนทับของเดิมพัง
-- ให้บอกทันที อย่าปล่อยไว้ เพราะจะเงียบไปเป็นวันโดยไม่มีอาการ

select 'ประตูที่สอง ฝนหนัก' as รายการ,
  coalesce((select case when prosrc like '%rainHeavyMinPx%' then 'ติดตั้งแล้ว' else 'ยังไม่มี' end
            from pg_proc p join pg_namespace n on n.oid=p.pronamespace
            where n.nspname='public' and p.proname='rain_alert_collect'), 'ไม่พบฟังก์ชัน') as ผล
union all
select 'ประตูที่หนึ่ง เกณฑ์พื้นที่ ยังอยู่',
  coalesce((select case when prosrc like '%v_pct >= v_min%' then 'อยู่ครบ' else 'หายไปแล้ว ต้องแก้' end
            from pg_proc p join pg_namespace n on n.oid=p.pronamespace
            where n.nspname='public' and p.proname='rain_alert_collect'), 'ไม่พบ')
union all
select 'กติกาช่วงเร่งด่วน ยังอยู่',
  coalesce((select case when prosrc like '%rush:%' then 'อยู่ครบ' else 'หายไปแล้ว ต้องแก้' end
            from pg_proc p join pg_namespace n on n.oid=p.pronamespace
            where n.nspname='public' and p.proname='rain_alert_collect'), 'ไม่พบ')
union all
select 'เพดาน 3 ครั้งต่อวัน ยังอยู่',
  coalesce((select case when prosrc like '%v_today >= 3%' then 'อยู่ครบ' else 'หายไปแล้ว ต้องแก้' end
            from pg_proc p join pg_namespace n on n.oid=p.pronamespace
            where n.nspname='public' and p.proname='rain_alert_collect'), 'ไม่พบ')
union all
select 'ส่วนตรวจภาพเรดาร์ค้าง ยังอยู่',
  coalesce((select case when prosrc like '%rainSameCount%' then 'อยู่ครบ' else 'หายไปแล้ว ต้องแก้' end
            from pg_proc p join pg_namespace n on n.oid=p.pronamespace
            where n.nspname='public' and p.proname='rain_alert_collect'), 'ไม่พบ')
union all
select 'ช่องเก็บความแรงในตาราง',
  case when exists (select 1 from information_schema.columns
                    where table_schema='public' and table_name='rain_track' and column_name='heavy_px')
       then 'เพิ่มแล้ว เริ่มเก็บรอบหน้า' else 'ยังไม่มี' end
union all
select 'เกณฑ์ที่ใช้ตอนนี้',
  'พื้นที่ ' || coalesce((select val #>> array[]::text[] from bs_settings where key='rainMinPct'),'15')
  || ' เปอร์เซ็นต์   หรือ   ฝนหนัก '
  || coalesce((select val #>> array[]::text[] from bs_settings where key='rainHeavyMinPx'),'3') || ' จุด'
union all
select 'แบ็กสแลชแปลกปลอม',
  coalesce((select 'พบ ต้องแก้' from pg_proc p join pg_namespace n on n.oid=p.pronamespace
            where n.nspname='public' and p.proname='rain_alert_collect'
              and position(chr(92) in p.prosrc) > 0), 'สะอาด ไม่มีเลย')
union all
select 'ข้อความฝนวันนี้',
  coalesce((select string_agg(distinct ref_id, '  ') from line_sent
            where kind='rain'
              and sent_at >= date_trunc('day', now() at time zone 'Asia/Bangkok')
                            at time zone 'Asia/Bangkok'), 'ยังไม่ส่ง') || '   เพดานวันละ 3';
