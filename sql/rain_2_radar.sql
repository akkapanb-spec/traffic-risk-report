-- แจ้งเตือนฝนเข้ากลุ่มไลน์ โดยอ่านจากเรดาร์จริง
-- รันไฟล์นี้ไฟล์เดียว ไม่ต้องรัน rain_1_alert.sql
-- ถ้ามี $0 ต่อท้ายไฟล์ ให้ลบออกก่อนกด Run
--
-- ต้อง deploy Edge Function ชื่อ rain ก่อน ไม่งั้นตัวนี้จะได้แต่ข้อผิดพลาด
--
-- ต่างจากแบบ Open-Meteo อย่างไร
--   Open-Meteo เป็นโมเดลพยากรณ์ บอกล่วงหน้าได้แต่บางทีผิดตำแหน่ง
--   อันนี้เป็นเรดาร์จริง เห็นกลุ่มฝนที่มีอยู่จริง ณ ขณะนั้น
--   เฝ้าเป็นวงรัศมี 8 กิโลเมตรรอบแยกเดชาติวงศ์ ไม่ใช่จุดเดียว
--   เพราะถ้าเฝ้าจุดเดียว กว่าจะเตือนคนที่ขับอยู่ตรงนั้นก็เปียกไปแล้ว
--   ฝนเคลื่อนที่ราว 20 ถึง 40 กม. ต่อชั่วโมง วง 8 กม. จึงให้เวลาราว 12 ถึง 25 นาที
--
-- ส่งได้วันละข้อความเดียวเท่านั้น ต่อให้ฝนตกหลายระลอก
-- เพราะกลุ่มนี้มีสมาชิกจากกิจกรรมแจกหมวกที่ต้องอยู่ในกลุ่มเพื่อรักษาสิทธิ์
-- ข้อความถี่เกินไปจะทำให้คนออกจากกลุ่ม แล้วเครดิตของคนที่ชวนเขามาหายไปด้วย

-- ==========================================================
-- 1  ค่าตั้ง
-- ==========================================================
-- rainRadarUrl  ที่อยู่ของตัวอ่านเรดาร์
-- rainMinPct    ต้องมีฝนกี่เปอร์เซ็นต์ของวงจึงจะเตือน
--               ตั้ง 15 เพื่อไม่ให้เมฆฝนก้อนเล็กที่ผ่านขอบวงไปเฉย ๆ ทำให้เตือน

insert into bs_settings (key, val) values
  ('rainAlertEnabled', to_jsonb(false)),
  ('rainRadarUrl',     to_jsonb('https://ftpruljwwsmvipfcedyk.supabase.co/functions/v1/rain?km=8'::text)),
  ('rainMinPct',       to_jsonb(15))
on conflict (key) do update set val = excluded.val;

-- ==========================================================
-- 2  ตารางจับคู่คำขอกับคำตอบ
-- ==========================================================

create table if not exists rain_probe (
  req_id   bigint primary key,
  fired_at timestamptz not null default now(),
  done     boolean not null default false
);

alter table rain_probe enable row level security;
revoke all on rain_probe from anon, authenticated;

-- ==========================================================
-- 3  จังหวะที่หนึ่ง ยิงไปถามตัวอ่านเรดาร์
-- ==========================================================
-- ต้องแยกยิงกับอ่านเป็นคนละรอบ เพราะ pg_net ยิงจริงหลังทรานแซกชันปิดเท่านั้น

create or replace function rain_alert_fire()
returns bigint
language plpgsql
volatile
security definer
set search_path = public
as $fn$
declare
  v_req bigint;
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

  insert into rain_probe (req_id) values (v_req) on conflict (req_id) do nothing;
  return v_req;
end;
$fn$;

-- ==========================================================
-- 4  จังหวะที่สอง อ่านคำตอบแล้วตัดสินใจ
-- ==========================================================

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
  -- line_sent เป็นตัวกันเอง ฟังก์ชันไม่ต้องจำอะไรไว้
  v_ref := 'day:' || to_char(now() at time zone 'Asia/Bangkok', 'YYYY-MM-DD');

  v_text := array_to_string(array[
    '🌧️ เตือนฝนกำลังเข้าเขตเมือง',
    'เรดาร์ตรวจพบกลุ่มฝนในรัศมี 8 กิโลเมตรรอบแยกเดชาติวงศ์'
      || case when v_heavy > 0 then '  มีฝนหนักปนอยู่ด้วย' else '' end,
    '',
    'ช่วงอันตรายที่สุดคือไม่กี่นาทีแรกที่ฝนเริ่มตก',
    'น้ำผสมกับคราบน้ำมันบนผิวถนนกลายเป็นฟิล์มลื่น',
    'ยางเกาะถนนได้น้อยลงมาก ทั้งที่ถนนยังดูเหมือนแค่ชื้น',
    '',
    'ลดความเร็ว และเพิ่มระยะห่างจากรถคันหน้าเป็นสองเท่า',
    '',
    '👮 จราจรชอนตะวัน และผู้เกี่ยวข้อง'
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
-- 5  ตั้งเวลาทำงาน
-- ==========================================================
-- เรดาร์ออกภาพใหม่ทุก 10 นาที ตรวจทุก 15 นาทีจึงเพียงพอ
-- ยิงกับอ่านต้องคนละรอบ เพราะ pg_net ยิงจริงหลังทรานแซกชันปิด

select cron.unschedule(jobname) from cron.job where jobname in ('rain-fire', 'rain-collect');

select cron.schedule('rain-fire',    '0,15,30,45 * * * *', 'select rain_alert_fire()');
select cron.schedule('rain-collect', '5,20,35,50 * * * *', 'select rain_alert_collect()');

-- ==========================================================
-- ตรวจผล  คำสั่งสุดท้ายคำสั่งเดียวที่จะแสดงผล
-- ==========================================================

select 'สวิตช์แจ้งเตือนฝน' as รายการ,
       coalesce((select val #>> array[]::text[] from bs_settings where key = 'rainAlertEnabled'), 'ไม่พบ')
       || '   ยังปิดอยู่ตามที่ตั้งใจ' as ผล
union all
select 'ที่อยู่ตัวอ่านเรดาร์',
       coalesce((select val #>> array[]::text[] from bs_settings where key = 'rainRadarUrl'), 'ไม่พบ')
union all
select 'เกณฑ์ฝนในวง',
       coalesce((select val #>> array[]::text[] from bs_settings where key = 'rainMinPct'), '-')
       || ' เปอร์เซ็นต์ของพื้นที่วง 8 กิโลเมตร'
union all
select 'ส่งได้บ่อยแค่ไหน', 'วันละหนึ่งข้อความเท่านั้น'
union all
select 'งานตั้งเวลา',
       coalesce((select string_agg(jobname || ' = ' || schedule, '   ' order by jobname)
                 from cron.job where jobname like 'rain-%'), 'ไม่พบ')
union all
select 'ขั้นต่อไป',
       'deploy Edge Function ชื่อ rain แล้วบอกผม ผมจะทดสอบให้ก่อนเปิดสวิตช์';
