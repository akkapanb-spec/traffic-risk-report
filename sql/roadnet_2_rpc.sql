-- ============================================================
-- โครงข่ายถนน - RPC ถนนและช่วงถนน (ส่วนที่ 2 ของ 3)
-- ============================================================
-- ต้องรัน roadnet_1_tables.sql ก่อน และต้องมี admin_check_ จาก deaths_admin.sql
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
-- ถ้าบรรทัดแรกเป็นข้อความไทยลอย ๆ แปลว่า paste ขาดหัว ให้วางใหม่
--
-- หมายเหตุเรื่องระบบพิกัด: การวัดระยะตามแนวถนนทำบน EPSG:32647 (UTM 47N)
-- ซึ่งครอบคลุมนครสวรรค์ หน่วยเป็นเมตรและเป็นระนาบ จึงตัดช่วงถนนและวัด
-- ระยะสะสมได้ตรง ถ้าคำนวณบน 4326 ตรง ๆ หน่วยจะเป็นองศาและเพี้ยนราว 4%
-- เพราะองศาลองจิจูดที่ละติจูด 15.7 สั้นกว่าองศาละติจูด
-- ============================================================

set search_path = public, extensions;

-- ============================================================
-- ตัวช่วย: แปลง jsonb [[lat,lng],...] เป็นเส้น
-- ============================================================
create or replace function rn_line_from_json(p_coords jsonb)
returns geography language sql immutable as $$
  select case when jsonb_array_length(coalesce(p_coords,'[]'::jsonb)) < 2 then null
    else st_setsrid(st_makeline(array(
      select st_makepoint((c->>1)::float8, (c->>0)::float8)
      from jsonb_array_elements(p_coords) c
    )), 4326)::geography end;
$$;

-- ตัวช่วย: แปลงเส้นกลับเป็น jsonb [[lat,lng],...] ให้ฝั่งเว็บวาดบน Leaflet
create or replace function rn_line_to_json(p_line geography)
returns jsonb language sql immutable as $$
  select case when p_line is null then null else (
    select coalesce(jsonb_agg(jsonb_build_array(st_y(p), st_x(p)) order by n), '[]'::jsonb)
    from (select (dp).geom p, (dp).path[1] n
          from (select st_dumppoints(p_line::geometry) dp) d) q
  ) end;
$$;

-- ============================================================
-- โหลดข้อมูลทั้งหมดสำหรับหน้าจัดการ
-- ============================================================
create or replace function rn_admin_data(p_token text) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare v_err jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;

  return jsonb_build_object('success', true,
    'roads', coalesce((select jsonb_agg(to_jsonb(x) order by x.name)
      from (select r.id, r.name, r.code, r.highway_type, r.subdistrict, r.local_authority,
                   r.in_municipality, r.start_name, r.end_name, r.length_km, r.direction_mode,
                   r.dir_a_label, r.dir_b_label, r.has_median, r.lanes, r.speed_limit, r.note,
                   rn_line_to_json(r.center_line) as line,
                   (select count(*) from rn_segments s where s.road_id = r.id) as segment_count
            from rn_roads r) x), '[]'::jsonb),
    'segments', coalesce((select jsonb_agg(to_jsonb(x) order by x.road_id, x.seq)
      from (select s.id, s.road_id, s.seq, s.code, s.start_m, s.end_m, s.length_m,
                   s.mid_lat, s.mid_lng, s.acc_count, s.fatal_count, s.drunk_count
            from rn_segments s) x), '[]'::jsonb),
    'places', coalesce((select jsonb_agg(to_jsonb(x) order by x.kind, x.name)
      from (select p.id, p.kind, p.name, p.road_id, p.segment_id, p.subdistrict, p.in_municipality,
                   p.latitude, p.longitude, p.side, p.risk_level, p.open_hours, p.student_count, p.note
            from rn_places p) x), '[]'::jsonb));
end $$;

-- ============================================================
-- บันทึกถนน - p_row.line เป็น [[lat,lng],...] จากที่วาดบนแผนที่
--   length_km คำนวณจากเส้น ไม่รับค่าที่ผู้ใช้กรอก จะได้ไม่ขัดกับแนวจริง
-- ============================================================
create or replace function rn_road_save(p_token text, p_id bigint, p_row jsonb) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare v_err jsonb; v_user jsonb; v_id bigint; v_line geography; v_km numeric;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  v_user := officer_session_user(p_token);

  if coalesce(p_row->>'name','') = '' then
    return jsonb_build_object('success', false, 'message', 'กรุณากรอกชื่อถนน');
  end if;

  v_line := rn_line_from_json(p_row->'line');
  if v_line is null then
    return jsonb_build_object('success', false, 'message', 'กรุณาวาดแนวกลางถนนอย่างน้อย 2 จุดบนแผนที่');
  end if;
  v_km := round((st_length(v_line) / 1000.0)::numeric, 3);

  if p_id is null then
    insert into rn_roads(name, code, highway_type, subdistrict, local_authority, in_municipality,
      center_line, start_name, end_name, length_km, direction_mode, dir_a_label, dir_b_label,
      has_median, lanes, speed_limit, note, created_by)
    values (p_row->>'name', nullif(p_row->>'code',''), nullif(p_row->>'highway_type',''),
      nullif(p_row->>'subdistrict',''), nullif(p_row->>'local_authority',''),
      coalesce((p_row->>'in_municipality')::boolean, false),
      v_line, nullif(p_row->>'start_name',''), nullif(p_row->>'end_name',''), v_km,
      coalesce(nullif(p_row->>'direction_mode',''), 'two_way'),
      coalesce(nullif(p_row->>'dir_a_label',''), 'ขาเข้าเมือง'),
      coalesce(nullif(p_row->>'dir_b_label',''), 'ขาออกเมือง'),
      coalesce((p_row->>'has_median')::boolean, false),
      nullif(p_row->>'lanes','')::int, nullif(p_row->>'speed_limit','')::int,
      nullif(p_row->>'note',''),
      (v_user->>'rank') || ' ' || (v_user->>'firstName') || ' ' || (v_user->>'lastName'))
    returning id into v_id;
  else
    update rn_roads set
      name = p_row->>'name', code = nullif(p_row->>'code',''),
      highway_type = nullif(p_row->>'highway_type',''),
      subdistrict = nullif(p_row->>'subdistrict',''),
      local_authority = nullif(p_row->>'local_authority',''),
      in_municipality = coalesce((p_row->>'in_municipality')::boolean, false),
      center_line = v_line, start_name = nullif(p_row->>'start_name',''),
      end_name = nullif(p_row->>'end_name',''), length_km = v_km,
      direction_mode = coalesce(nullif(p_row->>'direction_mode',''), 'two_way'),
      dir_a_label = coalesce(nullif(p_row->>'dir_a_label',''), 'ขาเข้าเมือง'),
      dir_b_label = coalesce(nullif(p_row->>'dir_b_label',''), 'ขาออกเมือง'),
      has_median = coalesce((p_row->>'has_median')::boolean, false),
      lanes = nullif(p_row->>'lanes','')::int, speed_limit = nullif(p_row->>'speed_limit','')::int,
      note = nullif(p_row->>'note',''), updated_at = now()
     where id = p_id
    returning id into v_id;
    if v_id is null then return jsonb_build_object('success', false, 'message', 'ไม่พบถนนที่ต้องการแก้ไข'); end if;
  end if;

  return jsonb_build_object('success', true, 'id', v_id, 'lengthKm', v_km,
    'message', 'บันทึกถนนแล้ว ระยะทาง ' || v_km || ' กม.');
end $$;

create or replace function rn_road_delete(p_token text, p_id bigint) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare v_err jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  delete from rn_roads where id = p_id;
  return jsonb_build_object('success', true, 'message', 'ลบถนนและช่วงถนนทั้งหมดของสายนี้แล้ว');
end $$;

-- ============================================================
-- ตัดถนนเป็นช่วง - หัวใจของโครงข่าย
--   เลือกจำนวนช่วงให้ความยาวต่อช่วงใกล้ค่าเป้าหมายที่สุด แล้วหารเท่า ๆ กัน
--   จึงไม่มีช่วงสุดท้ายสั้นกระเผลก และทุกช่วงยาวเท่ากันทั้งสาย
--   p_road_id = null คือตัดใหม่ทั้งระบบ
-- ============================================================
create or replace function rn_resegment(p_token text, p_road_id bigint, p_target_m numeric)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_err jsonb; r record; v_line geometry; v_len numeric; v_n int; v_seg_len numeric;
  v_target numeric; v_sub geometry; v_mid geometry; v_code text; i int;
  v_roads int := 0; v_segs int := 0;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;

  v_target := coalesce(p_target_m, (select (val#>>'{}')::numeric from bs_settings where key = 'segmentTargetM'), 200);
  if v_target < 50 then v_target := 50; end if;
  if v_target > 1000 then v_target := 1000; end if;

  for r in select * from rn_roads
            where center_line is not null and (p_road_id is null or id = p_road_id)
  loop
    delete from rn_segments where road_id = r.id;

    v_line := st_transform(r.center_line::geometry, 32647);   -- UTM 47N หน่วยเมตร
    v_len  := st_length(v_line);
    if v_len < 1 then continue; end if;

    v_n := greatest(1, round(v_len / v_target)::int);
    v_seg_len := v_len / v_n;

    for i in 1..v_n loop
      v_sub := st_linesubstring(v_line, ((i-1)::numeric / v_n)::float8, (i::numeric / v_n)::float8);
      v_mid := st_transform(st_lineinterpolatepoint(v_sub, 0.5), 4326);
      v_code := upper(regexp_replace(coalesce(nullif(r.code,''), r.name), '[^0-9A-Za-z]', '', 'g'));
      v_code := coalesce(nullif(left(v_code, 10), ''), 'RD' || r.id) || '-' || lpad(i::text, 3, '0');

      insert into rn_segments(road_id, seq, code, geom, start_m, end_m, length_m, mid_lat, mid_lng)
      values (r.id, i, v_code,
        st_transform(v_sub, 4326)::geography,
        round(((i-1) * v_seg_len)::numeric, 1), round((i * v_seg_len)::numeric, 1),
        round(v_seg_len::numeric, 1), st_y(v_mid), st_x(v_mid));
      v_segs := v_segs + 1;
    end loop;
    v_roads := v_roads + 1;
  end loop;

  return jsonb_build_object('success', true, 'roads', v_roads, 'segments', v_segs,
    'message', 'ตัดช่วงถนนแล้ว ' || v_roads || ' สาย รวม ' || v_segs || ' ช่วง (ช่วงละประมาณ ' || round(v_target) || ' ม.)');
end $$;

-- ============================================================
-- จับจุดเข้าถนน - ตัวเชื่อมระหว่างข้อมูลอุบัติเหตุกับโครงข่าย
--   รับ [[lat,lng],...] คืนถนน ช่วงถนน และระยะสะสมจากต้นถนนของแต่ละจุด
--   ฝั่งเว็บเอา offset_m ไปลบกันตรง ๆ ได้ระยะทางตามถนนจริง
--   จุดที่ไกลเกิน snapRadiusM คืน null ให้ฝั่งเว็บถอยไปใช้เส้นตรงแทน
-- ============================================================
create or replace function rn_locate(p_token text, p_points jsonb) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare v_user jsonb; v_radius numeric; v_out jsonb;
begin
  -- เจ้าหน้าที่ทุกคนเรียกได้ ไม่ต้องเป็น admin เพราะเป็นแค่การอ่านเพื่อวิเคราะห์
  v_user := officer_session_user(p_token);
  if v_user is null then
    return jsonb_build_object('success', false, 'code', 'AUTH_REQUIRED', 'message', 'กรุณาเข้าสู่ระบบใหม่');
  end if;

  v_radius := coalesce((select (val#>>'{}')::numeric from bs_settings where key = 'snapRadiusM'), 60);

  select coalesce(jsonb_agg(to_jsonb(q) order by q.i), '[]'::jsonb) into v_out
  from (
    select p.i,
           m.road_id, m.road_name, m.in_municipality, m.direction_mode,
           m.segment_id, m.segment_code, m.offset_m, m.dist_m
    from (select (row_number() over ())::int - 1 as i,
                 st_setsrid(st_makepoint((c->>1)::float8, (c->>0)::float8), 4326)::geography as g
          from jsonb_array_elements(p_points) c) p
    left join lateral (
      select r.id as road_id, r.name as road_name, r.in_municipality, r.direction_mode,
             s.id as segment_id, s.code as segment_code,
             round(st_distance(p.g, r.center_line)::numeric, 1) as dist_m,
             round((st_linelocatepoint(st_transform(r.center_line::geometry, 32647),
                                       st_transform(p.g::geometry, 32647))
                    * st_length(st_transform(r.center_line::geometry, 32647)))::numeric, 1) as offset_m
        from rn_roads r
        left join lateral (
          select s2.id, s2.code from rn_segments s2
           where s2.road_id = r.id
           order by s2.geom <-> p.g limit 1
        ) s on true
       where r.center_line is not null
         and st_dwithin(p.g, r.center_line, v_radius)
       order by st_distance(p.g, r.center_line)
       limit 1
    ) m on true
  ) q;

  return jsonb_build_object('success', true, 'radiusM', v_radius, 'points', v_out);
end $$;

-- ============================================================
-- จับ bs_features เข้าโครงข่ายทีเดียวทั้งตาราง
--   เก็บ offset_m ไว้เลย เกณฑ์ข้อ 1 จะได้ลบกับ offset ของจุดเกิดเหตุได้ทันที
-- ============================================================
create or replace function rn_snap_features(p_token text) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare v_err jsonb; v_radius numeric; v_hit int := 0; v_miss int := 0;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;

  v_radius := coalesce((select (val#>>'{}')::numeric from bs_settings where key = 'snapRadiusM'), 60);

  update bs_features f set road_id = m.road_id, segment_id = m.segment_id, offset_m = m.offset_m
    from (
      select f2.id,
             m2.road_id, m2.segment_id, m2.offset_m
        from bs_features f2
        left join lateral (
          select r.id as road_id,
                 (select s.id from rn_segments s where s.road_id = r.id
                   order by s.geom <-> f2.geom limit 1) as segment_id,
                 round((st_linelocatepoint(st_transform(r.center_line::geometry, 32647),
                                           st_transform(f2.geom::geometry, 32647))
                        * st_length(st_transform(r.center_line::geometry, 32647)))::numeric, 1) as offset_m
            from rn_roads r
           where r.center_line is not null and st_dwithin(f2.geom, r.center_line, v_radius)
           order by st_distance(f2.geom, r.center_line)
           limit 1
        ) m2 on true
       where f2.geom is not null
    ) m
   where f.id = m.id;

  select count(*) filter (where road_id is not null), count(*) filter (where road_id is null)
    into v_hit, v_miss from bs_features where geom is not null;

  return jsonb_build_object('success', true, 'matched', v_hit, 'unmatched', v_miss,
    'message', 'จับจุดกายภาพเข้าถนนแล้ว ' || v_hit || ' จุด · ไม่พบถนนในระยะ ' || v_radius || ' ม. อีก ' || v_miss || ' จุด');
end $$;

-- ============================================================
-- ปิดการเรียกตรงจากคนทั่วไป ทุกตัวตรวจ token อยู่แล้วแต่กันไว้อีกชั้น
-- ============================================================
revoke execute on function rn_road_save(text, bigint, jsonb) from public;
revoke execute on function rn_road_delete(text, bigint) from public;
revoke execute on function rn_resegment(text, bigint, numeric) from public;
revoke execute on function rn_snap_features(text) from public;

grant execute on function rn_admin_data(text) to anon, authenticated;
grant execute on function rn_road_save(text, bigint, jsonb) to anon, authenticated;
grant execute on function rn_road_delete(text, bigint) to anon, authenticated;
grant execute on function rn_resegment(text, bigint, numeric) to anon, authenticated;
grant execute on function rn_locate(text, jsonb) to anon, authenticated;
grant execute on function rn_snap_features(text) to anon, authenticated;
