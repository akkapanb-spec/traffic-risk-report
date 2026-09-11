-- แจ้งประกาศล่วงหน้าได้ 12 ชั่วโมงก่อนเริ่ม ไม่ต้องรอให้เริ่มก่อน
-- ถ้ามีอักขระแปลกปลอมต่อท้ายบรรทัดสุดท้าย ให้ลบออกก่อนกด Run
-- รันก่อน 06:00 ของวันที่ 12 ก.ย. 2569
--
-- ------------------------------------------------------------
-- เหตุที่ต้องแก้
-- ------------------------------------------------------------
-- line_advisory_1.sql ส่งประกาศตอนที่มันเริ่มมีผล
-- คืนวันที่ 11 ก.ย. เจ้าหน้าที่แก้ #15 เป็นปิดการจราจรทั้งสองช่องทาง เริ่ม 12 ก.ย. 08:00
-- ตามกติกาเดิม #9 จะออก 06:03 แล้ว #15 ออกแยกอีกข้อความตอน 08:03
-- คือหลังถนนปิดไปแล้วสามนาที คนที่ออกจากบ้านเจ็ดโมงจะไม่ได้รับรู้เลย
--
-- ประกาศเรื่องปิดถนน คุณค่าทั้งหมดอยู่ที่การรู้ก่อนปิด
-- จึงเปลี่ยนเป็นแจ้งได้ตั้งแต่ 12 ชั่วโมงก่อนเริ่ม ร่วมกับช่วงเงียบ 22:00 ถึง 06:00 ที่มีอยู่
--   เริ่มตอนเช้า    แจ้งตอนหัวค่ำวันก่อน หรือ 06:00 ถ้าลงประกาศดึก
--   เริ่มตอนบ่าย    แจ้งตอนเช้าวันเดียวกัน
--   ลงล่วงหน้าสามสัปดาห์    ยังรอจนเหลือ 12 ชั่วโมงเหมือนเดิม ไม่แจ้งเร็วเกินไป
--
-- ผลกับรอบแรก  06:03 วันที่ 12 ก.ย. ทั้ง #9 และ #15 จะออกรวมกันในข้อความเดียว
-- ก่อนถนนปิดสองชั่วโมง
--
-- ------------------------------------------------------------
-- แก้เพิ่มอีกสองจุดในข้อความ
-- ------------------------------------------------------------
-- รายละเอียดตัดที่ 240 ตัวอักษรแทน 160  #15 ยาว 181 และท่อนท้ายถูกตัดทิ้งพอดี
-- เส้นทางเลี่ยงที่พิมพ์คั่นจุลภาคติดกัน จะเว้นวรรคให้อ่านง่าย
--
-- เขียนสองฟังก์ชันใหม่ทั้งตัว คัดจาก line_advisory_1.sql ด้วยเครื่อง แก้เฉพาะจุดที่บอก

-- ==========================================================
-- 1  ค่าตั้งใหม่
-- ==========================================================

insert into bs_settings (key, val) values ('advisoryLeadHours', to_jsonb(12))
on conflict (key) do nothing;

-- ==========================================================
-- 2  ตัวเขียนข้อความ
-- ==========================================================
create or replace function line_adv_item_text(p_id bigint)
returns text
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  a      traffic_advisories%rowtype;
  v_s    timestamp;
  v_e    timestamp;
  v_when text;
  v_kind text;
  v_lines text[];
begin
  select * into a from traffic_advisories where id = p_id;
  if not found then return null; end if;

  v_s := a.starts_at at time zone 'Asia/Bangkok';
  v_e := a.ends_at   at time zone 'Asia/Bangkok';

  -- วันเดียวกันเขียนวันครั้งเดียว คนละวันเขียนทั้งสองวัน
  if v_s::date = v_e::date then
    v_when := line_thai_dm(v_s::date) || ' ' || to_char(v_s, 'HH24:MI') ||
              ' – ' || to_char(v_e, 'HH24:MI') || ' น.';
  else
    v_when := line_thai_dm(v_s::date) || ' ' || to_char(v_s, 'HH24:MI') ||
              ' – ' || line_thai_dm(v_e::date) || ' ' || to_char(v_e, 'HH24:MI') || ' น.';
  end if;

  -- ป้ายชื่อตรงกับที่หน้าเจ้าหน้าที่ใช้ คนลงประกาศกับคนอ่านจะได้เห็นคำเดียวกัน
  v_kind := case a.kind
              when 'work'  then '🚧 ก่อสร้าง/ซ่อมทาง'
              when 'event' then '🚩 ขบวน/กิจกรรม'
              when 'close' then '⛔ ปิดถนน'
              else '📢 ประกาศ'
            end;

  v_lines := array[
    v_kind || '  ' || coalesce(nullif(btrim(a.title), ''), 'ไม่มีชื่อเรื่อง'),
    '📍 ' || coalesce(nullif(btrim(a.place), ''), 'ไม่ระบุสถานที่'),
    '🕒 ' || v_when
  ];

  -- รายละเอียดสำคัญกว่าที่คิด หลายรายการบอกสิ่งที่คนต้องรู้ไว้ตรงนี้
  -- เช่น ปิดช่องซ้ายสุด หรือ ปิดการจราจรเฉพาะวันที่ 12 ถึง 13
  -- ตัดที่ 240 ตัวอักษร  เดิมตัดที่ 160 แต่ #15 ยาว 181 และท่อนท้ายคือคำขอให้หลีกเลี่ยง
  -- ตัดกลางประโยคแบบนั้น คนอ่านจะเห็นแค่ครึ่งเดียวของสิ่งที่เจ้าหน้าที่ตั้งใจบอก
  if nullif(btrim(a.detail), '') is not null then
    v_lines := v_lines || array[
      'ℹ️ ' || case when length(btrim(a.detail)) > 240
                    then left(regexp_replace(btrim(a.detail), '[[:space:]]+', ' ', 'g'), 240) || '…'
                    else regexp_replace(btrim(a.detail), '[[:space:]]+', ' ', 'g') end
    ];
  end if;

  if nullif(btrim(a.reroute), '') is not null then
    -- เจ้าหน้าที่พิมพ์คั่นด้วยจุลภาคติดกัน เช่น ถ.ธรรมวิถี,ซ.อัมรินทร์วิถี  เว้นวรรคให้อ่านง่าย
    v_lines := v_lines || array['↪️ เส้นทางเลี่ยง ' ||
      regexp_replace(btrim(a.reroute), '[[:space:]]*,[[:space:]]*', ', ', 'g')];
  end if;

  if a.latitude is not null and a.longitude is not null then
    v_lines := v_lines || array['🗺️ ' || line_map_link(a.latitude || ',' || a.longitude)];
  end if;

  return array_to_string(v_lines, chr(10));
end;
$fn$;

-- ==========================================================
-- 3  ตัวส่ง
-- ==========================================================
create or replace function line_send_advisories()
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_now   time := (now() at time zone 'Asia/Bangkok')::time;
  v_qs    time := coalesce((select (val #>> array[]::text[])::time from bs_settings where key = 'advisoryQuietStart'), time '22:00');
  v_qe    time := coalesce((select (val #>> array[]::text[])::time from bs_settings where key = 'advisoryQuietEnd'),   time '06:00');
  v_max   int  := coalesce((select (val #>> array[]::text[])::int  from bs_settings where key = 'advisoryMaxPerMsg'),  5);
  v_lead  int  := coalesce((select (val #>> array[]::text[])::int  from bs_settings where key = 'advisoryLeadHours'), 12);
  v_site  text := coalesce((select val #>> array[]::text[] from bs_settings where key = 'publicSiteUrl'), '');
  v_ids   bigint[];
  v_parts text[];
  v_text  text;
  v_ref   text;
  v_sent  int;
  v_id    bigint;
begin
  if coalesce((select (val #>> array[]::text[])::boolean from bs_settings
                where key = 'advisoryAlertEnabled'), false) is not true then
    return jsonb_build_object('success', true, 'message', 'ปิดอยู่');
  end if;

  -- ช่วงเงียบข้ามเที่ยงคืน จึงต้องเช็คสองฝั่ง
  if (v_qs > v_qe and (v_now >= v_qs or v_now < v_qe))
     or (v_qs < v_qe and v_now >= v_qs and v_now < v_qe) then
    return jsonb_build_object('success', true,
      'message', 'อยู่ในช่วงเงียบ ' || to_char(v_qs, 'HH24:MI') || ' ถึง ' || to_char(v_qe, 'HH24:MI') || ' จะส่งตอนพ้นช่วง');
  end if;

  select array_agg(id order by starts_at, id) into v_ids
  from (
    select a.id, a.starts_at
    from traffic_advisories a
    -- แจ้งได้ตั้งแต่ 12 ชั่วโมงก่อนเริ่ม ไม่ต้องรอให้เริ่มก่อน
    -- ถนนปิดต้องรู้ก่อนปิด ถ้ารอส่งตอนเริ่ม ข้อความจะถึงหลังถนนปิดไปแล้ว
    -- และไม่เร็วเกินไป ประกาศที่ลงล่วงหน้าสามสัปดาห์จะยังรอจนเหลือ 12 ชั่วโมง
    where a.starts_at <= now() + make_interval(hours => v_lead)
      and a.ends_at   >  now()
      and a.closed_at is null
      and not exists (select 1 from line_adv_announced x where x.adv_id = a.id)
    order by a.starts_at, a.id
    limit v_max
  ) z;

  if v_ids is null then
    return jsonb_build_object('success', true, 'message', 'ไม่มีประกาศใหม่ที่ถึงเวลา');
  end if;

  v_parts := array['🚧 แจ้งจุดที่ควรหลีกเลี่ยง', ''];

  foreach v_id in array v_ids loop
    v_parts := v_parts || array[line_adv_item_text(v_id), ''];
  end loop;

  v_parts := v_parts || array['โปรดวางแผนการเดินทาง และใช้ความระมัดระวังเมื่อผ่านบริเวณดังกล่าว'];
  if v_site <> '' then
    v_parts := v_parts || array['ดูรูปภาพและรายละเอียด ' || v_site];
  end if;
  v_parts := v_parts || array['', '👮 ด้วยความปรารถนาดี น้องจราจรชอนตะวัน'];

  v_text := array_to_string(v_parts, chr(10));
  v_ref  := 'adv:' || array_to_string(v_ids, '-');

  v_sent := line_broadcast('advisory', v_text, v_ref);

  -- จดว่าแจ้งแล้วเฉพาะเมื่อส่งออกไปจริงอย่างน้อยหนึ่งกลุ่ม
  -- ถ้าตอนนั้นไม่มีกลุ่มเปิดอยู่เลย จะไม่จด รอบหน้าจะได้ลองใหม่
  if v_sent > 0 then
    insert into line_adv_announced (adv_id, ref)
    select unnest(v_ids), v_ref
    on conflict (adv_id) do nothing;
  end if;

  return jsonb_build_object('success', true, 'sent', v_sent, 'ids', to_jsonb(v_ids), 'ref', v_ref,
    'message', case when v_sent > 0 then 'ส่งแล้ว ' || array_length(v_ids, 1) || ' รายการ'
                    else 'ไม่มีกลุ่มที่เปิดรับอยู่ ยังไม่จดว่าแจ้งแล้ว' end);
end;
$fn$;

revoke execute on function line_send_advisories() from anon, authenticated;

-- ==========================================================
-- ตรวจผล  คำสั่งสุดท้ายคำสั่งเดียวที่จะแสดงผล
-- ==========================================================

select 'แจ้งล่วงหน้าได้กี่ชั่วโมง' as รายการ,
  coalesce((select val #>> array[]::text[] from bs_settings where key = 'advisoryLeadHours'), '-') || ' ชั่วโมง' as ผล
union all
select 'ตัวส่งใช้ค่าล่วงหน้าแล้วไหม',
  coalesce((select case when prosrc like '%advisoryLeadHours%' then 'ใช้แล้ว' else 'ยังไม่ใช้' end
            from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' and p.proname = 'line_send_advisories'), 'ไม่พบ')
union all
select 'ตัดรายละเอียดที่',
  coalesce((select case when prosrc like '%> 240%' then '240 ตัวอักษร' else 'ยังเป็นค่าเดิม' end
            from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' and p.proname = 'line_adv_item_text'), 'ไม่พบ')
union all
select 'จะส่งตอน 06:03 วันที่ 12 ก.ย.',
  coalesce((select string_agg('#' || a.id || ' ' || a.title, '  /  ' order by a.starts_at)
            from traffic_advisories a
            where a.starts_at <= timestamp '2026-09-12 06:03' at time zone 'Asia/Bangkok' + interval '12 hours'
              and a.ends_at   >  timestamp '2026-09-12 06:03' at time zone 'Asia/Bangkok'
              and a.closed_at is null
              and not exists (select 1 from line_adv_announced x where x.adv_id = a.id)), 'ไม่มี')
union all
select 'ข้อความที่ #15 จะแสดง',
  left(replace(coalesce(line_adv_item_text(15), 'ไม่พบ'), chr(10), '  /  '), 400)
union all
select 'แบ็กสแลชแปลกปลอม',
  coalesce((select 'พบ ต้องแก้' from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' and p.proname in ('line_adv_item_text', 'line_send_advisories')
              and position(chr(92) in p.prosrc) > 0 limit 1), 'สะอาด ไม่มีเลย');
