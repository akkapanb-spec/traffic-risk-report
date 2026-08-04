-- ============================================================
-- วิเคราะห์จุดเสี่ยงอุบัติเหตุ - RPC บันทึกและเผยแพร่ผล
-- ============================================================
-- ส่วนที่ 4 ของ 4 - รันเรียงตามลำดับใน Supabase SQL Editor
-- ต้องรันส่วนที่ 1-3 ก่อน
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
-- ถ้าบรรทัดแรกเป็นข้อความไทยลอย ๆ แปลว่า paste ขาดหัว ให้วางใหม่
-- ============================================================

-- ============================================================
-- บันทึกผลการวิเคราะห์ทั้งชุด
--   - ล้างผลอัตโนมัติของรอบก่อน (source='auto') แล้วใส่ชุดใหม่
--   - โซนที่ admin วาดเอง (source='manual') ไม่ถูกแตะต้อง
--   - p_publish = true คือให้ขึ้นหน้าประชาชนทันที
-- ============================================================
create or replace function bs_publish(p_token text, p_run jsonb, p_sites jsonb, p_zones jsonb, p_publish boolean)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_err jsonb; v_user jsonb; v_run_id bigint; r jsonb;
  v_pub boolean := coalesce(p_publish, false);
  v_start date; v_end date; v_sites int := 0; v_zones int := 0;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  v_user := officer_session_user(p_token);

  v_start := nullif(p_run->>'period_start','')::date;
  v_end   := nullif(p_run->>'period_end','')::date;

  insert into bs_runs(ran_by, as_of, period_start, period_end, settings, totals, published)
  values ((v_user->>'rank') || ' ' || (v_user->>'firstName') || ' ' || (v_user->>'lastName'),
          nullif(p_run->>'as_of','')::date, v_start, v_end,
          p_run->'settings', p_run->'totals', v_pub)
  returning id into v_run_id;

  -- ผลรอบก่อนถูกแทนที่ทั้งหมด (จุดเสี่ยงเป็นภาพรวม ณ รอบวิเคราะห์ ไม่สะสม)
  delete from bs_sites;
  delete from bs_zones where source = 'auto';

  for r in select value from jsonb_array_elements(coalesce(p_sites, '[]'::jsonb))
  loop
    insert into bs_sites(run_id, rule, kind, title, latitude, longitude, road, subdistrict,
      in_municipality, radius_m, acc_count, fatal_count, injury_count, drunk_count, month_count,
      score, level, confirmed, peak, members, period_start, period_end, published)
    values (v_run_id, coalesce(r->>'rule','corridor'), r->>'kind', coalesce(r->>'title','จุดเสี่ยง'),
      (r->>'latitude')::double precision, (r->>'longitude')::double precision,
      r->>'road', r->>'subdistrict', (r->>'in_municipality')::boolean,
      coalesce((r->>'radius_m')::int, 0),
      coalesce((r->>'acc_count')::int, 0), coalesce((r->>'fatal_count')::int, 0),
      coalesce((r->>'injury_count')::int, 0), coalesce((r->>'drunk_count')::int, 0),
      coalesce((r->>'month_count')::int, 0),
      (r->>'score')::numeric, r->>'level', coalesce((r->>'confirmed')::boolean, false),
      r->'peak', r->'members', v_start, v_end, v_pub);
    v_sites := v_sites + 1;
  end loop;

  for r in select value from jsonb_array_elements(coalesce(p_zones, '[]'::jsonb))
  loop
    insert into bs_zones(run_id, source, level, title, polygon, corridor, centroid_lat, centroid_lng,
      point_count, fatal_count, month_count, area_km2, peak, note, period_start, period_end, published, created_by)
    values (v_run_id, 'auto', coalesce(r->>'level','red'), coalesce(r->>'title','โซนเสี่ยง'),
      coalesce(r->'polygon', '[]'::jsonb), r->'corridor',
      (r->>'centroid_lat')::double precision, (r->>'centroid_lng')::double precision,
      coalesce((r->>'point_count')::int, 0), coalesce((r->>'fatal_count')::int, 0),
      coalesce((r->>'month_count')::int, 0), (r->>'area_km2')::numeric,
      r->'peak', r->>'note', v_start, v_end, v_pub,
      (v_user->>'rank') || ' ' || (v_user->>'firstName') || ' ' || (v_user->>'lastName'));
    v_zones := v_zones + 1;
  end loop;

  return jsonb_build_object('success', true, 'runId', v_run_id, 'sites', v_sites, 'zones', v_zones,
    'message', case when v_pub
      then 'บันทึกและเผยแพร่แล้ว — จุดเสี่ยง ' || v_sites || ' จุด, โซน ' || v_zones || ' โซน'
      else 'บันทึกเป็นฉบับร่างแล้ว — จุดเสี่ยง ' || v_sites || ' จุด, โซน ' || v_zones || ' โซน (ยังไม่ขึ้นหน้าประชาชน)' end);
end $$;

-- เผยแพร่/ถอนเผยแพร่ผลรอบล่าสุดทั้งชุด
create or replace function bs_set_published(p_token text, p_published boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb; v_pub boolean := coalesce(p_published, false);
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  update bs_sites set published = v_pub;
  update bs_zones set published = v_pub where source = 'auto';
  update bs_runs set published = v_pub
   where id = (select id from bs_runs order by ran_at desc limit 1);
  return jsonb_build_object('success', true,
    'message', case when v_pub then 'เผยแพร่ผลวิเคราะห์ขึ้นหน้าประชาชนแล้ว' else 'ถอนผลวิเคราะห์ออกจากหน้าประชาชนแล้ว' end);
end $$;

-- ป้องกันการเรียกตรงจากคนทั่วไป (ทุกตัวตรวจ token อยู่แล้ว แต่กันไว้อีกชั้น)
revoke execute on function bs_publish(text, jsonb, jsonb, jsonb, boolean) from public;
revoke execute on function bs_set_published(text, boolean) from public;
grant execute on function bs_publish(text, jsonb, jsonb, jsonb, boolean) to anon, authenticated;
grant execute on function bs_set_published(text, boolean) to anon, authenticated;
