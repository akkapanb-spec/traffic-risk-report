-- ============================================================
-- แก้ 2 จุดที่เจอหลังรันจริง
-- ============================================================
-- ต้องรัน traffic_1_volume.sql มาก่อน
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
--
-- 1) rn_road_norm ไม่ตัดคำนำหน้าเลย  ตรวจแล้วพบว่า regexp_replace ในฟังก์ชันนั้น
--    ไม่ทำงานสักชั้น แม้แต่ชั้นที่ยุบช่องว่างซ้ำ  "ถนนโกสีย์" ยังได้ "ถนนโกสีย์"
--    ผลคือชื่อในเคส "โกสีย์" ไม่มีวันตรงกับชื่อในโครงข่าย "ถนนโกสีย์"
--    จับคู่ได้แค่ 7 ชื่อ 73 เคส จาก 249 ชื่อ 1,040 เคส
--    เขียนใหม่ด้วยฟังก์ชันข้อความธรรมดา ไม่พึ่ง regex จะได้ไม่ต้องเดาว่าเอนจินทำอะไร
--
-- 2) tv_road_rates หมดเวลา (statement timeout)
--    ของเดิมเรียก rn_resolve_road ทีละแถวอุบัติเหตุ คูณจำนวนถนน
--    = 17 สาย x 1,044 เคส ราวหมื่นแปดพันครั้ง แต่ละครั้งยิงหลาย query
--    แก้ให้แปลงชื่อที่ไม่ซ้ำกันครั้งเดียว 249 ชื่อ แล้วค่อยเอาไปรวมยอด
-- ============================================================

set search_path = public, extensions;

-- ============================================================
-- 1) ล้างชื่อถนน แบบไม่ใช้ regex
-- ============================================================
create or replace function rn_road_norm(p_name text)
returns text
language plpgsql immutable as $$
declare
  v text := btrim(coalesce(p_name, ''));
  p text;
  -- เรียงจากยาวไปสั้น เพื่อให้ "ทางหลวงหมายเลข" ถูกตัดก่อน "ทล."
  prefixes text[] := array['ทางหลวงหมายเลข','ทางหลวงชนบท','ถนน','ซอย','ทล.','ทช.','ถ.','ซ.'];
  pos int;
  tail text;
begin
  if v = '' then return null; end if;

  foreach p in array prefixes loop
    if left(v, length(p)) = p then
      v := btrim(substr(v, length(p) + 1));
      exit;                                  -- ตัดคำนำหน้าอันเดียวพอ
    end if;
  end loop;

  -- ตัด "หมายเลข 1" ที่ต่อท้ายชื่อ เพราะเป็นคำอธิบาย ไม่ใช่ชื่อถนน
  -- ตัดเฉพาะเมื่อหลังคำนั้นเป็นตัวเลขล้วน จะได้ไม่ไปตัดชื่อที่บังเอิญมีคำนี้อยู่กลาง
  pos := strpos(v, 'หมายเลข');
  if pos > 0 then
    tail := btrim(substr(v, pos + length('หมายเลข')));
    -- เช็คว่าเป็นตัวเลขล้วนโดยไม่ใช้ regex เลย ตัดตัวเลขออกหมดแล้วต้องไม่เหลืออะไร
    if tail <> '' and ltrim(tail, '0123456789') = '' then
      v := btrim(left(v, pos - 1));
    end if;
  end if;

  -- ยุบช่องว่างซ้ำ วนจนไม่เหลือคู่ ไม่ต้องใช้ regex
  while strpos(v, '  ') > 0 loop
    v := replace(v, '  ', ' ');
  end loop;

  return nullif(btrim(v), '');
end $$;

-- ============================================================
-- 2) อัตราอุบัติเหตุต่อปริมาณจราจร - แปลงชื่อครั้งเดียวต่อชื่อ
-- ============================================================
create or replace function tv_road_rates(p_token text, p_from date default null, p_to date default null)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_user jsonb; v_from date; v_to date; v_days int;
  v_total int; v_unmatched int; v_rows jsonb;
begin
  v_user := officer_session_user(p_token);
  if v_user is null then
    return jsonb_build_object('success', false, 'code', 'AUTH_REQUIRED', 'message', 'กรุณาเข้าสู่ระบบใหม่');
  end if;

  v_to   := coalesce(p_to, current_date);
  v_from := coalesce(p_from, v_to - 365);
  v_days := greatest(1, (v_to - v_from));

  -- ชื่อถนนที่ไม่ซ้ำกันในช่วงนี้ แปลงเป็น road_id ชื่อละครั้งเดียว
  create temporary table if not exists tmp_tv_map (nm text, c int, rid bigint) on commit drop;
  truncate tmp_tv_map;

  insert into tmp_tv_map (nm, c, rid)
  select t.nm, t.c, rn_resolve_road(t.nm)
  from (select nullif(btrim(a.road), '') nm, count(*)::int c
        from accidents a
        where a.incident_datetime >= v_from and a.incident_datetime < (v_to + 1)
        group by 1) t;

  select coalesce(sum(c), 0) into v_total     from tmp_tv_map;
  select coalesce(sum(c), 0) into v_unmatched from tmp_tv_map where rid is null;

  select coalesce(jsonb_agg(to_jsonb(x) order by x.rate desc nulls last, x.accidents desc), '[]'::jsonb)
    into v_rows
  from (
    select r.id as road_id, r.name as road_name, r.code as road_code, r.length_km,
           m.accidents, av.aadt,
           case when av.aadt is null or coalesce(r.length_km, 0) = 0 then null
                else round(m.accidents::numeric * 100000000
                     / (av.aadt::numeric * r.length_km * v_days), 2)
           end as rate
    from (select rid, sum(c)::int accidents from tmp_tv_map where rid is not null group by rid) m
    join rn_roads r on r.id = m.rid
    left join lateral (
      select round(sum(v.aadt::numeric * coalesce(nullif(v.km_to - v.km_from, 0), 1))
                 / sum(coalesce(nullif(v.km_to - v.km_from, 0), 1)))::int as aadt
      from rn_traffic_volume v
      where v.road_id = r.id
        and v.year = (select max(v2.year) from rn_traffic_volume v2 where v2.road_id = r.id)
    ) av on true
  ) x;

  return jsonb_build_object(
    'success', true,
    'period_start', v_from, 'period_end', v_to, 'days', v_days,
    'total', v_total, 'unmatched', v_unmatched,
    'rows', v_rows);
end $$;

grant execute on function rn_road_norm(text)              to anon, authenticated;
grant execute on function tv_road_rates(text, date, date) to anon, authenticated;

-- ============================================================
-- ตรวจผลหลังรัน
-- ============================================================
-- select rn_road_norm('ถนนโกสีย์')            as ควรได้_โกสีย์;
-- select rn_road_norm('ถนนพหลโยธินหมายเลข 1') as ควรได้_พหลโยธิน;
-- select rn_road_norm('ซอยปาริชาติ')          as ควรได้_ปาริชาติ;
-- select rn_resolve_road('โกสีย์')            as ควรได้เลขถนน_ไม่ใช่_null;
