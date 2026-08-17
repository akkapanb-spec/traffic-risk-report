-- ============================================================
-- แก้ wx_first_rain เรียกไม่ได้ — invalid input syntax for type json
-- ============================================================
-- ต้องรัน weather_2_firstrain.sql มาก่อน ไฟล์นี้เขียนทับฟังก์ชันเดิม
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
--
-- อาการ
--   หน้าเว็บขึ้น "ไม่สามารถเรียกฟังก์ชันนี้ได้: invalid input syntax for type json"
--   ขณะที่ wx_stats ซึ่งรับพารามิเตอร์ชุดคล้ายกันทำงานได้ปกติ
--
-- ความต่างจุดเดียวระหว่างสองตัว
--   ตัวที่พังคืนผลด้วย jsonb_object_agg (สร้าง object ที่คีย์มาจากค่าในคอลัมน์)
--   ตัวที่ใช้ได้คืนผลด้วย jsonb_agg (สร้าง array ของ object)
--   จึงเปลี่ยนมาใช้แบบเดียวกับตัวที่พิสูจน์แล้วว่าใช้ได้บนฐานข้อมูลนี้
--
--   หมายเหตุตามตรง: นี่คือการตัดความต่างที่เหลืออยู่จุดเดียวออก
--   ไม่ได้ยืนยันว่าสาเหตุคือบรรทัดนั้นแน่นอน เพราะรัน SQL เองไม่ได้
--   ถ้ารันแล้วยังพังเหมือนเดิม แปลว่าเดาผิด ต้องดูข้อความเต็มจาก SQL Editor
--
-- คืนค่าเป็น array แทน object — หน้าเว็บแก้ให้รับรูปแบบใหม่แล้ว
-- ============================================================

set search_path = public, extensions;

create or replace function wx_first_rain(p_token text, p_wet_mm real default 0.2,
  p_gap_hours int default 24, p_first_hrs int default 2)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $wx_first_rain$
declare
  v_err jsonb;
  v_out jsonb;
  v_wet numeric;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;

  if not exists (select 1 from wx_hourly) then
    return jsonb_build_object('success', false, 'message', 'ยังไม่มีข้อมูลสภาพอากาศ กดดึงข้อมูลก่อน');
  end if;

  -- แปลง real เป็น numeric ก่อนใส่ลง jsonb
  -- real เป็นเลขทศนิยมความแม่นยำเดียว ซึ่งแปลงเป็นข้อความได้หลายรูปแบบ
  v_wet := round(p_wet_mm::numeric, 2);

  with
  wx as (
    select zone_code, hour, coalesce(precip_mm, 0) >= p_wet_mm as wet from wx_hourly
  ),
  tagged as (
    select zone_code, hour, wet,
           row_number() over (partition by zone_code order by hour)
         - row_number() over (partition by zone_code, wet order by hour) as grp
      from wx
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
  runs_prev as (
    select r.*, lag(r.run_len) over (partition by r.zone_code order by r.run_start) as prev_len,
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
                when exists (select 1 from first_runs f where f.zone_code = p.zone_code and f.grp = p.grp)
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
    'wet_mm', v_wet,
    'gap_hours', p_gap_hours,
    'first_hrs', p_first_hrs,
    -- array แทน object — โครงเดียวกับ wx_stats ที่ใช้ได้อยู่
    'rows', coalesce(jsonb_agg(jsonb_build_object(
        'state', a.state,
        'hours', a.hours,
        'acc',   a.acc,
        'rate',  case when a.hours > 0 then round((a.acc::numeric / a.hours) * 1000, 2) end
      ) order by a.state), '[]'::jsonb)
  ) into v_out from agg a;

  return v_out;
end $wx_first_rain$;

grant execute on function wx_first_rain(text, real, int, int) to anon, authenticated;

-- ============================================================
-- ตรวจผลหลังรัน
-- ============================================================
-- รันตรงในหน้า SQL Editor จะเห็นข้อความ error เต็มถ้ายังพัง
-- (ต้องใส่ token แอดมินจริง หาได้จาก DevTools > Application > Local Storage
--  คีย์ accidentTrafficPoliceSession บนหน้าเจ้าหน้าที่ที่ล็อกอินอยู่)
--
--   select wx_first_rain('<token>', 1.0, 24, 1);
--
-- ควรได้ rows สามแถว state = dry / first / rain
-- ถ้ายังขึ้น invalid input syntax for type json แปลว่าผมเดาสาเหตุผิด
-- ให้ส่งข้อความ error เต็มพร้อมเลขบรรทัดมาให้ดู
