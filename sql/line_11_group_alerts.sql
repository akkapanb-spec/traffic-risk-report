-- ============================================================
-- LINE Bot — แจ้งเตือนอัตโนมัติเข้ากลุ่มเท่านั้น
-- ============================================================
-- ไฟล์ที่ 11  ต้องรัน line_1 ถึง line_5, officer.sql, density_3_speed.sql มาก่อน
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
--
-- ไฟล์นี้ทำ 4 อย่าง
--   1) การแจ้งอัตโนมัติทุกชนิด ส่งเข้าเฉพาะ "กลุ่ม" ไม่ส่งหาแชทส่วนตัว
--   2) ปิดช่องโหว่: อุบัติเหตุที่บันทึกผ่านฟอร์มไม่เคยระบุว่าตายที่เกิดเหตุหรือที่ รพ.
--   3) แจ้งผู้เสียชีวิต เฉพาะที่เสียชีวิตในที่เกิดเหตุเท่านั้น
--   4) แจ้งจุดสะสมอุบัติเหตุรายเดือน ช่องกว้าง 100 ม. ทันทีที่ถึงเกณฑ์
-- ============================================================

set search_path = public, extensions;

-- ============================================================
-- 1) แจ้งเข้ากลุ่มอย่างเดียว
-- ============================================================
-- เดิมยิงหาทุกปลายทางใน line_targets รวมคนที่แอดบอทเป็นเพื่อนส่วนตัว
-- ข้อมูลผู้เสียชีวิตกับจุดเสี่ยงเป็นเรื่องของงาน ไม่ควรเด้งเข้าแชทส่วนตัวของประชาชน
-- เติมเงื่อนไข target_type = 'group' ที่ตัวกระจายตัวเดียว
-- ทุกการแจ้งอัตโนมัติจึงถูกจำกัดพร้อมกันหมด ไม่ต้องไล่แก้ทีละตัว
create or replace function line_broadcast(p_kind text, p_text text, p_ref text default null)
returns int
language plpgsql security definer set search_path = public, extensions as $line_broadcast$
declare t record; v_n int := 0; v_req bigint;
begin
  if coalesce(btrim(p_text), '') = '' then return 0; end if;

  for t in
    select target_id from line_targets
     where enabled
       and target_type = 'group'
       and case p_kind when 'death'  then want_death
                       when 'daily'  then want_daily
                       when 'weekly' then want_weekly
                       else true end
  loop
    if p_ref is not null and exists (
      select 1 from line_sent where kind = p_kind and ref_id = p_ref and target_id = t.target_id
    ) then continue; end if;

    v_req := line_push(t.target_id, p_text);
    insert into line_sent (kind, ref_id, target_id, ok, detail)
    values (p_kind, p_ref, t.target_id, v_req is not null, 'net_request_id=' || coalesce(v_req::text, 'null'));
    v_n := v_n + 1;
  end loop;

  return v_n;
end $line_broadcast$;

revoke execute on function line_broadcast(text, text, text) from public, anon, authenticated;

-- ============================================================
-- 2) ระบุให้ชัดว่าเสียชีวิตในที่เกิดเหตุ
-- ============================================================
-- ปัญหาที่เจอตอนทำข้อ 3
--   ตาราง deaths มีคอลัมน์ col_g บอกว่า "เสียชีวิตที่เกิดเหตุ" หรือ "เสียชีวิตโรงพยาบาล"
--   ฟอร์มบันทึกผู้เสียชีวิตกรอกช่องนี้ และข้อมูลนำเข้าเดิมก็มีครบ (ที่เกิดเหตุ 60 / รพ. 30)
--   แต่แถวที่ officer_save_accident สร้างให้อัตโนมัติ ไม่เคยใส่ค่านี้เลย เป็น null ทุกแถว
--
--   ฟอร์มอุบัติเหตุมีตัวเลือกอาการแค่ เสียชีวิต / หมดสติ / สาหัส / เล็กน้อย
--   ไม่มีตัวเลือก "เสียชีวิตภายหลัง" — คนที่ถูกบันทึกว่าเสียชีวิตในฟอร์มนั้น
--   คือเสียชีวิตในที่เกิดเหตุตามนิยาม จึงเติมค่าให้ตรงตามความหมายที่บันทึกไว้จริง
--
--   ถ้าไม่แก้ตรงนี้ การแจ้งเตือนข้อ 3 จะพลาดเคสที่สำคัญที่สุด
--   คือเคสที่เพิ่งบันทึกสด ๆ จากที่เกิดเหตุ ซึ่งเป็นเคสที่ต้องแจ้งเร็วที่สุด
--
-- ฟังก์ชันนี้คัดลอกมาจาก sql/officer.sql ทั้งดุ้น เปลี่ยนแค่สองบรรทัดที่ insert into deaths
-- ตรวจแล้วว่า officer_save_accident มีนิยามเดียวในโปรเจกต์ ไม่มีไฟล์อื่นเขียนทับทีหลัง
create or replace function officer_save_accident(p_token text, p_payload jsonb, p_images jsonb)
returns jsonb
language plpgsql security definer set search_path = public as $osa$
declare
  v_user jsonb;
  v_code text;
  v_occurred timestamptz;
  v_loc jsonb;
  v_persons jsonb := '[]'::jsonb;
  v_p jsonb;
  v_pass jsonb;
  v_vehicle text;
  v_injury text;
  i int;
begin
  v_user := officer_session_user(p_token);
  if v_user is null then
    return jsonb_build_object('success',false,'code','AUTH_REQUIRED','message','เซสชันหมดอายุ กรุณาเข้าสู่ระบบอีกครั้ง');
  end if;

  v_occurred := (p_payload->>'occurredAt')::timestamptz;
  if v_occurred is null then
    return jsonb_build_object('success',false,'message','วันที่และเวลาเกิดเหตุไม่ถูกต้อง');
  end if;
  v_loc := coalesce(p_payload->'location','{}'::jsonb);
  v_code := 'ACC-'||to_char(now() at time zone 'Asia/Bangkok','YYYYMMDD-HH24MISS')
            ||'-'||lpad(floor(random()*9000+1000)::text, 4, '0');

  insert into accidents(
    incident_datetime, recorded_at, accident_code,
    officer_rank, officer_name, officer_national_id, officer_code,
    party1, party2,
    place, road_character, road_character_other, road, local_authority,
    subdistrict, district, province, cause, latitude, longitude, details,
    images, verify_status
  ) values (
    v_occurred, now(), v_code,
    v_user->>'rank', (v_user->>'firstName')||' '||(v_user->>'lastName'),
    v_user->>'nationalId', v_user->>'policeCode',
    coalesce(p_payload->'party1','{}'::jsonb), coalesce(p_payload->'party2','{}'::jsonb),
    v_loc->>'place', v_loc->>'roadCharacter', v_loc->>'roadCharacterOther',
    v_loc->>'road', v_loc->>'localAuthority', v_loc->>'subdistrict',
    coalesce(v_loc->>'district','เมืองนครสวรรค์'), coalesce(v_loc->>'province','นครสวรรค์'),
    v_loc->>'cause', nullif(v_loc->>'latitude','')::double precision,
    nullif(v_loc->>'longitude','')::double precision, v_loc->>'details',
    coalesce(p_images,'[]'::jsonb), 'รอตรวจสอบ'
  );

  -- รวมรายชื่อบุคคลทั้งหมด (ฝ่าย 1 + ผู้โดยสาร, ฝ่าย 2 + ผู้โดยสาร)
  v_p := coalesce(p_payload->'party1','{}'::jsonb);
  v_vehicle := case when v_p->>'vehicle' = 'อื่นๆ' and coalesce(v_p->>'vehicleOther','') <> ''
                    then v_p->>'vehicleOther' else coalesce(v_p->>'vehicle','') end;
  v_persons := v_persons || jsonb_build_array(jsonb_build_object(
    'party','ฝ่ายที่1','type',coalesce(v_p->>'status','ผู้ขับขี่'),'gender',v_p->>'gender',
    'age',v_p->>'age','injury',v_p->>'injury','safety',v_p->>'safety','vehicle',v_vehicle));
  i := 0;
  for v_pass in select value from jsonb_array_elements(coalesce(v_p->'passengers','[]'::jsonb))
  loop
    i := i + 1;
    v_persons := v_persons || jsonb_build_array(jsonb_build_object(
      'party','ฝ่ายที่1','type','ผู้โดยสารที่'||i,'gender',v_pass->>'gender',
      'age',v_pass->>'age','injury',v_pass->>'injury','safety',v_pass->>'safety','vehicle',v_vehicle));
  end loop;

  v_p := coalesce(p_payload->'party2','{}'::jsonb);
  if coalesce(v_p->>'status','ไม่มี') <> 'ไม่มี' then
    v_vehicle := case when v_p->>'vehicle' = 'อื่นๆ' and coalesce(v_p->>'vehicleOther','') <> ''
                      then v_p->>'vehicleOther' else coalesce(v_p->>'vehicle','') end;
    v_persons := v_persons || jsonb_build_array(jsonb_build_object(
      'party','ฝ่ายที่2','type',coalesce(v_p->>'status','ผู้ขับขี่'),'gender',v_p->>'gender',
      'age',v_p->>'age','injury',v_p->>'injury','safety',v_p->>'safety','vehicle',v_vehicle));
    i := 0;
    for v_pass in select value from jsonb_array_elements(coalesce(v_p->'passengers','[]'::jsonb))
    loop
      i := i + 1;
      v_persons := v_persons || jsonb_build_array(jsonb_build_object(
        'party','ฝ่ายที่2','type','ผู้โดยสารที่'||i,'gender',v_pass->>'gender',
        'age',v_pass->>'age','injury',v_pass->>'injury','safety',v_pass->>'safety','vehicle',v_vehicle));
    end loop;
  end if;

  -- แยกลงตาราง deaths / injuries
  for v_pass in select value from jsonb_array_elements(v_persons)
  loop
    v_injury := coalesce(v_pass->>'injury','');
    if v_injury = 'เสียชีวิต' then
      insert into deaths(incident_datetime, age, gender, status, vehicle_type,
        safety_equipment, road_name, subdistrict, coordinates, cause, col_g)
      values (v_occurred, nullif(v_pass->>'age','')::int, v_pass->>'gender', v_pass->>'type',
        v_pass->>'vehicle', v_pass->>'safety', v_loc->>'road', v_loc->>'subdistrict',
        coalesce(v_loc->>'latitude','')||', '||coalesce(v_loc->>'longitude',''), v_loc->>'cause',
        'เสียชีวิตที่เกิดเหตุ');
    elsif v_injury in ('หมดสติ','สาหัส','เล็กน้อย') then
      insert into injuries(incident_datetime, raw)
      values (v_occurred, jsonb_build_object(
        'severity', v_injury, 'gender', v_pass->>'gender', 'age', v_pass->>'age',
        'vehicle', v_pass->>'vehicle', 'safety', v_pass->>'safety',
        'person_type', v_pass->>'type', 'place', v_loc->>'place', 'road', v_loc->>'road',
        'subdistrict', v_loc->>'subdistrict', 'lat', v_loc->>'latitude', 'lng', v_loc->>'longitude',
        'acc_code', v_code,
        'image_url', coalesce(p_images->>0,'')));
    end if;
  end loop;

  return jsonb_build_object('success',true,'message','บันทึกข้อมูลอุบัติเหตุสำเร็จ',
    'accidentId', v_code, 'imageUrls', coalesce(p_images,'[]'::jsonb));
end $osa$;
-- ============================================================
-- 3) แจ้งผู้เสียชีวิต — เฉพาะที่เสียชีวิตในที่เกิดเหตุ
-- ============================================================
-- เดิมยิงทุกแถวใหม่ใน deaths ซึ่งรวมคนที่ไปเสียชีวิตที่โรงพยาบาลด้วย
-- ข้อมูลจริงมี 30 จาก 91 แถวที่เป็นเสียชีวิตโรงพยาบาล คือหนึ่งในสาม
--
-- เข้มไว้ก่อน: ส่งเฉพาะแถวที่เขียนว่า "เสียชีวิตที่เกิดเหตุ" ตรงตัวเท่านั้น
-- แถวที่ค่ายังว่าง (เช่นกรอกฟอร์มแล้วไม่ได้เลือกช่องอาการ) จะไม่ส่ง
-- แจ้งขาดยังตามเก็บทีหลังได้ แต่แจ้งผิดว่าตายคาที่เรียกคืนไม่ได้
--
-- แถวที่ไม่เข้าเงื่อนไขถูกหมายว่า "จัดการแล้ว" ทันที
-- ไม่งั้น cron จะวนอ่านแถวเดิมทุก 5 นาทีไปตลอดกาล
create or replace function line_send_new_deaths(p_max int default 3)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $line_send_new_deaths$
declare
  d record; v_sent int := 0; v_skip int := 0; v_left int; v_txt text;
begin
  select count(*) into v_left from deaths d
   where not exists (select 1 from line_sent s where s.kind = 'death' and s.ref_id = d.id::text);

  if v_left = 0 then return jsonb_build_object('success', true, 'sent', 0, 'left', 0); end if;

  for d in
    select id, col_g from deaths d2
     where not exists (select 1 from line_sent s where s.kind = 'death' and s.ref_id = d2.id::text)
     order by incident_datetime desc nulls last, id desc
     limit greatest(1, p_max)
  loop
    if coalesce(btrim(d.col_g), '') <> 'เสียชีวิตที่เกิดเหตุ' then
      insert into line_sent (kind, ref_id, target_id, ok, detail)
      values ('death', d.id::text, 'SKIP', true,
              'ไม่ได้เสียชีวิตในที่เกิดเหตุ (' || coalesce(nullif(btrim(d.col_g), ''), 'ไม่ระบุ') || ')')
      on conflict do nothing;
      v_skip := v_skip + 1;
      continue;
    end if;

    v_txt := line_msg_death(d.id);
    if v_txt is not null then
      perform line_broadcast('death', v_txt, d.id::text);
      v_sent := v_sent + 1;
    else
      insert into line_sent (kind, ref_id, target_id, ok, detail)
      values ('death', d.id::text, 'ERROR', false, 'สร้างข้อความไม่ได้')
      on conflict do nothing;
    end if;
  end loop;

  return jsonb_build_object('success', true, 'sent', v_sent, 'skipped', v_skip, 'left', v_left);
end $line_send_new_deaths$;

revoke execute on function line_send_new_deaths(int) from public, anon, authenticated;

-- ============================================================
-- 4) จุดสะสมอุบัติเหตุรายเดือน — ช่องกว้าง 100 ม.
-- ============================================================
-- นับตั้งแต่วันที่ 1 ของเดือนตามปฏิทิน พอขึ้นเดือนใหม่เริ่มนับใหม่จากศูนย์
-- ทำได้เองโดยไม่ต้องล้างอะไร เพราะกุญแจกันส่งซ้ำมีเดือนอยู่ในตัว
-- เดือนใหม่ = กุญแจใหม่ = จุดเดิมแจ้งได้อีกครั้ง
--
-- เรื่องเกณฑ์ "สีแดงเข้ม"
--   สีบนแผนที่ไล่จากช่องที่หนาที่สุดในภาพนั้น ไม่ใช่จากจำนวนตายตัว
--   ต้นเดือนที่มีอุบัติเหตุจุดละครั้งเดียว ทุกช่องจะเป็นแดงเข้มพร้อมกันหมด
--   เอามาใช้เป็นเกณฑ์แจ้งเตือนตรง ๆ ไม่ได้ จะเด้งรัวทุกวันที่ 1
--   จึงใช้จำนวนครั้งตายตัวแทน แก้ตัวเลขได้ที่ bs_settings คีย์ hotspotMinPerMonth
--
--   วัดจากของจริง: เดือน ส.ค. 2569 มี 55 อุบัติเหตุ ช่องหนาสุดได้ 3 ครั้ง
--   ตั้งไว้ที่ 4 คือสูงกว่าที่เคยเกิดจริงในเดือนนี้หนึ่งขั้น
--   จุดที่ถึงเกณฑ์จึงเป็นจุดที่หนักผิดปกติจริง ๆ ไม่ใช่จุดที่บังเอิญมีรถชนสองสามครั้ง
--
-- on conflict do nothing — รันไฟล์ซ้ำจะไม่ทับค่าที่ปรับด้วยมือไว้แล้ว
-- อยากเปลี่ยนทีหลังใช้ update ตามท้ายไฟล์
insert into bs_settings(key, val) values ('hotspotMinPerMonth', '4'::jsonb)
on conflict (key) do nothing;

create or replace function line_send_hotspots()
returns jsonb
language plpgsql security definer set search_path = public, extensions as $line_send_hotspots$
declare
  v_from timestamptz;
  v_to   timestamptz;
  v_min  int;
  v_edge float8 := 100.0 / sqrt(3.0);   -- ช่องกว้าง 100 ม. = ด้านราว 58 ม.
  v_month text;
  v_bounds geometry;
  c record;
  v_txt text;
  v_sent int := 0;
  v_found int := 0;
begin
  v_min  := coalesce((select (val#>>'{}')::int from bs_settings where key = 'hotspotMinPerMonth'), 4);
  v_from := date_trunc('month', timezone('Asia/Bangkok', now()));
  v_to   := now();
  v_month := to_char(v_from, 'YYYY-MM');

  create temporary table if not exists tmp_hot_pt (g geometry) on commit drop;
  truncate tmp_hot_pt;

  insert into tmp_hot_pt (g)
  select st_transform(st_setsrid(st_makepoint(a.longitude, a.latitude), 4326), 32647)
  from accidents a
  where a.latitude is not null and a.longitude is not null
    and a.latitude between 14 and 17 and a.longitude between 99 and 101
    and a.incident_datetime >= v_from and a.incident_datetime < v_to;

  if not exists (select 1 from tmp_hot_pt) then
    return jsonb_build_object('success', true, 'month', v_month, 'found', 0, 'sent', 0);
  end if;

  -- index เหมือน geo_density ไม่งั้นช่องเล็กขนาดนี้จะ timeout
  create index if not exists tmp_hot_pt_gix on tmp_hot_pt using gist (g);
  analyze tmp_hot_pt;

  select st_setsrid(st_expand(st_extent(g)::geometry, v_edge * 2), 32647)
    into v_bounds from tmp_hot_pt;

  for c in
    with cells as (select h.geom from st_hexagongrid(v_edge, v_bounds) h),
    agg as (
      select cl.geom, count(*)::int as n
        from cells cl join tmp_hot_pt p on st_intersects(cl.geom, p.g)
       group by cl.geom having count(*) >= v_min
    )
    select a.n,
           st_y(st_transform(st_centroid(a.geom), 4326)) as lat,
           st_x(st_transform(st_centroid(a.geom), 4326)) as lng
      from agg a order by a.n desc
  loop
    v_found := v_found + 1;
    v_txt := array_to_string(array[
      '🔴 จุดสะสมอุบัติเหตุ ประจำเดือน',
      line_thai_date(v_from) || ' ถึงวันนี้',
      '',
      'พบจุดที่เกิดอุบัติเหตุซ้ำในบริเวณเดียวกัน',
      '🔢 ' || c.n || ' ครั้ง ในรัศมีราว 100 เมตร',
      '🗺️ https://www.google.com/maps?q=' || round(c.lat::numeric, 6) || ',' || round(c.lng::numeric, 6),
      '',
      'นับใหม่ทุกวันที่ 1 ของเดือน'
    ], chr(10));

    -- กุญแจกันส่งซ้ำ = เดือน + พิกัดกลางช่องปัด 4 ตำแหน่ง (ราว 11 ม.)
    -- ปัดเพื่อให้ค่าเดิมทุกรอบ ไม่งั้นทศนิยมขยับนิดเดียวก็กลายเป็นจุดใหม่แล้วส่งซ้ำ
    if line_broadcast('hotspot', v_txt,
         v_month || ':' || round(c.lat::numeric, 4) || ',' || round(c.lng::numeric, 4)) > 0 then
      v_sent := v_sent + 1;
    end if;
  end loop;

  return jsonb_build_object('success', true, 'month', v_month,
    'min_per_cell', v_min, 'found', v_found, 'sent', v_sent);
end $line_send_hotspots$;

revoke execute on function line_send_hotspots() from public, anon, authenticated;

-- ============================================================
-- 5) ตั้งเวลาเดิน
-- ============================================================
-- ผู้เสียชีวิต: ทุก 5 นาทีตามเดิม ตารางเดิมยังอยู่ ไม่ต้องตั้งใหม่
--
-- จุดสะสม: ทุก 5 นาทีเช่นกัน — แจ้งทันทีที่จุดไหนถึงเกณฑ์ ไม่รอรอบเช้า
--   เดินถี่แบบนี้ไม่ได้ส่งถี่ตาม เพราะกุญแจกันส่งซ้ำคุมไว้อยู่
--   จุดหนึ่งในเดือนหนึ่งส่งได้ครั้งเดียว รอบที่เหลือเจอแล้วเงียบ
--
--   ราคาที่จ่ายคือคิวรีทุก 5 นาที ซึ่งเบามาก เพราะนับเฉพาะเดือนปัจจุบัน
--   เดือนนี้มี 55 จุด ไม่ใช่พันกว่าจุดแบบหน้าแผนที่ทั้งปี
--   และมี index บนตารางชั่วคราวเหมือน geo_density
--
-- ถอนของเดิมก่อนถ้ามี ใช้ท่าเดียวกับ line_6_no_daily.sql ที่รันผ่านมาแล้ว
-- คืน 0 แถวถ้ายังไม่เคยตั้ง ไม่ error
select cron.unschedule(jobname) from cron.job where jobname = 'line-hotspot';
select cron.schedule('line-hotspot', '*/5 * * * *', 'select line_send_hotspots();');

-- ============================================================
-- ตรวจผลหลังรัน
-- ============================================================
-- ปลายทางที่จะได้รับ ต้องเป็น group เท่านั้น
--   select label, target_type, enabled from line_targets order by target_type;
--
-- อุบัติเหตุที่บันทึกใหม่ต้องมี col_g ติดมาแล้ว
--   select id, incident_datetime, col_g from deaths order by id desc limit 5;
--
-- ดูว่าข้ามใครไปเพราะไม่ได้เสียชีวิตในที่เกิดเหตุ
--   select ref_id, detail, sent_at from line_sent
--    where kind = 'death' and target_id = 'SKIP' order by sent_at desc limit 10;
--
-- งาน cron ที่เดินอยู่ — line-hotspot กับ line-new-deaths ต้องเป็น */5 * * * *
--   select jobname, schedule, active from cron.job order by jobname;
--
-- เปลี่ยนเกณฑ์จุดสะสมทีหลัง (มีผลรอบถัดไปทันที ไม่ต้องรันไฟล์ใหม่)
--   update bs_settings set val = '3'::jsonb, updated_at = now() where key = 'hotspotMinPerMonth';
--
-- *** ระวัง: คำสั่งข้างล่างส่งเข้าไลน์จริง ไม่ใช่การทดลอง ***
--   select line_send_hotspots();
