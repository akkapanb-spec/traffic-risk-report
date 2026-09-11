-- แจ้งจุดที่ควรหลีกเลี่ยง จากประกาศการจราจร เข้ากลุ่มไลน์สถานการณ์อุบัติเหตุ
-- ถ้ามีอักขระแปลกปลอมต่อท้ายบรรทัดสุดท้าย ให้ลบออกก่อนกด Run
-- ไม่ต้อง deploy Edge Function ไม่ต้องแก้หน้าเว็บ เจ้าหน้าที่ลงประกาศเหมือนเดิมทุกอย่าง
--
-- ============================================================
-- ทำงานอย่างไร
-- ============================================================
-- งานตามเวลาตรวจทุก 5 นาที หาประกาศที่ถึงเวลาเริ่มแล้ว ยังไม่หมดเวลา
-- ยังไม่ถูกกดปิดก่อนกำหนด และยังไม่เคยแจ้งเข้ากลุ่ม แล้วส่งให้กลุ่มหนึ่งครั้ง
--
-- ประกาศหนึ่งรายการแจ้งเข้ากลุ่มครั้งเดียว ตอนที่มันเริ่มมีผล
--   เจ้าหน้าที่ลงประกาศล่วงหน้าสามสัปดาห์    ส่งตอนถึงวันเริ่ม ไม่ใช่ตอนลงประกาศ
--   เจ้าหน้าที่ลงประกาศตอนเกิดเหตุ          ส่งภายในห้านาที
-- วัดจากประกาศที่มีอยู่ 12 รายการ เจ้าหน้าที่ลงประกาศตรงกับเวลาเริ่มพอดีเป็นส่วนใหญ่
-- ค่ากลางคือลงหลังเริ่มหกนาที  จึงเกือบทุกรายการจะถึงกลุ่มภายในสิบนาทีหลังเริ่ม
--
-- ถ้ามีหลายรายการถึงเวลาพร้อมกัน รวมเป็นข้อความเดียว ไม่ส่งแยก
-- คนในกลุ่มสองร้อยกว่าคนจะได้ไม่ถูกเด้งแจ้งเตือนติดกันหลายครั้ง
--
-- ------------------------------------------------------------
-- ช่วงเงียบ 22:00 ถึง 06:00
-- ------------------------------------------------------------
-- ประกาศที่ถึงเวลาเริ่มตอนกลางคืน จะรอส่งตอน 06:00 ไม่ได้ทิ้ง
-- ส่วนใหญ่เป็นงานก่อสร้างที่วางแผนไว้แล้ว ไม่คุ้มที่จะปลุกคนสองร้อยคนตอนเที่ยงคืน
-- ประกาศที่ทั้งเริ่มและจบในช่วงกลางคืนจะไม่ถูกส่งเลย เพราะเช้ามาก็หมดความหมายแล้ว
--
-- ------------------------------------------------------------
-- สิ่งที่ตั้งใจไม่ทำในรอบนี้
-- ------------------------------------------------------------
-- ไม่แจ้งตอนหมดเวลา ว่าเปิดการจราจรแล้ว
--   จะทำให้จำนวนข้อความเป็นสองเท่า และข้อมูลนั้นมีค่าน้อยกว่าตอนเริ่มมาก
-- ไม่ส่งซ้ำเมื่อเจ้าหน้าที่แก้ไขประกาศหลังจากแจ้งไปแล้ว
--   แก้ทีละตัวอักษรก็ส่งใหม่ทั้งฉบับ จะกลายเป็นรบกวน
-- ไม่แนบรูปมาในข้อความ
--   ใส่ลิงก์ไปหน้าเว็บซึ่งมีรูปครบทุกรูปแทน
--
-- ------------------------------------------------------------
-- ค่าใช้จ่ายโควตาไลน์
-- ------------------------------------------------------------
-- ประกาศมีเดือนละ 2 ถึง 6 รายการ แต่ละข้อความนับตามจำนวนคนในกลุ่ม
-- รวมราว 400 ถึง 1,300 จาก 15,000 ต่อเดือนของแพ็กเกจที่ใช้อยู่
-- ใช้ชนิดข้อความ advisory แยกจากฝน จึงไม่ไปกินโควตาของข้อความเตือนฝน

-- ==========================================================
-- 1  ค่าตั้ง  เปลี่ยนได้ด้วย update บรรทัดเดียว
-- ==========================================================

insert into bs_settings (key, val) values
  ('advisoryAlertEnabled', to_jsonb(true)),
  ('advisoryQuietStart',   to_jsonb('22:00'::text)),
  ('advisoryQuietEnd',     to_jsonb('06:00'::text)),
  ('advisoryMaxPerMsg',    to_jsonb(5))
on conflict (key) do nothing;

-- ==========================================================
-- 2  จดว่าประกาศไหนแจ้งไปแล้ว
-- ==========================================================
-- แยกเป็นตารางต่างหาก ไม่เพิ่มช่องในตาราง traffic_advisories
-- ตารางนั้นเป็นของหน้าเจ้าหน้าที่ ถ้าไปเพิ่มช่อง อาจกระทบฟังก์ชันบันทึกที่เขียนไว้แล้ว
-- ลบประกาศเมื่อไร รายการที่นี่ก็หายตามไปเอง

create table if not exists line_adv_announced (
  adv_id       bigint primary key references traffic_advisories(id) on delete cascade,
  announced_at timestamptz not null default now(),
  ref          text
);

alter table line_adv_announced enable row level security;
revoke all on line_adv_announced from anon, authenticated;

-- ==========================================================
-- 3  เขียนข้อความของประกาศหนึ่งรายการ
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
  -- ตัดที่ 160 ตัวอักษร เพราะข้อความรวมหลายรายการต้องไม่ยาวจนคนเลื่อนผ่าน
  if nullif(btrim(a.detail), '') is not null then
    v_lines := v_lines || array[
      'ℹ️ ' || case when length(btrim(a.detail)) > 160
                    then left(regexp_replace(btrim(a.detail), '[[:space:]]+', ' ', 'g'), 160) || '…'
                    else regexp_replace(btrim(a.detail), '[[:space:]]+', ' ', 'g') end
    ];
  end if;

  if nullif(btrim(a.reroute), '') is not null then
    v_lines := v_lines || array['↪️ เส้นทางเลี่ยง ' || btrim(a.reroute)];
  end if;

  if a.latitude is not null and a.longitude is not null then
    v_lines := v_lines || array['🗺️ ' || line_map_link(a.latitude || ',' || a.longitude)];
  end if;

  return array_to_string(v_lines, chr(10));
end;
$fn$;

-- ==========================================================
-- 4  ตัวส่ง  เรียกจากงานตามเวลาทุก 5 นาที
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
    where a.starts_at <= now()
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
-- 5  งานตามเวลา  ทุก 5 นาที เหลื่อมจากงานอื่นไว้
-- ==========================================================
-- ไม่ใช้นาทีเดียวกับงานส่งข่าวผู้เสียชีวิตที่รันทุก 5 นาทีเหมือนกัน
-- จะได้ไม่ยิงไลน์พร้อมกันสองงานในวินาทีเดียว

do $fn$
begin
  perform cron.unschedule('line-advisory');
exception when others then
  raise notice 'ยังไม่เคยมีงานนี้ ข้ามการลบ';
end;
$fn$;

select cron.schedule('line-advisory', '3,8,13,18,23,28,33,38,43,48,53,58 * * * *',
                     'select line_send_advisories()');

-- ==========================================================
-- ตรวจผล  คำสั่งสุดท้ายคำสั่งเดียวที่จะแสดงผล
-- ==========================================================

select 'สวิตช์' as รายการ,
  (select string_agg(key || '=' || (val #>> array[]::text[]), '  ' order by key)
   from bs_settings where key like 'advisory%') as ผล
union all
select 'งานตามเวลา',
  coalesce((select jobname || '  [' || schedule || ']  ' || case when active then 'เปิด' else 'ปิด' end
            from cron.job where jobname = 'line-advisory'), 'ไม่พบ')
union all
select 'ชนิด advisory จะถึงกลุ่มไหม',
  coalesce((select count(*)::text || ' กลุ่มเปิดรับอยู่' from line_targets
            where enabled and target_type = 'group'), '0')
union all
select 'ประกาศที่จะส่งในรอบแรก',
  coalesce((select string_agg('#' || id || ' ' || title, '  /  ' order by starts_at)
            from traffic_advisories a
            where a.starts_at <= now() and a.ends_at > now() and a.closed_at is null
              and not exists (select 1 from line_adv_announced x where x.adv_id = a.id)), 'ไม่มี')
union all
select 'ตอนนี้อยู่ในช่วงเงียบไหม',
  case when (now() at time zone 'Asia/Bangkok')::time >= time '22:00'
         or (now() at time zone 'Asia/Bangkok')::time <  time '06:00'
       then 'ใช่  จะส่งตอน 06:03 น.' else 'ไม่ใช่  จะส่งภายใน 5 นาที' end
union all
select 'แบ็กสแลชแปลกปลอม',
  coalesce((select 'พบ ต้องแก้' from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' and p.proname in ('line_adv_item_text', 'line_send_advisories')
              and position(chr(92) in p.prosrc) > 0 limit 1), 'สะอาด ไม่มีเลย');
