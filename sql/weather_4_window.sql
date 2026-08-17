-- ============================================================
-- นับเฉพาะช่วงที่มีข้อมูลครบทั้งสองฝั่ง
-- ============================================================
-- ต้องรัน weather_1_tables.sql และ weather_3_fix.sql มาก่อน
-- ไฟล์นี้เขียนทับ wx_stats และ wx_first_rain
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
--
-- ปัญหาที่เจอตอนใช้จริง
--   ดึงสภาพอากาศย้อนหลัง 3 ปี แต่ข้อมูลอุบัติเหตุเริ่มเก็บเดือน ก.ค. 2568
--   ตัวหารจึงกลายเป็น 3 ปี ส่วนตัวตั้งมีแค่ 13 เดือน
--
--   ผลที่เห็น: ชั่วโมงแห้ง 59,706 → 197,368 (สามเท่า)
--              อุบัติเหตุแห้ง 773 → 773 (เท่าเดิม)
--              อัตรา 12.95 → 3.92 ต่อพันชั่วโมง
--
--   อัตราถูกเจือจางลงสามเท่าโดยที่ไม่มีอะไรบนหน้าจอบอก
--   ยิ่งดึงข้อมูลอากาศย้อนหลังมากเท่าไหร่ ตัวเลขยิ่งดูดีขึ้นเท่านั้น
--   ซึ่งกลับหัวกลับหางกับความจริง
--
-- วิธีแก้
--   ตัดช่วงวิเคราะห์ให้เหลือเฉพาะส่วนที่ทับกันของสองชุดข้อมูลเสมอ
--   คือตั้งแต่ (อากาศเริ่ม หรือ อุบัติเหตุเริ่ม อันไหนช้ากว่า)
--   ถึง (อากาศจบ หรือ อุบัติเหตุจบ อันไหนเร็วกว่า)
--
--   ทำอัตโนมัติ ไม่ต้องให้คนจำว่าข้อมูลเริ่มเมื่อไหร่
--   ดึงอากาศเกินมาเท่าไหร่ก็ไม่ทำให้ผลเพี้ยน ส่วนที่เกินถูกตัดทิ้งเอง
--
--   และคืนช่วงที่ใช้จริงกลับไปด้วย หน้าเว็บจะได้แสดงให้เห็น
--   ไม่ใช่คำนวณบนช่วงหนึ่งแล้วคนอ่านเข้าใจว่าอีกช่วงหนึ่ง
-- ============================================================

set search_path = public, extensions;

-- ============================================================
-- ช่วงที่ข้อมูลทับกัน — ใช้ร่วมกันทั้งสองฟังก์ชัน
-- ============================================================
create or replace function wx_window(out w_from timestamptz, out w_to timestamptz,
  out acc_from timestamptz, out acc_to timestamptz)
language plpgsql stable security definer set search_path = public, extensions as $wx_window$
declare wx_min timestamptz; wx_max timestamptz;
begin
  select min(hour), max(hour) + interval '1 hour' into wx_min, wx_max from wx_hourly;

  select min(a.incident_datetime), max(a.incident_datetime) into acc_from, acc_to
    from accidents a
   where a.latitude is not null and a.longitude is not null
     and a.latitude between 14 and 17 and a.longitude between 99 and 101;

  -- ตัดหัวตัดท้ายให้เหลือเฉพาะที่มีทั้งอากาศและอุบัติเหตุ
  w_from := greatest(wx_min, date_trunc('hour', acc_from));
  w_to   := least(wx_max, date_trunc('hour', acc_to) + interval '1 hour');
end $wx_window$;

revoke execute on function wx_window() from public, anon, authenticated;

-- ============================================================
-- 1) ฝนกับอุบัติเหตุ — ตัดช่วงแล้ว
-- ============================================================
create or replace function wx_stats(p_token text, p_from date default null,
  p_to date default null, p_wet_mm real default 0.2)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $wx_stats$
declare
  v_err jsonb; v_from timestamptz; v_to timestamptz; v_out jsonb; w record;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;

  select * into w from wx_window();
  if w.w_from is null or w.w_to is null or w.w_to <= w.w_from then
    return jsonb_build_object('success', false,
      'message', 'ยังไม่มีช่วงที่มีทั้งข้อมูลอากาศและอุบัติเหตุ กดดึงข้อมูลอากาศก่อน');
  end if;

  -- ผู้ใช้ระบุช่วงเองได้ แต่จะไม่เกินช่วงที่ข้อมูลมีจริง
  v_from := greatest(coalesce(p_from::timestamptz, w.w_from), w.w_from);
  v_to   := least(coalesce((p_to + 1)::timestamptz, w.w_to), w.w_to);

  with
  acc as (
    select date_trunc('hour', timezone('Asia/Bangkok', a.incident_datetime))
             at time zone 'Asia/Bangkok' as hour,
           (select z.code from wx_zones z where z.enabled
              order by (z.latitude - a.latitude)^2 + (z.longitude - a.longitude)^2 limit 1) as zone_code
      from accidents a
     where a.latitude is not null and a.longitude is not null
       and a.latitude between 14 and 17 and a.longitude between 99 and 101
       and a.incident_datetime >= v_from and a.incident_datetime < v_to
  ),
  hrs as (
    select h.zone_code, h.hour, coalesce(h.precip_mm, 0) >= p_wet_mm as wet
      from wx_hourly h where h.hour >= v_from and h.hour < v_to
  ),
  joined as (
    select h.zone_code, h.wet, count(a.hour) as n_acc
      from hrs h left join acc a on a.zone_code = h.zone_code and a.hour = h.hour
     group by h.zone_code, h.hour, h.wet
  ),
  per_zone as (
    select j.zone_code,
           count(*) filter (where j.wet)                      as wet_hours,
           count(*) filter (where not j.wet)                  as dry_hours,
           coalesce(sum(j.n_acc) filter (where j.wet), 0)     as wet_acc,
           coalesce(sum(j.n_acc) filter (where not j.wet), 0) as dry_acc
      from joined j group by j.zone_code
  )
  select jsonb_build_object(
    'success', true,
    'from', v_from, 'to', v_to, 'wet_mm', round(p_wet_mm::numeric, 2),
    'acc_from', w.acc_from, 'acc_to', w.acc_to,
    'zones', coalesce(jsonb_agg(jsonb_build_object(
        'zone_code', p.zone_code,
        'name', (select name from wx_zones where code = p.zone_code),
        'wet_hours', p.wet_hours, 'dry_hours', p.dry_hours,
        'wet_acc', p.wet_acc, 'dry_acc', p.dry_acc,
        'wet_rate', case when p.wet_hours > 0 then round((p.wet_acc::numeric / p.wet_hours) * 1000, 2) end,
        'dry_rate', case when p.dry_hours > 0 then round((p.dry_acc::numeric / p.dry_hours) * 1000, 2) end,
        'ratio', case when p.dry_hours > 0 and p.wet_hours > 0 and p.dry_acc > 0
                      then round(((p.wet_acc::numeric / p.wet_hours) / (p.dry_acc::numeric / p.dry_hours)), 2) end
      ) order by p.zone_code), '[]'::jsonb),
    'total', (select jsonb_build_object(
        'wet_hours', sum(wet_hours), 'dry_hours', sum(dry_hours),
        'wet_acc', sum(wet_acc), 'dry_acc', sum(dry_acc),
        'wet_rate', case when sum(wet_hours) > 0 then round((sum(wet_acc)::numeric / sum(wet_hours)) * 1000, 2) end,
        'dry_rate', case when sum(dry_hours) > 0 then round((sum(dry_acc)::numeric / sum(dry_hours)) * 1000, 2) end,
        'ratio', case when sum(dry_hours) > 0 and sum(wet_hours) > 0 and sum(dry_acc) > 0
                      then round(((sum(wet_acc)::numeric / sum(wet_hours)) / (sum(dry_acc)::numeric / sum(dry_hours))), 2) end
      ) from per_zone)
  ) into v_out from per_zone p;

  return v_out;
end $wx_stats$;

grant execute on function wx_stats(text, date, date, real) to anon, authenticated;

-- ============================================================
-- 2) ฝนแรก — ตัดช่วงแล้ว
-- ============================================================
-- ตัดช่วง "หลัง" จำแนกสถานะถนนแล้ว ไม่ใช่ก่อน
-- เพราะการรู้ว่าชั่วโมงหนึ่งเป็นฝนแรกหรือไม่ ต้องดูชั่วโมงก่อนหน้าย้อนไปหลายวัน
-- ถ้าตัดข้อมูลก่อนจำแนก ฝนที่ตกต้นช่วงจะถูกนับเป็นฝนแรกทั้งหมดโดยผิด
create or replace function wx_first_rain(p_token text, p_wet_mm real default 0.2,
  p_gap_hours int default 24, p_first_hrs int default 2)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $wx_first_rain$
declare v_err jsonb; v_out jsonb; w record;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;

  select * into w from wx_window();
  if w.w_from is null or w.w_to is null or w.w_to <= w.w_from then
    return jsonb_build_object('success', false,
      'message', 'ยังไม่มีช่วงที่มีทั้งข้อมูลอากาศและอุบัติเหตุ กดดึงข้อมูลอากาศก่อน');
  end if;

  with
  wx as (select zone_code, hour, coalesce(precip_mm, 0) >= p_wet_mm as wet from wx_hourly),
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
     where p.hour >= w.w_from and p.hour < w.w_to    -- ตัดช่วงตรงนี้ หลังจำแนกเสร็จ
  ),
  acc as (
    select date_trunc('hour', timezone('Asia/Bangkok', a.incident_datetime))
             at time zone 'Asia/Bangkok' as hour,
           (select z.code from wx_zones z where z.enabled
              order by (z.latitude - a.latitude)^2 + (z.longitude - a.longitude)^2 limit 1) as zone_code
      from accidents a
     where a.latitude is not null and a.longitude is not null
       and a.latitude between 14 and 17 and a.longitude between 99 and 101
       and a.incident_datetime >= w.w_from and a.incident_datetime < w.w_to
  ),
  joined as (
    select c.state, count(a.hour) as n_acc
      from classed c left join acc a on a.zone_code = c.zone_code and a.hour = c.hour
     group by c.zone_code, c.hour, c.state
  ),
  agg as (
    select state, count(*)::int as hours, coalesce(sum(n_acc), 0)::int as acc
      from joined group by state
  )
  select jsonb_build_object(
    'success', true,
    'wet_mm', round(p_wet_mm::numeric, 2),
    'gap_hours', p_gap_hours, 'first_hrs', p_first_hrs,
    'from', w.w_from, 'to', w.w_to,
    'rows', coalesce(jsonb_agg(jsonb_build_object(
        'state', a.state, 'hours', a.hours, 'acc', a.acc,
        'rate', case when a.hours > 0 then round((a.acc::numeric / a.hours) * 1000, 2) end
      ) order by a.state), '[]'::jsonb)
  ) into v_out from agg a;

  return v_out;
end $wx_first_rain$;

grant execute on function wx_first_rain(text, real, int, int) to anon, authenticated;

-- ============================================================
-- ตรวจผลหลังรัน
-- ============================================================
-- ช่วงที่ระบบจะใช้จริง ควรเริ่มที่วันแรกของข้อมูลอุบัติเหตุ ไม่ใช่วันแรกของข้อมูลอากาศ
--   select * from wx_window();
--
-- อัตราต้องกลับไปใกล้ค่ารอบแรก (ราว 13 ครั้งต่อพันชั่วโมงตอนแห้ง)
-- ไม่ใช่ 3.92 ที่ถูกเจือจางจากการดึงอากาศเกินช่วงมา
