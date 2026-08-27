-- ติดตามทิศทางฝน และเตือนก่อนฝนเข้าวง
-- ถ้ามีอักขระแปลกปลอมต่อท้ายบรรทัดสุดท้าย ให้ลบออกก่อนกด Run
-- ต้อง deploy Edge Function ชื่อ rain ฉบับใหม่ก่อน ไม่งั้นจะไม่มีข้อมูลวงนอกให้เก็บ
--
-- ------------------------------------------------------------
-- ปัญหาที่ไฟล์นี้แก้
-- ------------------------------------------------------------
-- 27 ส.ค. 2569 เรดาร์อ่านได้ 2 เปอร์เซ็นต์ตอน 19:30 และ 17.9 ตอน 19:45
-- ระบบส่งข้อความตอน 19:50 ซึ่งเป็นเวลาที่ฝนเข้าเขตเมืองไปแล้ว
-- คนที่กำลังจะออกจากบ้านตอน 19:40 จึงไม่ได้ประโยชน์
--
-- การเพิ่มความถี่ช่วยได้ไม่เกินแปดนาที การลดเกณฑ์ช่วยไม่ได้เลยในกรณีนั้น
-- เพราะฝนกระโดดจาก 2 ไป 17.9 ในรอบเดียว ไม่ได้ค่อย ๆ ไต่
--
-- สิ่งที่ช่วยได้จริงคือมองออกไปไกลกว่าวง 8 กม. แล้วดูว่าฝนกำลังเข้ามาไหม
--
-- ------------------------------------------------------------
-- วิธีคำนวณ
-- ------------------------------------------------------------
-- ตัวอ่านเรดาร์รายงานระยะของฝนที่ใกล้ที่สุดในวง 30 กม. มาทุกรอบ
-- เก็บไว้แล้วเทียบสองรอบติดกัน ถ้าระยะลดลง แปลว่าฝนกำลังเข้าหาเรา
--   ความเร็วเข้าหา = ระยะที่ลดลง หารด้วยเวลาที่ผ่านไป
--   เวลาที่คาดว่าจะถึง = ระยะที่เหลือ หารด้วยความเร็วเข้าหา
--
-- ใช้ขอบของก้อนฝน ไม่ใช้ใจกลาง เพราะขอบคือสิ่งที่มาถึงคนก่อน
--
-- ทิศทางคำนวณจากจุดศูนย์กลางของกลุ่มฝนสองรอบ
-- ใช้บอกเป็นคำว่ามาจากทางไหน ไม่ได้ใช้ตัดสินใจส่ง
--
-- ------------------------------------------------------------
-- สิ่งที่ตั้งใจไม่ทำ
-- ------------------------------------------------------------
-- ไม่บอกชื่อถนนที่ฝนเข้าและออก
--   ก้อนฝนกว้างสิบถึงยี่สิบกิโลเมตร คลุมถนนหลายสิบสายพร้อมกัน
--   การบอกชื่อถนนให้ความรู้สึกแม่นยำเกินจริง แล้วคนจะเข้าใจว่าถนนอื่นปลอดภัย
--   บอกเป็นทิศทางกับพื้นที่จึงซื่อสัตย์กว่าและใช้ตัดสินใจได้จริงกว่า
--
-- ไม่บอกว่าฝนจะตกนานกี่นาทีแบบตัวเลขเดียว
--   ก้อนฝนไม่ได้แค่เคลื่อนที่ มันโตและสลายด้วย
--   27 ส.ค. จุดที่มีฝนหายไป 89 จาก 101 จุดใน 15 นาที ซึ่งเร็วกว่าการเคลื่อนที่ล้วน ๆ
--   แปลว่าก้อนนั้นสลายไปด้วย การทำนายระยะเวลาจึงเชื่อถือไม่ได้เท่าทิศทาง
--
-- ไม่เปิดข้อความส่วนนี้ให้ประชาชนทันที
--   ค่าตั้ง rainForecastEnabled เริ่มต้นเป็นปิด ระบบจะเก็บข้อมูลเงียบ ๆ ไปก่อน
--   ต้องเทียบกับฝนจริงอย่างน้อยสามครั้งว่าทิศและเวลาที่คำนวณได้ตรงกับที่เห็น
--   จึงค่อยเปิด  การส่งคำทำนายที่ยังไม่เคยตรวจ ทำลายความเชื่อถือเร็วกว่าการไม่ส่ง

-- ==========================================================
-- 1  ค่าตั้ง
-- ==========================================================

insert into bs_settings (key, val) values
  ('rainForecastEnabled', to_jsonb(false)),
  ('rainEtaMaxMin',       to_jsonb(20))
on conflict (key) do nothing;

-- ==========================================================
-- 2  ตารางเก็บร่องรอยการเคลื่อนที่
-- ==========================================================
-- เก็บเท่าที่ต้องใช้คำนวณ ไม่เก็บภาพ เพราะภาพหนัก 660 กิโลไบต์ต่อรอบ

create table if not exists rain_track (
  id          bigserial primary key,
  seen_at     timestamptz not null default now(),
  pct8        numeric,
  nearest_km  numeric,
  outer_px    int,
  clat        double precision,
  clng        double precision
);

alter table rain_track enable row level security;
revoke all on rain_track from anon, authenticated;

create index if not exists rain_track_seen_idx on rain_track (seen_at desc);

-- ==========================================================
-- 3  แปลงมุมเป็นคำบอกทิศแบบไทย
-- ==========================================================
-- มุม 0 คือทิศเหนือ เพิ่มตามเข็มนาฬิกา
-- ใช้แปดทิศพอ ละเอียดกว่านี้คนอ่านไม่ได้ประโยชน์เพิ่ม

create or replace function rain_dir_thai(p_deg numeric)
returns text
language sql
immutable
as $fn$
  select case
    when p_deg is null then null
    when p_deg <  22.5 or p_deg >= 337.5 then 'ทิศเหนือ'
    when p_deg < 67.5  then 'ทิศตะวันออกเฉียงเหนือ'
    when p_deg < 112.5 then 'ทิศตะวันออก'
    when p_deg < 157.5 then 'ทิศตะวันออกเฉียงใต้'
    when p_deg < 202.5 then 'ทิศใต้'
    when p_deg < 247.5 then 'ทิศตะวันตกเฉียงใต้'
    when p_deg < 292.5 then 'ทิศตะวันตก'
    else 'ทิศตะวันตกเฉียงเหนือ'
  end;
$fn$;

-- ==========================================================
-- 4  คำนวณการเคลื่อนที่จากสองรอบล่าสุด
-- ==========================================================
-- คืน jsonb เสมอ ไม่เคยคืน null เพื่อให้ผู้เรียกไม่ต้องเดาว่าเงียบเพราะอะไร

create or replace function rain_motion()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  a record;   -- รอบล่าสุด
  b record;   -- รอบก่อนหน้า
  v_min numeric;
  v_closing numeric;   -- กิโลเมตรต่อชั่วโมงที่เข้าหาเรา
  v_eta numeric;
  v_deg numeric;
  v_from text;
begin
  select * into a from rain_track order by id desc limit 1;
  if a is null then
    return jsonb_build_object('ok', false, 'why', 'ยังไม่มีข้อมูลติดตาม');
  end if;

  select * into b from rain_track where id < a.id order by id desc limit 1;
  if b is null then
    return jsonb_build_object('ok', false, 'why', 'มีข้อมูลรอบเดียว ยังเทียบไม่ได้');
  end if;

  v_min := extract(epoch from (a.seen_at - b.seen_at)) / 60.0;

  -- ห่างกันน้อยเกินไปหรือมากเกินไป ก็เทียบไม่ได้
  -- น้อยกว่าสามนาที ระยะที่ขยับยังน้อยกว่าความหยาบของภาพ ผลจะเป็นสัญญาณรบกวน
  -- มากกว่าสามสิบนาที ก้อนฝนอาจเป็นคนละก้อนกันแล้ว
  if v_min < 3 or v_min > 30 then
    return jsonb_build_object('ok', false, 'why', 'ช่วงเวลาระหว่างสองรอบไม่เหมาะ ' || round(v_min, 1) || ' นาที');
  end if;

  if a.nearest_km is null then
    return jsonb_build_object('ok', true, 'approaching', false, 'why', 'ไม่มีฝนในวง 30 กม.');
  end if;

  if b.nearest_km is null then
    return jsonb_build_object('ok', true, 'approaching', false,
      'why', 'ฝนเพิ่งโผล่เข้ามาในวง ยังเทียบความเร็วไม่ได้',
      'nearestKm', a.nearest_km);
  end if;

  v_closing := (b.nearest_km - a.nearest_km) / (v_min / 60.0);

  -- ทิศที่ฝนอยู่ เทียบจากจุดศูนย์กลางกลุ่มฝนรอบล่าสุด
  -- บอกว่ามาจากทางไหน จึงใช้ตำแหน่งของฝน ไม่ใช่ทิศที่มันวิ่ง
  if a.clat is not null then
    v_deg := degrees(atan2(
               (a.clng - 100.122704) * cos(radians(15.693907)),
               (a.clat - 15.693907)));
    if v_deg < 0 then v_deg := v_deg + 360; end if;
    v_from := rain_dir_thai(v_deg);
  end if;

  if v_closing <= 1 then
    return jsonb_build_object('ok', true, 'approaching', false,
      'why', 'ฝนไม่ได้เข้าหาตัวเมือง',
      'nearestKm', a.nearest_km, 'closingKmh', round(v_closing, 1),
      'fromThai', v_from);
  end if;

  v_eta := a.nearest_km / v_closing * 60.0;

  return jsonb_build_object(
    'ok', true, 'approaching', true,
    'nearestKm', a.nearest_km,
    'closingKmh', round(v_closing, 1),
    'etaMin', round(v_eta),
    'fromDeg', round(coalesce(v_deg, 0)),
    'fromThai', v_from,
    'gapMin', round(v_min, 1)
  );
end;
$fn$;

-- ==========================================================
-- ตรวจผล  คำสั่งสุดท้ายคำสั่งเดียวที่จะแสดงผล
-- ==========================================================

select 'ตารางติดตาม' as รายการ,
       case when to_regclass('public.rain_track') is null then 'ยังไม่มี' else 'สร้างแล้ว' end as ผล
union all
select 'ข้อมูลที่เก็บไว้แล้ว', (select count(*)::text from rain_track) || ' รอบ'
union all
select 'สวิตช์คำทำนาย',
       coalesce((select val #>> array[]::text[] from bs_settings where key='rainForecastEnabled'), '-')
       || '   ปิดไว้ก่อนตามที่ตั้งใจ'
union all
select 'เกณฑ์เวลาที่จะเตือนล่วงหน้า',
       coalesce((select val #>> array[]::text[] from bs_settings where key='rainEtaMaxMin'), '-') || ' นาที'
union all
select 'ผลคำนวณตอนนี้', rain_motion()::text
union all
select 'ขั้นต่อไป', 'deploy Edge Function ชื่อ rain ฉบับใหม่ แล้วรอเก็บข้อมูลสองรอบขึ้นไป';
