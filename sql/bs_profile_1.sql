-- ============================================================
-- โปรไฟล์จุดเสี่ยง — เกิดเมื่อไหร่ และสภาพถนนแบบไหน
-- ============================================================
-- ต้องรัน blackspot_1..4, weather_1_tables.sql และ weather_2_firstrain.sql มาก่อน
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
--
-- ทำไมต้องมี
--   ตอนนี้จุดเสี่ยงบอกได้แค่ "ตรงไหน" กับ "กี่ครั้ง"
--   ซึ่งไม่พอจะตัดสินใจว่าควรใช้มาตรการอะไร
--
--   จุดที่เกิดกระจุกช่วง 16-19 น. ทุกวัน ต้องจัดกำลังชั่วโมงนั้น
--   จุดที่เกิดตอนกลางคืนพร้อมเมาแล้วขับ ต้องตั้งด่าน
--   จุดที่เกิดตอนฝนแรก ต้องแก้ผิวทางหรือติดป้าย
--   สามจุดนี้อาจมีจำนวนครั้งเท่ากันเป๊ะ แต่วิธีแก้คนละเรื่องโดยสิ้นเชิง
--
-- สิ่งที่ตั้งใจ "ไม่" ทำ
--   ไม่รวมทุกมิติเป็นคะแนนเดียว เพราะได้เลขที่อธิบายไม่ได้ว่าแปลว่าอะไร
--   และการเอาจำนวนอุบัติเหตุไปบวกกับปริมาณจราจรคือการนับการเปิดรับสองรอบ
--   คืนเป็นตัวเลขดิบแยกมิติ แล้วให้หน้าเว็บเป็นคนตีความ
--
-- ข้อจำกัดที่ต้องรู้
--   จุดเสี่ยงหนึ่งจุดมักมีอุบัติเหตุหลักหน่วย ซึ่งน้อยเกินกว่าจะสรุปรูปแบบ
--   ฟังก์ชันนี้จึงคืนจำนวนที่ใช้คำนวณมาด้วยเสมอ (n)
--   หน้าเว็บต้องปฏิเสธที่จะสรุปเมื่อ n น้อย ไม่ใช่แปะป้ายมั่ว ๆ
-- ============================================================

set search_path = public, extensions;

create or replace function bs_site_profile(p_token text, p_wet_mm real default 0.2,
  p_gap_hours int default 24, p_first_hrs int default 2)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $bs_site_profile$
declare v_err jsonb; v_out jsonb; v_has_wx boolean;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;

  select exists (select 1 from wx_hourly) into v_has_wx;

  with
  -- จำแนกสถานะถนนทุกชั่วโมง ใช้ตรรกะเดียวกับ wx_first_rain
  -- ทำซ้ำที่นี่แทนที่จะเรียกฟังก์ชันนั้น เพราะต้องได้ผลรายชั่วโมง ไม่ใช่ยอดรวม
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
  hour_state as (
    select p.zone_code, p.hour,
           case when not p.wet then 'dry'
                when exists (select 1 from first_runs f where f.zone_code = p.zone_code and f.grp = p.grp)
                     and p.pos_in_run <= p_first_hrs then 'first'
                else 'rain' end as state
      from pos p
  ),
  -- อุบัติเหตุพร้อมชั่วโมงและโซนที่ใกล้ที่สุด
  acc as (
    select a.id, a.latitude, a.longitude, a.incident_datetime,
           extract(hour from timezone('Asia/Bangkok', a.incident_datetime))::int as hr,
           date_trunc('hour', timezone('Asia/Bangkok', a.incident_datetime))
             at time zone 'Asia/Bangkok' as hour_key,
           (select z.code from wx_zones z where z.enabled
              order by (z.latitude - a.latitude)^2 + (z.longitude - a.longitude)^2 limit 1) as zone_code
      from accidents a
     where a.latitude is not null and a.longitude is not null
       and a.latitude between 14 and 17 and a.longitude between 99 and 101
  ),
  -- จับอุบัติเหตุเข้าจุดเสี่ยงที่อยู่ในรัศมีของจุดนั้น
  -- หนึ่งเหตุอาจตกในรัศมีหลายจุดได้ ซึ่งถูกต้อง เพราะจุดเสี่ยงซ้อนทับกันได้จริง
  pair as (
    select s.id as site_id, a.hr,
           coalesce(h.state, 'unknown') as state
      from bs_sites s
      join acc a
        on st_dwithin(
             st_setsrid(st_makepoint(s.longitude, s.latitude), 4326)::geography,
             st_setsrid(st_makepoint(a.longitude, a.latitude), 4326)::geography,
             greatest(coalesce(s.radius_m, 200), 50))
      left join hour_state h on h.zone_code = a.zone_code and h.hour = a.hour_key
     where s.published
  ),
  per_site as (
    select p.site_id,
           count(*)::int as n,
           -- ฮิสโทแกรม 24 ชั่วโมง ให้หน้าเว็บหาช่วงที่กระจุกเอง
           (select jsonb_agg(coalesce(c.cnt, 0) order by g.h)
              from generate_series(0, 23) g(h)
              left join (select hr, count(*)::int cnt from pair p2
                          where p2.site_id = p.site_id group by hr) c on c.hr = g.h) as hours,
           count(*) filter (where p.state = 'dry')::int     as dry_n,
           count(*) filter (where p.state = 'rain')::int    as rain_n,
           count(*) filter (where p.state = 'first')::int   as first_n,
           count(*) filter (where p.state = 'unknown')::int as unknown_n
      from pair p group by p.site_id
  ),
  -- ฐานเปรียบเทียบ: ทั้งพื้นที่มีชั่วโมงแต่ละสถานะกี่ % ของเวลาทั้งหมด
  -- ถ้าไม่มีตัวนี้ จะตีความสัดส่วนฝนผิดแบบเดียวกับที่คุยกันไว้
  base as (
    select
      count(*) filter (where state = 'dry')::numeric   / nullif(count(*),0) as dry_share,
      count(*) filter (where state = 'rain')::numeric  / nullif(count(*),0) as rain_share,
      count(*) filter (where state = 'first')::numeric / nullif(count(*),0) as first_share
    from hour_state
  )
  select jsonb_build_object(
    'success', true,
    'has_weather', v_has_wx,
    'wet_mm', p_wet_mm, 'gap_hours', p_gap_hours, 'first_hrs', p_first_hrs,
    'baseline', (select jsonb_build_object(
        'dry', round(coalesce(dry_share,0), 4),
        'rain', round(coalesce(rain_share,0), 4),
        'first', round(coalesce(first_share,0), 4)) from base),
    'sites', coalesce((select jsonb_agg(jsonb_build_object(
        'id', s.id, 'title', s.title, 'road', s.road_name,
        'latitude', s.latitude, 'longitude', s.longitude,
        'radius_m', s.radius_m, 'level', s.level, 'rule', s.rule,
        'acc_count', s.acc_count, 'fatal_count', s.fatal_count,
        'n', coalesce(ps.n, 0),
        'hours', coalesce(ps.hours, '[]'::jsonb),
        'weather', jsonb_build_object(
          'dry', coalesce(ps.dry_n, 0), 'rain', coalesce(ps.rain_n, 0),
          'first', coalesce(ps.first_n, 0), 'unknown', coalesce(ps.unknown_n, 0))
      ) order by coalesce(ps.n, 0) desc, s.id)
      from bs_sites s left join per_site ps on ps.site_id = s.id
      where s.published), '[]'::jsonb)
  ) into v_out;

  return v_out;
end $bs_site_profile$;

grant execute on function bs_site_profile(text, real, int, int) to anon, authenticated;

-- ============================================================
-- ตรวจผลหลังรัน
-- ============================================================
-- ต้องได้จุดเสี่ยงที่เผยแพร่แล้วทุกจุด พร้อม n และฮิสโทแกรม 24 ช่อง
--   select jsonb_pretty(bs_site_profile('<token แอดมิน>'));
--
-- baseline คือสัดส่วนเวลาของทั้งพื้นที่ ใช้เทียบกับสัดส่วนของแต่ละจุด
-- ถ้าจุดหนึ่งมีอุบัติเหตุตอนฝนแรก 30% แต่ baseline ฝนแรกมีแค่ 2% ของเวลา
-- แปลว่าจุดนั้นสัมพันธ์กับฝนแรกจริง ไม่ใช่บังเอิญ
--
-- has_weather เป็น false แปลว่ายังไม่ได้ดึงข้อมูลสภาพอากาศ
-- ส่วนของเวลายังใช้ได้ ส่วนของฝนจะเป็น unknown ทั้งหมด
