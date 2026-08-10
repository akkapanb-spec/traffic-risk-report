-- ============================================================
-- LINE Bot — ตัวสร้างข้อความ
-- ============================================================
-- ไฟล์ที่ 2 จาก 3  ต้องรัน line_1_tables.sql มาก่อน
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
--
-- ไฟล์นี้ยังไม่ส่งอะไรออก LINE เช่นกัน สร้างแต่ข้อความเป็นข้อความเปล่า ๆ
-- จะได้ตรวจเนื้อหาให้ถูกก่อน แล้วค่อยต่อท่อส่งในไฟล์ที่ 3
--
-- ทำไมสร้างข้อความใน SQL ไม่ใช่ใน Edge Function
--   ข้อความทุกบรรทัดคือคำถามกับฐานข้อมูล ซึ่งเป็นสิ่งที่ SQL ทำได้ตรงที่สุด
--   และเรียกตรวจผลได้ทันทีด้วย select โดยไม่ต้อง deploy อะไร
--   Edge Function จึงเหลือหน้าที่แค่รับ-ส่ง ไม่ต้องรู้เรื่องข้อมูลเลย
-- ============================================================

set search_path = public, extensions;

-- ============================================================
-- 1) วันที่แบบไทย
-- ============================================================
-- ทุกอย่างในระบบนี้เป็นเวลาไทย และปีที่แสดงต่อคนอ่านเป็น พ.ศ.
create or replace function line_thai_date(p_ts timestamptz, p_with_time boolean default false)
returns text
language plpgsql immutable set search_path = public, extensions as $$
declare
  v timestamp;
  m text[] := array['ม.ค.','ก.พ.','มี.ค.','เม.ย.','พ.ค.','มิ.ย.','ก.ค.','ส.ค.','ก.ย.','ต.ค.','พ.ย.','ธ.ค.'];
begin
  if p_ts is null then return '-'; end if;
  v := timezone('Asia/Bangkok', p_ts);
  return to_char(v, 'FMDD') || ' ' || m[extract(month from v)::int] || ' ' ||
         (extract(year from v)::int + 543)::text ||
         case when p_with_time then ' ' || to_char(v, 'HH24:MI') || ' น.' else '' end;
end $$;

-- วันที่วันนี้ตามเวลาไทย ใช้ซ้ำหลายที่จนควรมีชื่อเรียก
create or replace function line_today()
returns date language sql stable set search_path = public, extensions as $$
  select (timezone('Asia/Bangkok', now()))::date;
$$;

-- ============================================================
-- 2) ผู้เสียชีวิตรายใหม่
-- ============================================================
-- ข้อความนี้จะถูกส่งทันทีที่มีการบันทึกผู้เสียชีวิตเข้าระบบ
-- จึงต้องอ่านจบใน 5 วินาที และบอกสิ่งที่เอาไปสั่งการต่อได้จริง
-- ไม่ใช่ตัวเลขสถิติที่รอดูตอนสรุปรายเดือนก็ได้
create or replace function line_msg_death(p_id bigint)
returns text
language plpgsql stable security definer set search_path = public, extensions as $$
declare
  d record; v_year int; v_year_n int; v_lines text[];
  v_lat text; v_lng text; v_pos int;
begin
  select * into d from deaths where id = p_id;
  if d.id is null then return null; end if;

  v_year   := extract(year from timezone('Asia/Bangkok', d.incident_datetime))::int;
  select count(*) into v_year_n from deaths
   where extract(year from timezone('Asia/Bangkok', incident_datetime))::int = v_year;

  v_lines := array['🚨 ผู้เสียชีวิตจากอุบัติเหตุจราจร'];
  v_lines := v_lines || ('เกิดเหตุ ' || line_thai_date(d.incident_datetime, true));

  if coalesce(btrim(d.road_name), '') <> '' then
    v_lines := v_lines || ('สถานที่ ' || d.road_name ||
      case when coalesce(btrim(d.subdistrict),'') <> '' then ' ต.' || d.subdistrict else '' end);
  elsif coalesce(btrim(d.subdistrict), '') <> '' then
    v_lines := v_lines || ('สถานที่ ต.' || d.subdistrict);
  end if;

  -- อายุ 0 คือยังไม่ได้กรอก ไม่ใช่ทารก ต้องไม่พิมพ์ว่า "อายุ 0 ปี"
  v_lines := v_lines || ('ผู้เสียชีวิต ' || coalesce(nullif(btrim(d.gender), ''), 'ไม่ระบุเพศ') ||
    case when coalesce(d.age, 0) > 0 then ' อายุ ' || d.age || ' ปี' else ' (ไม่ระบุอายุ)' end);

  if coalesce(btrim(d.vehicle_type), '') <> '' then
    v_lines := v_lines || ('ยานพาหนะ ' || d.vehicle_type);
  end if;
  -- สาเหตุว่างบ่อย ไม่มีก็ข้ามบรรทัดไป ดีกว่าพิมพ์ "สาเหตุ -" ให้รก
  if coalesce(btrim(d.cause), '') <> '' then
    v_lines := v_lines || ('สาเหตุ ' || d.cause);
  end if;

  -- พิกัดเก็บเป็นข้อความ "lat, lng" แปลงเป็นลิงก์แผนที่ให้กดได้เลยจากในไลน์
  if coalesce(btrim(d.coordinates), '') <> '' and strpos(d.coordinates, ',') > 0 then
    v_pos := strpos(d.coordinates, ',');
    v_lat := btrim(left(d.coordinates, v_pos - 1));
    v_lng := btrim(substr(d.coordinates, v_pos + 1));
    if v_lat <> '' and v_lng <> '' then
      v_lines := v_lines || ('แผนที่ https://www.google.com/maps?q=' || v_lat || ',' || v_lng);
    end if;
  end if;

  v_lines := v_lines || ('รวมผู้เสียชีวิตปี ' || (v_year + 543)::text || ' : ' || v_year_n || ' ราย');
  return array_to_string(v_lines, E'\n');
end $$;

-- ============================================================
-- 3) สรุปประจำวัน
-- ============================================================
-- p_day คือวันที่ต้องการสรุป ไม่ใช่วันที่ส่ง
-- ตั้งค่าเริ่มต้นเป็นเมื่อวาน เพราะตัวตั้งเวลาจะยิงตอนเช้าเพื่อสรุปของวันก่อนหน้า
create or replace function line_msg_daily(p_day date default null)
returns text
language plpgsql stable security definer set search_path = public, extensions as $$
declare
  v_day date := coalesce(p_day, line_today() - 1);
  v_from timestamptz; v_to timestamptz;
  v_acc int; v_death int; v_death_month int; v_death_year int;
  v_new_risk int; v_open_risk int;
  v_lines text[]; r record; v_n int;
begin
  -- ขอบเขตของวัน คิดตามเวลาไทยเสมอ ไม่ใช่ UTC
  v_from := timezone('Asia/Bangkok', v_day::timestamp);
  v_to   := timezone('Asia/Bangkok', (v_day + 1)::timestamp);

  -- นับอุบัติเหตุจาก view สาธารณะ ไม่แตะตาราง accidents ที่มีข้อมูลบุคคล
  select count(*) into v_acc from accidents_public
   where incident_datetime >= v_from and incident_datetime < v_to;

  select count(*) into v_death from deaths
   where incident_datetime >= v_from and incident_datetime < v_to;

  select count(*) into v_death_month from deaths
   where incident_datetime >= timezone('Asia/Bangkok', date_trunc('month', v_day::timestamp))
     and incident_datetime < v_to;

  select count(*) into v_death_year from deaths
   where incident_datetime >= timezone('Asia/Bangkok', date_trunc('year', v_day::timestamp))
     and incident_datetime < v_to;

  v_lines := array['📋 สรุปสถานการณ์จราจร สภ.เมืองนครสวรรค์',
                   'ข้อมูลวันที่ ' || line_thai_date(v_from), ''];

  v_lines := v_lines || ('• อุบัติเหตุ ' || v_acc || ' ครั้ง');
  v_lines := v_lines || ('• ผู้เสียชีวิต ' || v_death || ' ราย' ||
    ' (เดือนนี้ ' || v_death_month || ' · ปีนี้ ' || v_death_year || ')');

  -- รายชื่อผู้เสียชีวิตของวันนั้น ถ้ามี — ตัวเลขอย่างเดียวไม่พอให้สั่งการ
  if v_death > 0 then
    for r in
      select road_name, subdistrict, cause, incident_datetime from deaths
       where incident_datetime >= v_from and incident_datetime < v_to
       order by incident_datetime
    loop
      v_lines := v_lines || ('   – ' || to_char(timezone('Asia/Bangkok', r.incident_datetime), 'HH24:MI') ||
        ' น. ' || coalesce(nullif(btrim(r.road_name), ''), 'ไม่ระบุถนน') ||
        case when coalesce(btrim(r.subdistrict),'') <> '' then ' ต.' || r.subdistrict else '' end ||
        case when coalesce(btrim(r.cause),'') <> '' then ' · ' || r.cause else '' end);
    end loop;
  end if;

  -- ประกาศจุดเลี่ยงที่ยังมีผล ณ ตอนส่ง
  select count(*) into v_n from traffic_advisories
   where closed_at is null and starts_at <= now() and ends_at >= now();
  if v_n > 0 then
    v_lines := v_lines || array['', '⚠️ ประกาศจุดเลี่ยงที่มีผลอยู่ ' || v_n || ' รายการ'];
    for r in
      select title, place, ends_at from traffic_advisories
       where closed_at is null and starts_at <= now() and ends_at >= now()
       order by ends_at limit 5
    loop
      v_lines := v_lines || ('   – ' || r.title || ' (' || r.place ||
        ') ถึง ' || line_thai_date(r.ends_at, true));
    end loop;
  end if;

  -- จุดเสี่ยงที่ประชาชนแจ้งเข้ามาใหม่ในวันนั้น และที่ยังค้างอยู่ทั้งหมด
  select count(*) into v_new_risk from risk_points
   where registration_date >= v_from and registration_date < v_to;
  select count(*) into v_open_risk from risk_points
   where coalesce(status, '') = 'ยังไม่ได้ดำเนินการ';

  if v_new_risk > 0 or v_open_risk > 0 then
    v_lines := v_lines || array['', '📍 จุดเสี่ยงที่ประชาชนแจ้ง'];
    v_lines := v_lines || ('   แจ้งใหม่ ' || v_new_risk || ' จุด · ยังไม่ได้ดำเนินการ ' || v_open_risk || ' จุด');
    for r in
      select location, road, subdistrict from risk_points
       where registration_date >= v_from and registration_date < v_to
       order by registration_date limit 5
    loop
      v_lines := v_lines || ('   – ' || coalesce(nullif(btrim(r.location), ''), '(ไม่ระบุสถานที่)') ||
        case when coalesce(btrim(r.road),'') <> '' then ' ถ.' || r.road else '' end);
    end loop;
  end if;

  return array_to_string(v_lines, E'\n');
end $$;

-- เทียบกับงวดก่อน ให้เห็นทิศทาง ไม่ใช่แค่ตัวเลขลอย ๆ
create or replace function line_delta(p_now int, p_prev int)
returns text language sql immutable set search_path = public, extensions as $$
  select case
    when p_prev = 0 and p_now = 0 then '(เท่าเดิม)'
    when p_prev = 0               then '(สัปดาห์ก่อนไม่มี)'
    when p_now  > p_prev          then '(▲ +' || (p_now - p_prev) || ' จาก ' || p_prev || ')'
    when p_now  < p_prev          then '(▼ -' || (p_prev - p_now) || ' จาก ' || p_prev || ')'
    else '(เท่าเดิม ' || p_prev || ')'
  end;
$$;

-- ============================================================
-- 4) สรุปประจำสัปดาห์
-- ============================================================
-- เทียบกับสัปดาห์ก่อนหน้าเสมอ เพราะจำนวนดิบอย่างเดียวบอกไม่ได้ว่าดีขึ้นหรือแย่ลง
create or replace function line_msg_weekly(p_end date default null)
returns text
language plpgsql stable security definer set search_path = public, extensions as $$
declare
  v_end date := coalesce(p_end, line_today() - 1);
  v_start date := coalesce(p_end, line_today() - 1) - 6;
  v_from timestamptz; v_to timestamptz; v_pfrom timestamptz;
  v_acc int; v_acc_prev int; v_death int; v_death_prev int;
  v_lines text[]; r record;
begin
  v_from  := timezone('Asia/Bangkok', v_start::timestamp);
  v_to    := timezone('Asia/Bangkok', (v_end + 1)::timestamp);
  v_pfrom := timezone('Asia/Bangkok', (v_start - 7)::timestamp);

  select count(*) into v_acc from accidents_public where incident_datetime >= v_from and incident_datetime < v_to;
  select count(*) into v_acc_prev from accidents_public where incident_datetime >= v_pfrom and incident_datetime < v_from;
  select count(*) into v_death from deaths where incident_datetime >= v_from and incident_datetime < v_to;
  select count(*) into v_death_prev from deaths where incident_datetime >= v_pfrom and incident_datetime < v_from;

  v_lines := array['📊 สรุปประจำสัปดาห์ สภ.เมืองนครสวรรค์',
                   line_thai_date(v_from) || ' – ' || line_thai_date(timezone('Asia/Bangkok', v_end::timestamp)), ''];

  v_lines := v_lines || ('• อุบัติเหตุ ' || v_acc || ' ครั้ง ' || line_delta(v_acc, v_acc_prev));
  v_lines := v_lines || ('• ผู้เสียชีวิต ' || v_death || ' ราย ' || line_delta(v_death, v_death_prev));

  -- ถนนที่มีผู้เสียชีวิตมากที่สุดในสัปดาห์ — ใช้ตั้งจุดตรวจสัปดาห์ถัดไป
  if v_death > 0 then
    v_lines := v_lines || array['', 'ถนนที่มีผู้เสียชีวิต'];
    for r in
      select coalesce(nullif(btrim(road_name), ''), 'ไม่ระบุถนน') as nm, count(*) as c
        from deaths where incident_datetime >= v_from and incident_datetime < v_to
       group by 1 order by c desc, nm limit 5
    loop
      v_lines := v_lines || ('   – ' || r.nm || ' ' || r.c || ' ราย');
    end loop;

    v_lines := v_lines || array['', 'สาเหตุ'];
    for r in
      select coalesce(nullif(btrim(cause), ''), 'ไม่ระบุสาเหตุ') as nm, count(*) as c
        from deaths where incident_datetime >= v_from and incident_datetime < v_to
       group by 1 order by c desc, nm limit 5
    loop
      v_lines := v_lines || ('   – ' || r.nm || ' ' || r.c || ' ราย');
    end loop;
  end if;

  return array_to_string(v_lines, E'\n');
end $$;

-- ============================================================
-- 5) ตอบคีย์เวิร์ด
-- ============================================================
-- คืน null เมื่อไม่เข้าคีย์เวิร์ดใดเลย = บอทเงียบ
--
-- เรื่องนี้สำคัญกว่าที่คิด บอทอยู่ในกลุ่มที่คนคุยงานกันจริง
-- ถ้าตอบทุกข้อความที่ไม่เข้าใจ จะกลายเป็นตัวกวนจนโดนเตะออกจากกลุ่ม
create or replace function line_reply(p_text text)
returns jsonb
language plpgsql stable security definer set search_path = public, extensions as $$
declare
  v_q text := lower(btrim(coalesce(p_text, '')));
  v_action text; v_lines text[]; r record; v_n int; v_today date := line_today();
begin
  if v_q = '' then return null; end if;

  -- คำที่เจาะจงกว่ามาก่อน ตาม sort_order ที่ตั้งไว้ในตาราง
  select action into v_action from line_keywords
   where enabled and position(keyword in v_q) > 0
   order by sort_order, length(keyword) desc limit 1;

  if v_action is null then return null; end if;

  -- group id ต้องอ่านจากตัวเหตุการณ์ที่ LINE ส่งมา ฐานข้อมูลไม่รู้จัก
  -- ส่งสัญญาณให้ Edge Function เติมเอง
  if v_action = 'id' then
    return jsonb_build_object('action', 'id', 'text', null);
  end if;

  if v_action = 'help' then
    v_lines := array['🤖 พิมพ์คำเหล่านี้เพื่อขอข้อมูล', ''];
    for r in
      select action as a, string_agg(keyword, ' / ' order by keyword) as ks
        from line_keywords where enabled and action not in ('help', 'id')
       group by action
       order by min(sort_order)
    loop
      v_lines := v_lines || ('• ' || r.ks);
    end loop;

  elsif v_action = 'risk' then
    v_lines := array['📍 จุดเสี่ยงที่เผยแพร่แล้ว'];
    select count(*) into v_n from bs_sites where published;
    if v_n = 0 then
      v_lines := v_lines || 'ยังไม่มีจุดเสี่ยงที่เผยแพร่';
    else
      v_lines := v_lines || array['ทั้งหมด ' || v_n || ' จุด · แสดง 8 อันดับแรก', ''];
      for r in
        select title, road, subdistrict, level, fatal_count, acc_count from bs_sites
         where published
         order by case level when 'high' then 0 when 'risk' then 1 else 2 end,
                  fatal_count desc, acc_count desc limit 8
      loop
        v_lines := v_lines || (
          case r.level when 'high' then '🔴 ' when 'risk' then '🟠 ' else '🟡 ' end || r.title ||
          case when coalesce(btrim(r.road),'') <> '' then E'\n     ' || r.road else '' end ||
          case when coalesce(btrim(r.subdistrict),'') <> '' then ' ต.' || r.subdistrict else '' end ||
          E'\n     อุบัติเหตุ ' || r.acc_count || ' · เสียชีวิต ' || r.fatal_count);
      end loop;
    end if;

  elsif v_action = 'avoid' then
    select count(*) into v_n from traffic_advisories
     where closed_at is null and starts_at <= now() and ends_at >= now();
    if v_n = 0 then
      v_lines := array['✅ ขณะนี้ไม่มีประกาศจุดเลี่ยงที่มีผล'];
    else
      v_lines := array['⚠️ ประกาศจุดเลี่ยงที่มีผลขณะนี้ ' || v_n || ' รายการ', ''];
      for r in
        select title, place, detail, reroute, ends_at from traffic_advisories
         where closed_at is null and starts_at <= now() and ends_at >= now()
         order by ends_at limit 8
      loop
        v_lines := v_lines || ('• ' || r.title ||
          E'\n   สถานที่ ' || r.place ||
          E'\n   ถึง ' || line_thai_date(r.ends_at, true) ||
          case when coalesce(btrim(r.reroute),'') <> '' then E'\n   เลี่ยงทาง ' || r.reroute else '' end);
      end loop;
    end if;

  elsif v_action = 'death' then
    v_lines := array['🕯️ ผู้เสียชีวิตจากอุบัติเหตุจราจร'];
    select count(*) into v_n from deaths
     where incident_datetime >= timezone('Asia/Bangkok', date_trunc('year', v_today::timestamp));
    v_lines := v_lines || ('ปี ' || (extract(year from v_today)::int + 543)::text || ' รวม ' || v_n || ' ราย');
    select count(*) into v_n from deaths
     where incident_datetime >= timezone('Asia/Bangkok', date_trunc('month', v_today::timestamp));
    v_lines := v_lines || array['เดือนนี้ ' || v_n || ' ราย', '', 'รายล่าสุด'];
    for r in
      select incident_datetime, road_name, subdistrict, cause, age, gender from deaths
       order by incident_datetime desc nulls last limit 3
    loop
      v_lines := v_lines || ('• ' || line_thai_date(r.incident_datetime, true) ||
        E'\n   ' || coalesce(nullif(btrim(r.road_name), ''), 'ไม่ระบุถนน') ||
        case when coalesce(btrim(r.subdistrict),'') <> '' then ' ต.' || r.subdistrict else '' end ||
        E'\n   ' || coalesce(nullif(btrim(r.gender), ''), 'ไม่ระบุเพศ') ||
        case when coalesce(r.age, 0) > 0 then ' อายุ ' || r.age || ' ปี' else '' end ||
        case when coalesce(btrim(r.cause),'') <> '' then ' · ' || r.cause else '' end);
    end loop;

  elsif v_action = 'accident' then
    v_lines := array['📊 สถิติอุบัติเหตุ'];
    select count(*) into v_n from accidents_public
     where incident_datetime >= timezone('Asia/Bangkok', v_today::timestamp);
    v_lines := v_lines || ('วันนี้ ' || v_n || ' ครั้ง');
    select count(*) into v_n from accidents_public
     where incident_datetime >= timezone('Asia/Bangkok', date_trunc('month', v_today::timestamp));
    v_lines := v_lines || ('เดือนนี้ ' || v_n || ' ครั้ง');
    select count(*) into v_n from accidents_public
     where incident_datetime >= timezone('Asia/Bangkok', date_trunc('year', v_today::timestamp));
    v_lines := v_lines || ('ปีนี้ ' || v_n || ' ครั้ง');
    select count(*) into v_n from deaths
     where incident_datetime >= timezone('Asia/Bangkok', date_trunc('year', v_today::timestamp));
    v_lines := v_lines || ('ผู้เสียชีวิตปีนี้ ' || v_n || ' ราย');

  elsif v_action = 'checkpoint' then
    select count(*) into v_n from cp_checkpoints where duty_date = v_today;
    if v_n = 0 then
      v_lines := array['วันนี้ยังไม่มีการบันทึกจุดตรวจ'];
    else
      v_lines := array['🚓 จุดตรวจวันนี้ ' || v_n || ' จุด', ''];
      for r in
        select place, road_name, subdistrict, commander, start_time, end_time, arrest_count
          from cp_checkpoints where duty_date = v_today order by start_time nulls last limit 8
      loop
        v_lines := v_lines || ('• ' || coalesce(nullif(btrim(r.place), ''), '(ไม่ระบุสถานที่)') ||
          case when coalesce(btrim(r.road_name),'') <> '' then ' · ' || r.road_name else '' end ||
          case when r.start_time is not null
               then E'\n   เวลา ' || to_char(r.start_time, 'HH24:MI') ||
                    coalesce('-' || to_char(r.end_time, 'HH24:MI'), '') else '' end ||
          case when coalesce(btrim(r.commander),'') <> '' then E'\n   หัวหน้าชุด ' || r.commander else '' end ||
          E'\n   จับกุม ' || r.arrest_count || ' ราย');
      end loop;
    end if;
  end if;

  if v_lines is null or array_length(v_lines, 1) is null then return null; end if;
  return jsonb_build_object('action', v_action, 'text', array_to_string(v_lines, E'\n'));
end $$;

-- ============================================================
-- 6) สิทธิ์
-- ============================================================
-- เปิดให้เรียกได้โดยไม่ต้องล็อกอิน เพราะทุกตัวคืนข้อมูลชุดเดียวกับ
-- ที่หน้าเว็บประชาชนแสดงอยู่แล้ว — ยอดอุบัติเหตุ ผู้เสียชีวิต ประกาศจุดเลี่ยง
-- จุดเสี่ยงเฉพาะที่เผยแพร่แล้ว ไม่มีข้อมูลบุคคลสักตัว
--
-- ของที่เป็นความลับจริงคือ group id กับ token ซึ่งอยู่คนละที่ (line_targets ปิด RLS)
-- และการเปิดแบบนี้ทำให้ตรวจข้อความได้จากเบราว์เซอร์โดยไม่ต้องรอ deploy
grant execute on function line_thai_date(timestamptz, boolean) to anon, authenticated;
grant execute on function line_today()                        to anon, authenticated;
grant execute on function line_delta(int, int)                to anon, authenticated;
grant execute on function line_msg_death(bigint)              to anon, authenticated;
grant execute on function line_msg_daily(date)                to anon, authenticated;
grant execute on function line_msg_weekly(date)               to anon, authenticated;
grant execute on function line_reply(text)                    to anon, authenticated;

-- ============================================================
-- ตรวจผลหลังรัน — อ่านข้อความจริงก่อนต่อท่อส่งเข้า LINE
-- ============================================================
-- select line_msg_daily();                      -- สรุปเมื่อวาน
-- select line_msg_weekly();                     -- สรุป 7 วันล่าสุด
-- select line_msg_death((select max(id) from deaths));   -- รายล่าสุด
-- select line_reply('จุดเสี่ยง');
-- select line_reply('เลี่ยง');
-- select line_reply('เสียชีวิต');
-- select line_reply('สวัสดีครับ');              -- ต้องได้ null = บอทเงียบ
