-- แจ้งประกาศเข้ากลุ่มไลน์ทันทีที่เจ้าหน้าที่ลงประกาศ  และส่งสองรายการที่ค้างอยู่ตอนนี้เลย
-- ถ้ามีอักขระแปลกปลอมต่อท้ายบรรทัดสุดท้าย ให้ลบออกก่อนกด Run
-- ใช้แทน line_advisory_3_lead.sql ซึ่งไม่ต้องรันแล้ว
--
-- ============================================================
-- สิ่งที่ผู้ใช้กำหนด  11 ก.ย. 2569 เวลา 23:54
-- ============================================================
--   วันนี้ แจ้งเลยตอนนี้
--   ครั้งหน้า ลงประกาศปุ๊บ ให้แจ้งเลย
--
-- เดิมออกแบบให้รอจนประกาศเริ่มมีผล และมีช่วงเงียบ 22:00 ถึง 06:00
-- ทั้งสองอย่างถูกยกเลิกตามที่สั่ง ประกาศออกทันทีไม่ว่าจะเริ่มเมื่อไรหรือกี่โมง
--
-- ------------------------------------------------------------
-- ทันทีจริง ๆ ไม่ใช่ภายในห้านาที
-- ------------------------------------------------------------
-- ใช้ตัวดักบนตาราง traffic_advisories  ทำงานทันทีที่มีแถวใหม่
-- ไม่ต้องแก้หน้าเว็บ ไม่ต้องแก้ advisory_save เพราะดักที่ตัวตาราง
-- ตรวจแล้วว่า advisory_save ใช้ insert ครั้งเดียวพร้อมข้อมูลครบทุกช่องรวมรูป
-- ตัวดักจึงเห็นข้อมูลครบตั้งแต่ครั้งแรก ไม่มีจังหวะที่ส่งข้อมูลครึ่ง ๆ ออกไป
--
-- ดักเฉพาะการลงใหม่ ไม่ดักการแก้ไข
-- แก้ประกาศที่แจ้งไปแล้วจะไม่ส่งซ้ำ ตามที่ผู้ใช้สั่งไว้ว่าเหตุที่แจ้งแล้วไม่ต้องแจ้งซ้ำ
-- ผลที่ต้องรู้ไว้ คือถ้าลงประกาศแล้วพิมพ์ผิด จะออกไปพร้อมคำผิด แก้ทีหลังก็ไม่ส่งใหม่
--
-- ------------------------------------------------------------
-- ตัวดักห้ามทำให้การบันทึกของเจ้าหน้าที่พัง
-- ------------------------------------------------------------
-- ถ้าส่งไลน์ไม่สำเร็จ ไม่ว่าเพราะอะไร การบันทึกประกาศต้องสำเร็จเหมือนเดิม
-- จึงห่อทั้งก้อนด้วยตัวดักความผิดพลาด ความผิดพลาดของไลน์ไม่ไหลกลับไปถึงเจ้าหน้าที่
-- งานตามเวลาทุก 5 นาทียังอยู่ เป็นตาข่ายรองรับ ถ้าตัวดักพลาด ภายในห้านาทีก็ยังออก
--
-- งานที่ตัวดักเพิ่มเข้าไปในการบันทึก คือค้นไม่กี่แถว เขียนข้อความ และเข้าคิวส่ง
-- ใช้เวลาเสี้ยววินาที ไม่ชนขีดจำกัดสามวินาทีของบทบาท anon ที่หน้าเว็บใช้
-- ตัวส่งไลน์จริงยิงออกไปหลังการบันทึกเสร็จแล้ว ไม่ได้ทำให้เจ้าหน้าที่รอ

-- ==========================================================
-- 1  ปิดช่วงเงียบ  เก็บตัวตั้งค่าไว้ เผื่ออยากเปิดคืน
-- ==========================================================
-- ตั้งเริ่มกับจบเป็นเวลาเดียวกัน ตัวตรวจช่วงเงียบจะไม่มีวันเป็นจริง
-- ถ้าอยากเปิดคืน  update bs_settings set val = to_jsonb(22:00 เป็นข้อความ) ตามเดิม

update bs_settings set val = to_jsonb('00:00'::text) where key in ('advisoryQuietStart', 'advisoryQuietEnd');

-- ==========================================================
-- 2  ตัวเขียนข้อความ  เหมือนใน line_advisory_3_lead.sql
-- ==========================================================
-- ตัดรายละเอียดที่ 240 ตัวอักษร และเว้นวรรคหลังจุลภาคในเส้นทางเลี่ยง
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
-- 3  ตัวส่ง  ไม่รอเวลาเริ่มแล้ว
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
    -- แจ้งทันทีที่ลงประกาศ ไม่รอเวลาเริ่ม  ตามที่ผู้ใช้กำหนดเมื่อ 11 ก.ย. 2569
    -- ยังตัดประกาศที่หมดเวลาไปแล้วออก เช่นที่ลงย้อนหลังหลังงานจบ
    -- ประกาศแบบนั้นไม่มีอะไรให้หลีกเลี่ยงแล้ว แจ้งไปก็เป็นแค่เสียงรบกวน
    where a.ends_at   >  now()
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
-- 4  ตัวดัก  ลงประกาศปุ๊บ แจ้งปั๊บ
-- ==========================================================

create or replace function line_adv_after_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  begin
    perform line_send_advisories();
  exception when others then
    -- ไม่โยนต่อ การบันทึกของเจ้าหน้าที่ต้องสำเร็จเสมอ
    -- งานตามเวลาจะลองส่งใหม่ภายในห้านาที
    raise warning 'แจ้งประกาศเข้าไลน์ไม่สำเร็จ จะลองใหม่รอบถัดไป  %', sqlerrm;
  end;
  return null;
end;
$fn$;

drop trigger if exists line_adv_notify on traffic_advisories;

create trigger line_adv_notify
  after insert on traffic_advisories
  for each row execute function line_adv_after_insert();

-- ==========================================================
-- 5  ส่งสองรายการที่ค้างอยู่ตอนนี้เลย
-- ==========================================================
-- ตัวส่งเข้าคิวข้อความในรายการนี้ ตัวยิงไลน์จริงออกไปหลังกด Run เสร็จ
-- ผลว่าไลน์รับหรือไม่ อ่านได้หลังจากนั้น ไม่ใช่ในไฟล์นี้

select line_send_advisories();

-- ==========================================================
-- ตรวจผล  คำสั่งสุดท้ายคำสั่งเดียวที่จะแสดงผล
-- ==========================================================

select 'เข้าคิวส่งเข้ากลุ่มแล้ว' as รายการ,
  coalesce((select string_agg(ref_id || '  ' || to_char(sent_at at time zone 'Asia/Bangkok', 'HH24:MI:SS'), '  ')
            from line_sent where kind = 'advisory'), 'ยังไม่มี') as ผล
union all
select 'ประกาศที่จดว่าแจ้งแล้ว',
  coalesce((select string_agg('#' || adv_id, ' ' order by adv_id) from line_adv_announced), 'ไม่มี')
union all
select 'ตัวดักบนตารางประกาศ',
  coalesce((select tgname || '  ' || case when tgenabled = 'O' then 'เปิด' else 'ปิด' end
            from pg_trigger where tgrelid = 'public.traffic_advisories'::regclass and tgname = 'line_adv_notify'), 'ไม่มี')
union all
select 'ช่วงเงียบ',
  (select string_agg(val #>> array[]::text[], ' ถึง ' order by key desc) from bs_settings
   where key in ('advisoryQuietStart', 'advisoryQuietEnd')) || '  เท่ากัน คือปิดอยู่'
union all
select 'ตัวส่งยังรอเวลาเริ่มไหม',
  coalesce((select case when prosrc like '%starts_at <= now()%' then 'ยังรอ ต้องแก้' else 'ไม่รอแล้ว แจ้งทันที' end
            from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' and p.proname = 'line_send_advisories'), 'ไม่พบ')
union all
select 'งานตามเวลาสำรอง',
  coalesce((select jobname || '  ' || case when active then 'เปิด' else 'ปิด' end
            from cron.job where jobname = 'line-advisory'), 'ไม่พบ')
union all
select 'แบ็กสแลชแปลกปลอม',
  coalesce((select 'พบ ต้องแก้' from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' and p.proname in ('line_adv_item_text', 'line_send_advisories', 'line_adv_after_insert')
              and position(chr(92) in p.prosrc) > 0 limit 1), 'สะอาด ไม่มีเลย')
union all
select 'ขั้นต่อไป', 'รอสักครู่แล้วดูในกลุ่มไลน์ ต้องเห็นข้อความเดียวที่มีทั้ง #9 และ #15';
