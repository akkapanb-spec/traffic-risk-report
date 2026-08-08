-- ============================================================
-- ปริมาณจราจร (AADT) และอัตราอุบัติเหตุต่อปริมาณจราจร
-- ============================================================
-- ต้องรัน roadnet_1_tables.sql / roadnet_2_rpc.sql และ officer.sql มาก่อน
-- และต้องมี admin_check_ จาก deaths_admin.sql
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
--
-- ปัญหาที่ไฟล์นี้แก้
--   แผนที่ความหนาแน่นบอกได้แค่ว่าตรงไหน "เกิดเยอะ" ไม่ได้บอกว่าตรงไหน "อันตราย"
--   ถนนที่รถผ่านวันละ 50,000 คัน กับซอยที่รถผ่านวันละ 500 คัน ถ้าเกิดเท่ากัน
--   แปลว่าซอยนั้นอันตรายกว่าร้อยเท่า แต่บนแผนที่ตอนนี้ดูเหมือนกันเป๊ะ
--
--   มาตรฐานที่วิศวกรจราจรใช้คือ อัตราต่อ 100 ล้านคัน-กิโลเมตร
--     ปริมาณการสัญจร (คัน-กม.) = AADT × ความยาวถนน(กม.) × จำนวนวัน
--     อัตรา = จำนวนอุบัติเหตุ ÷ ปริมาณการสัญจร × 100,000,000
--
-- ⚠️ อุปสรรคที่เจอจากข้อมูลจริง ต้องแก้ก่อนถึงจะคำนวณได้
--   ช่อง road ในตาราง accidents เป็นข้อความอิสระ พบ 250 ชื่อจาก 1,044 เคส
--   ถนนสายเดียวกันเขียนหลายแบบ เช่น
--     พหลโยธิน 175 · ถนนพหลโยธิน 18 · ถนนพหลโยธินหมายเลข 1 10
--     สวรรค์วิถี 114 · ถนนสวรรค์วิถี 27 · สวรรค์วิธี 11 (สะกดผิด)
--   ถ้าจับคู่ด้วยชื่อตรง ๆ อุบัติเหตุเกินครึ่งจะหลุดออกจากตัวเศษ
--   แล้วอัตราที่ได้จะต่ำกว่าความจริงโดยไม่มีอะไรฟ้อง
--
--   จึงทำตัวจับคู่ชื่อถนนแบบเดียวกับที่ทำกับชื่อตำบล (geo_aliases)
-- ============================================================

set search_path = public, extensions;

-- ============================================================
-- 1) ล้างชื่อถนนก่อนเทียบ
-- ============================================================
-- ตัดคำนำหน้าและช่องว่างซ้ำ "ถนนพหลโยธิน" " พหลโยธิน " ต้องได้ค่าเดียวกัน
-- ตัดคำต่อท้ายอย่าง "หมายเลข 1" ออกด้วย เพราะเป็นคำอธิบาย ไม่ใช่ชื่อ
create or replace function rn_road_norm(p_name text)
returns text language sql immutable as $$
  select nullif(btrim(regexp_replace(
    regexp_replace(
      regexp_replace(coalesce(p_name,''), '^\s*(ถนน|ถ\.|ซอย|ซ\.|ทางหลวงหมายเลข|ทางหลวงชนบท|ทล\.|ทช\.)\s*', '', 'i'),
      '\s*(หมายเลข|เลขที่)\s*[0-9]+\s*$', '', 'i'),
    '\s+', ' ', 'g')), '');
$$;

-- ============================================================
-- 2) ชื่อพ้องของถนน
-- ============================================================
create table if not exists rn_road_aliases (
  alias   text primary key,
  road_id bigint not null references rn_roads(id) on delete cascade,
  note    text
);
alter table rn_road_aliases enable row level security;
-- ไม่สร้าง policy = anon อ่านตรงไม่ได้ เข้าผ่าน RPC เท่านั้น

-- ============================================================
-- 3) หา road_id จากชื่อที่เขียนไว้ในเคส
-- ============================================================
-- ไล่จากแม่นไปหยาบ: ชื่อพ้องที่ผูกไว้เอง → รหัสทางหลวง → ชื่อที่ล้างแล้ว
-- เจอมากกว่าหนึ่งสายคืน null ดีกว่าเดาผิดแล้วเอาไปหารจนอัตราเพี้ยน
create or replace function rn_resolve_road(p_name text)
returns bigint
language plpgsql stable set search_path = public, extensions as $$
declare v_n text := rn_road_norm(p_name); v_id bigint; v_c int;
begin
  if v_n is null then return null; end if;

  select road_id into v_id from rn_road_aliases where alias = v_n;
  if v_id is not null then return v_id; end if;

  select count(*), min(id) into v_c, v_id from rn_roads
   where rn_road_norm(code) = v_n;
  if v_c = 1 then return v_id; end if;

  select count(*), min(id) into v_c, v_id from rn_roads
   where rn_road_norm(name) = v_n;
  if v_c = 1 then return v_id; end if;

  return null;
end $$;

-- ============================================================
-- 4) ปริมาณจราจร
-- ============================================================
-- เก็บรายปีรายถนน ช่วง กม. ใส่ไว้เผื่อกรณีถนนสายยาวที่ปริมาณต่างกันมากตามช่วง
-- ตอนคำนวณอัตรารวมทั้งสาย จะใช้ค่าเฉลี่ยถ่วงน้ำหนักตามความยาวช่วง
create table if not exists rn_traffic_volume (
  id       bigserial primary key,
  road_id  bigint not null references rn_roads(id) on delete cascade,
  year     int    not null,                  -- พ.ศ. ของรายงาน
  aadt     int    not null check (aadt >= 0),-- ปริมาณจราจรเฉลี่ยต่อวัน (คัน/วัน)
  km_from  numeric(8,3),
  km_to    numeric(8,3),
  source   text,                             -- อ้างอิงรายงานฉบับไหน
  note     text,
  updated_at timestamptz not null default now(),
  unique (road_id, year, km_from, km_to)
);
create index if not exists rn_tv_road_year_idx on rn_traffic_volume (road_id, year desc);

alter table rn_traffic_volume enable row level security;
-- ไม่สร้าง policy = anon อ่านตรงไม่ได้

-- ============================================================
-- 5) หน้าจัดการ: ถนน + ปริมาณจราจร + ชื่อถนนที่จับคู่ไม่ได้
-- ============================================================
create or replace function tv_admin_data(p_token text, p_year int default null)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare v_err jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;

  return jsonb_build_object('success', true,
    'roads', coalesce((select jsonb_agg(jsonb_build_object(
        'id', r.id, 'name', r.name, 'code', r.code, 'length_km', r.length_km) order by r.name)
      from rn_roads r), '[]'::jsonb),

    'volumes', coalesce((select jsonb_agg(jsonb_build_object(
        'id', v.id, 'road_id', v.road_id, 'road_name', r.name, 'road_code', r.code,
        'year', v.year, 'aadt', v.aadt, 'km_from', v.km_from, 'km_to', v.km_to,
        'source', v.source, 'note', v.note) order by v.year desc, r.name)
      from rn_traffic_volume v join rn_roads r on r.id = v.road_id
      where p_year is null or v.year = p_year), '[]'::jsonb),

    -- ชื่อถนนที่ใช้จริงในเคส พร้อมผลจับคู่ ตัวที่จับไม่ได้คือตัวที่จะหลุดจากการคำนวณ
    'road_names', coalesce((select jsonb_agg(jsonb_build_object(
        'name', t.v, 'rows', t.c, 'road_id', rn_resolve_road(t.v))
        order by rn_resolve_road(t.v) nulls first, t.c desc)
      from (select nullif(btrim(a.road),'') v, count(*) c
            from accidents a where nullif(btrim(a.road),'') is not null
            group by 1) t), '[]'::jsonb),

    'aliases', coalesce((select jsonb_agg(jsonb_build_object(
        'alias', al.alias, 'road_id', al.road_id, 'road_name', r.name) order by al.alias)
      from rn_road_aliases al join rn_roads r on r.id = al.road_id), '[]'::jsonb));
end $$;

create or replace function tv_save(p_token text, p_id bigint, p_row jsonb)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare v_err jsonb; v_id bigint;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;

  if nullif(p_row->>'road_id','') is null then
    return jsonb_build_object('success', false, 'message', 'ยังไม่ได้เลือกถนน');
  end if;
  if nullif(p_row->>'aadt','') is null then
    return jsonb_build_object('success', false, 'message', 'ยังไม่ได้ใส่ปริมาณจราจร');
  end if;

  insert into rn_traffic_volume (road_id, year, aadt, km_from, km_to, source, note)
  values ((p_row->>'road_id')::bigint,
          coalesce(nullif(p_row->>'year','')::int, extract(year from now())::int + 543),
          (p_row->>'aadt')::int,
          nullif(p_row->>'km_from','')::numeric, nullif(p_row->>'km_to','')::numeric,
          nullif(p_row->>'source',''), nullif(p_row->>'note',''))
  on conflict (road_id, year, km_from, km_to) do update set
    aadt = excluded.aadt, source = excluded.source, note = excluded.note, updated_at = now()
  returning id into v_id;

  return jsonb_build_object('success', true, 'message', 'บันทึกแล้ว', 'id', v_id);
end $$;

create or replace function tv_delete(p_token text, p_id bigint)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare v_err jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  -- ต้องมี where เสมอ Supabase เปิด sql_safe_updates ไว้
  delete from rn_traffic_volume where id = p_id;
  return jsonb_build_object('success', true, 'message', 'ลบแล้ว');
end $$;

create or replace function tv_alias_save(p_token text, p_alias text, p_road_id bigint)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare v_err jsonb; v_a text;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;

  -- เก็บชื่อที่ล้างแล้ว เพราะ rn_resolve_road ล้างก่อนค้นเสมอ
  -- ถ้าเก็บ "ถนนพหลโยธิน" ดิบ ๆ จะค้นไม่เจอตลอดกาล
  v_a := rn_road_norm(p_alias);
  if v_a is null then return jsonb_build_object('success', false, 'message', 'ยังไม่ได้ใส่ชื่อ'); end if;
  if not exists (select 1 from rn_roads where id = p_road_id) then
    return jsonb_build_object('success', false, 'message', 'ไม่พบถนนสายนี้');
  end if;

  insert into rn_road_aliases (alias, road_id, note)
  values (v_a, p_road_id, 'ผูกจากหน้าปริมาณจราจร')
  on conflict (alias) do update set road_id = excluded.road_id;

  return jsonb_build_object('success', true, 'message', 'ผูก ' || v_a || ' เรียบร้อย');
end $$;

create or replace function tv_alias_delete(p_token text, p_alias text)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare v_err jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  delete from rn_road_aliases where alias = rn_road_norm(p_alias);
  return jsonb_build_object('success', true, 'message', 'ลบแล้ว');
end $$;

-- ============================================================
-- 6) อัตราอุบัติเหตุต่อปริมาณจราจร รายถนน — หัวใจของเรื่องนี้
-- ============================================================
-- คืนทุกถนนที่มีอุบัติเหตุ ถนนที่ยังไม่มี AADT จะได้ rate เป็น null
-- ไม่เดาค่าให้ เพราะเดาแล้วจะกลายเป็นตัวเลขที่เอาไปอ้างอิงไม่ได้
create or replace function tv_road_rates(p_token text, p_from date default null, p_to date default null)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_user jsonb; v_from date; v_to date; v_days int; v_unmatched int; v_total int;
begin
  v_user := officer_session_user(p_token);
  if v_user is null then
    return jsonb_build_object('success', false, 'code', 'AUTH_REQUIRED', 'message', 'กรุณาเข้าสู่ระบบใหม่');
  end if;

  v_to   := coalesce(p_to, current_date);
  v_from := coalesce(p_from, v_to - 365);
  v_days := greatest(1, (v_to - v_from));

  select count(*) into v_total from accidents a
   where a.incident_datetime >= v_from and a.incident_datetime < (v_to + 1);

  select count(*) into v_unmatched from accidents a
   where a.incident_datetime >= v_from and a.incident_datetime < (v_to + 1)
     and rn_resolve_road(a.road) is null;

  return jsonb_build_object(
    'success', true,
    'period_start', v_from, 'period_end', v_to, 'days', v_days,
    'total', v_total,
    'unmatched', v_unmatched,   -- เคสที่ชื่อถนนจับคู่ไม่ได้ ไม่ได้เข้าตารางนี้
    'rows', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.rate desc nulls last, x.accidents desc) from (
        select r.id as road_id, r.name as road_name, r.code as road_code,
               r.length_km,
               cnt.accidents,
               av.aadt,
               case when av.aadt is null or coalesce(r.length_km,0) = 0 then null
                    else round(cnt.accidents::numeric * 100000000
                         / (av.aadt::numeric * r.length_km * v_days), 2)
               end as rate
        from rn_roads r
        join lateral (
          select count(*)::int accidents
          from accidents a
          where a.incident_datetime >= v_from and a.incident_datetime < (v_to + 1)
            and rn_resolve_road(a.road) = r.id
        ) cnt on true
        -- ใช้ปีล่าสุดที่มีข้อมูล และถ่วงน้ำหนักตามความยาวช่วงถ้ากรอกแยกช่วงไว้
        left join lateral (
          select round(sum(v.aadt::numeric * coalesce(nullif(v.km_to - v.km_from, 0), 1))
                     / sum(coalesce(nullif(v.km_to - v.km_from, 0), 1)))::int as aadt
          from rn_traffic_volume v
          where v.road_id = r.id
            and v.year = (select max(v2.year) from rn_traffic_volume v2 where v2.road_id = r.id)
        ) av on true
        where cnt.accidents > 0
      ) x), '[]'::jsonb));
end $$;

grant execute on function rn_road_norm(text)                     to anon, authenticated;
grant execute on function rn_resolve_road(text)                  to anon, authenticated;
grant execute on function tv_admin_data(text, int)               to anon, authenticated;
grant execute on function tv_save(text, bigint, jsonb)           to anon, authenticated;
grant execute on function tv_delete(text, bigint)                to anon, authenticated;
grant execute on function tv_alias_save(text, text, bigint)      to anon, authenticated;
grant execute on function tv_alias_delete(text, text)            to anon, authenticated;
grant execute on function tv_road_rates(text, date, date)        to anon, authenticated;

-- ============================================================
-- ตรวจผลหลังรัน
-- ============================================================
-- select rn_road_norm('ถนนพหลโยธินหมายเลข 1') as ควรได้_พหลโยธิน;
-- select jsonb_pretty(tv_road_rates('ใส่ token', null, null));
