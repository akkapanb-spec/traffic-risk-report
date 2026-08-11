-- ============================================================
-- LINE Bot — ตัวสร้างข้อความ
-- ============================================================
-- ไฟล์ที่ 2 จาก 3  ต้องรัน line_1_tables.sql มาก่อน
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
--
-- ไฟล์นี้ยังไม่ส่งอะไรออก LINE สร้างแต่ข้อความเป็นข้อความเปล่า ๆ
-- จะได้อ่านตรวจเนื้อหาให้ถูกก่อน แล้วค่อยต่อท่อส่งในไฟล์ที่ 3
--
-- ทำไมสร้างข้อความใน SQL ไม่ใช่ใน Edge Function
--   ข้อความทุกบรรทัดคือคำถามกับฐานข้อมูล ซึ่งเป็นสิ่งที่ SQL ทำได้ตรงที่สุด
--   ตรวจผลได้ทันทีด้วย select โดยไม่ต้อง deploy อะไร
--   Edge Function จึงเหลือหน้าที่แค่รับ-ส่ง ไม่รู้จักคีย์เวิร์ดสักตัว
--
-- ที่มาของตัวเลขแต่ละบรรทัด
--   อุบัติเหตุ         accidents_public   (id + เวลา เท่านั้น)
--   เสียชีวิต          deaths
--   สาหัส/หมดสติ      injuries.raw->>'severity'
--   บาดเจ็บเล็กน้อย    injuries.raw->>'severity'
--
-- ไม่กันข้อมูลซ้ำในตาราง deaths โดยตั้งใจ
--   ตรวจแล้วพบว่าแถวที่เวลาตรงกันคือคนละคนในเหตุเดียวกัน
--   เช่นรถตู้คว่ำครั้งหนึ่งเสียชีวิต 3 ราย (ชาย 29 · หญิง 35 · หญิง 46)
--   ถ้ายุบว่าเป็นรายเดียวกันเพราะเวลาใกล้กัน จะรายงานขาดไป 2 ศพ
-- ============================================================

set search_path = public, extensions;

-- ============================================================
-- 1) ตัวช่วย
-- ============================================================
-- ทุกอย่างในระบบนี้เป็นเวลาไทย และปีที่แสดงต่อคนอ่านเป็น พ.ศ.
create or replace function line_thai_date(p_ts timestamptz, p_with_time boolean default false)
returns text
language plpgsql immutable set search_path = public, extensions as $line_thai_date$
declare
  v timestamp;
  m text[] := array['ม.ค.','ก.พ.','มี.ค.','เม.ย.','พ.ค.','มิ.ย.','ก.ค.','ส.ค.','ก.ย.','ต.ค.','พ.ย.','ธ.ค.'];
begin
  if p_ts is null then return '-'; end if;
  v := timezone('Asia/Bangkok', p_ts);
  return to_char(v, 'FMDD') || ' ' || m[extract(month from v)::int] || ' ' ||
         (extract(year from v)::int + 543)::text ||
         case when p_with_time then ' ' || to_char(v, 'HH24:MI') || ' น.' else '' end;
end $line_thai_date$;

create or replace function line_today()
returns date language sql stable set search_path = public, extensions as $line_today$
  select (timezone('Asia/Bangkok', now()))::date;
$line_today$;

-- เทียบกับงวดก่อน ให้เห็นทิศทาง ไม่ใช่แค่ตัวเลขลอย ๆ
-- ต้องสร้างก่อนตัวที่เรียกใช้มัน
create or replace function line_delta(p_now int, p_prev int)
returns text language sql immutable set search_path = public, extensions as $line_delta$
  select case
    when p_prev = 0 and p_now = 0 then ''
    when p_prev = 0               then ' (งวดก่อนไม่มี)'
    when p_now  > p_prev          then ' (▲ +' || (p_now - p_prev) || ' จาก ' || p_prev || ')'
    when p_now  < p_prev          then ' (▼ -' || (p_prev - p_now) || ' จาก ' || p_prev || ')'
    else ' (เท่าเดิม)'
  end;
$line_delta$;

-- ============================================================
-- 2) นับอุบัติเหตุและผู้บาดเจ็บในช่วงเวลาหนึ่ง
-- ============================================================
-- แยกออกมาเป็นตัวเดียว เพราะทั้ง #ac-d #ac-w และสรุปรายสัปดาห์
-- ต้องการตัวเลขชุดเดียวกันเป๊ะ ๆ ต่างกันแค่ช่วงเวลา
-- ถ้าเขียนแยกกันสามที่ วันหนึ่งจะแก้ไม่ครบ แล้วตัวเลขสองที่ไม่ตรงกัน
create or replace function line_acc_counts(p_from timestamptz, p_to timestamptz)
returns jsonb
language sql stable security definer set search_path = public, extensions as $line_acc_counts$
  select jsonb_build_object(
    'accidents', (select count(*) from accidents_public
                   where incident_datetime >= p_from and incident_datetime < p_to),
    'deaths',    (select count(*) from deaths
                   where incident_datetime >= p_from and incident_datetime < p_to),
    'severe',    (select count(*) from injuries
                   where incident_datetime >= p_from and incident_datetime < p_to
                     and raw->>'severity' in ('สาหัส', 'หมดสติ')),
    'minor',     (select count(*) from injuries
                   where incident_datetime >= p_from and incident_datetime < p_to
                     and raw->>'severity' = 'เล็กน้อย'));
$line_acc_counts$;

-- ============================================================
-- 3) #ac-d — อุบัติเหตุวันนี้
-- ============================================================
create or replace function line_msg_acc_day(p_day date default null)
returns text
language plpgsql stable security definer set search_path = public, extensions as $line_msg_acc_day$
declare
  v_day date := coalesce(p_day, line_today());
  v_from timestamptz; v_to timestamptz; c jsonb;
begin
  v_from := timezone('Asia/Bangkok', v_day::timestamp);
  v_to   := timezone('Asia/Bangkok', (v_day + 1)::timestamp);
  c := line_acc_counts(v_from, v_to);

  return array_to_string(array[
    '📊 อุบัติเหตุวันนี้',
    line_thai_date(v_from),
    '',
    '• อุบัติเหตุ ' || (c->>'accidents') || ' ครั้ง',
    '• เสียชีวิต ' || (c->>'deaths') || ' ราย',
    '• สาหัส/หมดสติ ' || (c->>'severe') || ' ราย',
    '• บาดเจ็บเล็กน้อย ' || (c->>'minor') || ' ราย'
  ], chr(10));
end $line_msg_acc_day$;

-- ============================================================
-- 4) #ac-w — อุบัติเหตุรอบสัปดาห์
-- ============================================================
-- 7 วันย้อนหลังนับถึงวันที่ระบุ เทียบกับ 7 วันก่อนหน้า
create or replace function line_msg_acc_week(p_end date default null)
returns text
language plpgsql stable security definer set search_path = public, extensions as $line_msg_acc_week$
declare
  v_end date := coalesce(p_end, line_today());
  v_start date; v_from timestamptz; v_to timestamptz; v_pfrom timestamptz;
  c jsonb; p jsonb;
begin
  v_start := v_end - 6;
  v_from  := timezone('Asia/Bangkok', v_start::timestamp);
  v_to    := timezone('Asia/Bangkok', (v_end + 1)::timestamp);
  v_pfrom := timezone('Asia/Bangkok', (v_start - 7)::timestamp);

  c := line_acc_counts(v_from, v_to);
  p := line_acc_counts(v_pfrom, v_from);

  return array_to_string(array[
    '📊 สรุปอุบัติเหตุรอบสัปดาห์',
    line_thai_date(v_from) || ' – ' || line_thai_date(timezone('Asia/Bangkok', v_end::timestamp)),
    '',
    '• อุบัติเหตุ ' || (c->>'accidents') || ' ครั้ง' || line_delta((c->>'accidents')::int, (p->>'accidents')::int),
    '• เสียชีวิต ' || (c->>'deaths') || ' ราย' || line_delta((c->>'deaths')::int, (p->>'deaths')::int),
    '• สาหัส/หมดสติ ' || (c->>'severe') || ' ราย' || line_delta((c->>'severe')::int, (p->>'severe')::int),
    '• บาดเจ็บเล็กน้อย ' || (c->>'minor') || ' ราย' || line_delta((c->>'minor')::int, (p->>'minor')::int)
  ], chr(10));
end $line_msg_acc_week$;

-- ============================================================
-- 5) ผู้เสียชีวิตรายใหม่ — ส่งอัตโนมัติ ไม่ต้องพิมพ์คีย์เวิร์ด
-- ============================================================
-- ข้อความนี้ถูกส่งทันทีที่มีการบันทึกผู้เสียชีวิตเข้าระบบ
-- จึงต้องอ่านจบเร็ว และบอกสิ่งที่เอาไปสั่งการต่อได้จริง
create or replace function line_msg_death(p_id bigint)
returns text
language plpgsql stable security definer set search_path = public, extensions as $line_msg_death$
declare
  d record; v_year int; v_year_n int; v_lines text[];
  v_lat text; v_lng text; v_pos int;
begin
  select * into d from deaths where id = p_id;
  if d.id is null then return null; end if;

  v_year := extract(year from timezone('Asia/Bangkok', d.incident_datetime))::int;
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

  -- พิกัดเก็บเป็นข้อความ "lat, lng" แปลงเป็นลิงก์แผนที่ให้กดได้จากในไลน์เลย
  if coalesce(btrim(d.coordinates), '') <> '' and strpos(d.coordinates, ',') > 0 then
    v_pos := strpos(d.coordinates, ',');
    v_lat := btrim(left(d.coordinates, v_pos - 1));
    v_lng := btrim(substr(d.coordinates, v_pos + 1));
    if v_lat <> '' and v_lng <> '' then
      v_lines := v_lines || ('แผนที่ https://www.google.com/maps?q=' || v_lat || ',' || v_lng);
    end if;
  end if;

  v_lines := v_lines || ('รวมผู้เสียชีวิตปี ' || (v_year + 543)::text || ' : ' || v_year_n || ' ราย');
  return array_to_string(v_lines, chr(10));
end $line_msg_death$;

-- ============================================================
-- 6) สรุปรายสัปดาห์ที่ส่งอัตโนมัติ
-- ============================================================
-- เนื้อหาเดียวกับ #ac-w ทุกประการ ต่างกันแค่ใครเป็นคนสั่งให้ส่ง
-- ไม่เขียนซ้ำ เรียกตัวเดิม จะได้ไม่มีวันหลุดกันคนละเลข
create or replace function line_msg_weekly(p_end date default null)
returns text language sql stable security definer set search_path = public, extensions as $line_msg_weekly$
  select line_msg_acc_week(coalesce(p_end, line_today() - 1));
$line_msg_weekly$;

-- ============================================================
-- 7) ตอบคีย์เวิร์ด
-- ============================================================
-- คืน null เมื่อไม่เข้าคีย์เวิร์ดใดเลย = บอทเงียบ
--
-- เรื่องนี้สำคัญกว่าที่คิด บอทอยู่ในกลุ่มที่คนคุยงานกันจริง
-- ถ้าตอบทุกข้อความที่ไม่เข้าใจ จะกลายเป็นตัวกวนจนโดนเตะออกจากกลุ่ม
--
-- จับแบบตรงตัว ไม่ใช่แค่มีคำนั้นอยู่ในประโยค
-- ยอมให้มีข้อความต่อท้ายได้ เช่น "#ac-d ครับ" เพราะคนพิมพ์ในกลุ่มมักลงท้ายแบบนั้น
create or replace function line_reply(p_text text)
returns jsonb
language plpgsql stable security definer set search_path = public, extensions as $line_reply$
declare
  v_q text := lower(btrim(coalesce(p_text, '')));
  v_action text; v_lines text[]; r record;
begin
  if v_q = '' then return null; end if;

  select action into v_action from line_keywords
   where enabled and (v_q = keyword or v_q like keyword || ' %')
   order by sort_order, length(keyword) desc limit 1;

  if v_action is null then return null; end if;

  -- id ของห้องมากับตัวเหตุการณ์ที่ LINE ส่งมา ฐานข้อมูลไม่มีทางรู้
  -- ส่งสัญญาณให้ Edge Function เติมเอง
  if v_action = 'id' then
    return jsonb_build_object('action', 'id', 'text', null);
  end if;

  if v_action = 'ac-d' then
    return jsonb_build_object('action', v_action, 'text', line_msg_acc_day());
  elsif v_action = 'ac-w' then
    return jsonb_build_object('action', v_action, 'text', line_msg_acc_week());

  elsif v_action = 'help' then
    -- อ่านรายการจากตารางคีย์เวิร์ดโดยตรง คำที่เพิ่มใหม่จะโผล่เองอัตโนมัติ
    -- ไม่ต้องมาแก้ข้อความเมนูซ้ำทุกครั้งที่เพิ่มคำสั่ง
    v_lines := array['🤖 คำสั่งที่ใช้ได้', ''];
    for r in
      select string_agg(keyword, ' / ' order by keyword) as ks,
             max(case action when 'ac-d' then 'สรุปอุบัติเหตุวันนี้'
                             when 'ac-w' then 'สรุปอุบัติเหตุรอบสัปดาห์'
                             when 'id'   then 'ดู ID ของห้องนี้ (ใช้ตอนตั้งค่า)'
                             else action end) as ds
        from line_keywords where enabled and action <> 'help'
       group by action order by min(sort_order)
    loop
      v_lines := v_lines || (r.ks || '  —  ' || r.ds);
    end loop;
  end if;

  if v_lines is null or array_length(v_lines, 1) is null then return null; end if;
  return jsonb_build_object('action', v_action, 'text', array_to_string(v_lines, chr(10)));
end $line_reply$;

-- ============================================================
-- 8) สิทธิ์
-- ============================================================
-- เปิดให้ anon เรียกได้ เพราะทุกตัวคืน "จำนวน" ล้วน ๆ ไม่มีรายละเอียดรายกรณี
-- ตัวเลขชุดนี้อ่านได้จากตารางสาธารณะอยู่แล้ว — accidents_public, deaths, injuries
-- ล้วนเปิดให้ anon อ่านตรง ๆ ได้ การเปิดตรงนี้จึงไม่ได้เปิดอะไรใหม่
--
-- ข้อควรระวังสำหรับอนาคต: ถ้าวันหนึ่งเพิ่มคำสั่งที่คืนรายละเอียดรายกรณี
-- (สถานที่ พิกัด ทะเบียนรถ) ต้องย้ายไปใช้ service role เท่านั้น
-- เพราะตาราง accidents ถูกปิดจาก anon โดยตั้งใจ เนื่องจากมีข้อมูลบุคคล
grant execute on function line_thai_date(timestamptz, boolean)      to anon, authenticated;
grant execute on function line_today()                              to anon, authenticated;
grant execute on function line_delta(int, int)                      to anon, authenticated;
grant execute on function line_acc_counts(timestamptz, timestamptz) to anon, authenticated;
grant execute on function line_msg_acc_day(date)                    to anon, authenticated;
grant execute on function line_msg_acc_week(date)                   to anon, authenticated;
grant execute on function line_msg_death(bigint)                    to anon, authenticated;
grant execute on function line_msg_weekly(date)                     to anon, authenticated;
grant execute on function line_reply(text)                          to anon, authenticated;

-- ============================================================
-- ตรวจผลหลังรัน — อ่านข้อความจริงก่อนต่อท่อส่งเข้า LINE
-- ============================================================
-- select line_msg_acc_day();                            -- #ac-d ของวันนี้
-- select line_msg_acc_week();                           -- #ac-w
-- select line_msg_death((select max(id) from deaths));   -- ผู้เสียชีวิตรายล่าสุด
-- select line_reply('#ac-d');
-- select line_reply('#help');
-- select line_reply('สวัสดีครับ');                       -- ต้องได้ null = บอทเงียบ
-- select line_reply('เมื่อวานมีคนตายแถวสะพาน');           -- ต้องได้ null ด้วย
