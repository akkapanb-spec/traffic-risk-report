-- ============================================================
-- ฝนแรก — ทดสอบว่าฝนตกใหม่หลังทิ้งช่วงอันตรายกว่าฝนต่อเนื่องจริงไหม
-- ============================================================
-- ต้องรัน weather_1_tables.sql มาก่อน
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
--
-- ที่มาของคำถาม
--   ความรู้หน้างานจากเจ้าหน้าที่: ฝนตกหนักไม่ใช่ปัญหา เพราะรถจักรยานยนต์หยุดขี่
--   อันตรายจริงคือฝนแรกหลังทิ้งช่วง — น้ำมัน ยางรถ ฝุ่นที่สะสมบนผิวแอสฟัลต์
--   ลอยขึ้นมาผสมกับน้ำบาง ๆ กลายเป็นฟิล์มลื่น
--   พอฝนตกต่อเนื่องน้ำจะชะล้างออก ถนนกลับปลอดภัยขึ้น
--
--   นี่คือสมมติฐาน ไฟล์นี้มีไว้ "ทดสอบ" ไม่ใช่ยืนยันล่วงหน้า
--   ถ้าข้อมูลไม่สนับสนุน ก็ต้องยอมรับตามข้อมูล
--
-- ทำไมเรื่องนี้สำคัญกว่าเกณฑ์ฝนหนัก
--   ถ้าจริง การเตือนต้องเปลี่ยนจาก "พรุ่งนี้ฝนหนัก" เป็น
--   "ฝนกำลังจะตกหลังแล้งมาหลายวัน ช่วงชั่วโมงแรกระวังลื่น"
--   ซึ่งเป็นคนละเหตุการณ์กันโดยสิ้นเชิง และเตือนน้อยครั้งกว่ามาก
--
-- วิธีคิด
--   ไล่ชั่วโมงเรียงกันในแต่ละโซน จับกลุ่มช่วงที่เปียกติดกันเป็นหนึ่ง "ระลอกฝน"
--   ระลอกไหนที่ก่อนหน้ามีช่วงแห้งยาวเกินเกณฑ์ = ฝนแรก
--   นับเฉพาะไม่กี่ชั่วโมงแรกของระลอกนั้น เพราะฟิล์มลื่นถูกชะล้างเร็ว
-- ============================================================

set search_path = public, extensions;

-- ============================================================
-- เทียบสามสถานะ: แห้ง / ฝนแรก / ฝนต่อเนื่อง
-- ============================================================
-- p_wet_mm    ฝนกี่ มม./ชม. ถึงนับว่าตก
-- p_gap_hours ต้องแห้งติดกันกี่ชั่วโมงก่อนหน้า ถึงนับว่าเป็น "ฝนแรก"
-- p_first_hrs นับกี่ชั่วโมงแรกของระลอกว่ายังอยู่ในช่วงลื่น
create or replace function wx_first_rain(p_token text, p_wet_mm real default 0.2,
  p_gap_hours int default 24, p_first_hrs int default 2)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $wx_first_rain$
declare v_err jsonb; v_out jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;

  if not exists (select 1 from wx_hourly) then
    return jsonb_build_object('success', false, 'message', 'ยังไม่มีข้อมูลสภาพอากาศ กดดึงข้อมูลก่อน');
  end if;

  with
  h as (
    select zone_code, hour, coalesce(precip_mm, 0) >= p_wet_mm as wet
      from wx_hourly
  ),
  -- จับกลุ่มชั่วโมงที่สถานะเหมือนกันและติดกัน ให้เป็นระลอกเดียว
  -- ผลต่างของเลขลำดับสองชุดจะคงที่ภายในระลอกเดียวกัน เป็นวิธีจับกลุ่มมาตรฐาน
  tagged as (
    select zone_code, hour, wet,
           row_number() over (partition by zone_code order by hour)
         - row_number() over (partition by zone_code, wet order by hour) as grp
      from h
  ),
  pos as (
    select zone_code, hour, wet, grp,
           row_number() over (partition by zone_code, grp order by hour) as pos_in_run
      from tagged
  ),
  runs as (
    select zone_code, wet, grp, min(hour) as run_start, count(*)::int as run_len
      from pos group by zone_code, wet, grp
  ),
  -- ความยาวของระลอกก่อนหน้า ใช้ตัดสินว่าระลอกฝนนี้ตามหลังช่วงแห้งยาวหรือไม่
  runs_prev as (
    select r.*,
           lag(r.run_len) over (partition by r.zone_code order by r.run_start) as prev_len,
           lag(r.wet)     over (partition by r.zone_code order by r.run_start) as prev_wet
      from runs r
  ),
  first_runs as (
    select zone_code, grp from runs_prev
     where wet and prev_wet is false and coalesce(prev_len, 0) >= p_gap_hours
  ),
  classed as (
    select p.zone_code, p.hour,
           case when not p.wet then 'dry'
                when exists (select 1 from first_runs f
                              where f.zone_code = p.zone_code and f.grp = p.grp)
                     and p.pos_in_run <= p_first_hrs then 'first'
                else 'rain' end as state
      from pos p
  ),
  acc as (
    select date_trunc('hour', timezone('Asia/Bangkok', a.incident_datetime))
             at time zone 'Asia/Bangkok' as hour,
           (select z.code from wx_zones z where z.enabled
              order by (z.latitude - a.latitude)^2 + (z.longitude - a.longitude)^2
              limit 1) as zone_code
      from accidents a
     where a.latitude is not null and a.longitude is not null
       and a.latitude between 14 and 17 and a.longitude between 99 and 101
  ),
  joined as (
    select c.state, count(a.hour) as n_acc
      from classed c left join acc a
        on a.zone_code = c.zone_code and a.hour = c.hour
     group by c.zone_code, c.hour, c.state
  ),
  agg as (
    select state, count(*)::int as hours, coalesce(sum(n_acc), 0)::int as acc
      from joined group by state
  )
  select jsonb_build_object(
    'success', true,
    'wet_mm', p_wet_mm, 'gap_hours', p_gap_hours, 'first_hrs', p_first_hrs,
    'states', coalesce(jsonb_object_agg(a.state, jsonb_build_object(
        'hours', a.hours, 'acc', a.acc,
        'rate', case when a.hours > 0 then round((a.acc::numeric / a.hours) * 1000, 2) end
      )), '{}'::jsonb)
  ) into v_out from agg a;

  return v_out;
end $wx_first_rain$;

grant execute on function wx_first_rain(text, real, int, int) to anon, authenticated;

-- ============================================================
-- ตรวจผลหลังรัน
-- ============================================================
-- อ่านที่ rate ของแต่ละสถานะ (ครั้งต่อ 1,000 ชั่วโมง)
--   dry   = แห้ง
--   first = ฝนแรกหลังทิ้งช่วง
--   rain  = ฝนต่อเนื่อง
--
-- ถ้าสมมติฐานถูก first จะสูงกว่าทั้ง dry และ rain อย่างเห็นได้ชัด
-- ถ้า first กับ rain พอ ๆ กัน แปลว่าฝนแรกไม่ได้พิเศษ ต้องยอมรับตามข้อมูล
--
--   select wx_first_rain('<token แอดมิน>', 0.2, 24, 2);
--
-- ลองปรับช่วงแห้งดู 12 / 24 / 48 ชั่วโมง ว่าผลเปลี่ยนไหม
-- ถ้าต้องแห้งยิ่งนานผลยิ่งชัด แปลว่ากลไกการสะสมคราบเป็นเรื่องจริง
