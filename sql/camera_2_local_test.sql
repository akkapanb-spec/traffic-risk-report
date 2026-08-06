-- ============================================================
-- ยอมให้ที่อยู่เกตเวย์เป็น http ได้ เมื่อเป็นเครื่องในวง LAN
-- ============================================================
-- ต้องรัน camera_1_tables.sql ก่อน
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
--
-- ของเดิมบังคับ https:// ทุกกรณี ซึ่งถูกสำหรับหน้าเว็บบน GitHub Pages
-- เพราะหน้า https จะบล็อกสตรีม http ทิ้งเงียบ ๆ ได้จอดำโดยไม่มีอะไรใน console
--
-- แต่ตอนทดสอบในเครื่อง หน้าเว็บเปิดจาก http://localhost:3000 ซึ่งเป็น http เหมือนกัน
-- จึงไม่มีปัญหา mixed content และไม่ควรถูกห้ามบันทึก
--
-- ผ่อนเฉพาะปลายทางที่เป็นเครื่องในวงเท่านั้น localhost 127.x 10.x 172.16-31.x 192.168.x
-- ที่อยู่สาธารณะยังบังคับ https เหมือนเดิม เพราะภาพกล้องวิ่งข้ามอินเทอร์เน็ตแบบไม่เข้ารหัสไม่ได้
-- ============================================================

set search_path = public, extensions;

create or replace function cam_save(p_token text, p_id bigint, p_row jsonb)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare v_err jsonb; v_id bigint; v_gw text; v_host text; v_local boolean;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;

  if nullif(btrim(coalesce(p_row->>'name','')), '') is null then
    return jsonb_build_object('success', false, 'message', 'ยังไม่ได้ใส่ชื่อกล้อง');
  end if;
  if nullif(btrim(coalesce(p_row->>'path_wide','')), '') is null then
    return jsonb_build_object('success', false, 'message', 'ยังไม่ได้ใส่ชื่อสตรีม');
  end if;

  v_gw := regexp_replace(btrim(coalesce(p_row->>'gateway_url','')), '/+$', '');

  -- ตัดโปรโตคอลกับพอร์ตออก เหลือแต่ชื่อโฮสต์ไว้ตรวจ
  v_host := split_part(regexp_replace(v_gw, '^https?://', ''), ':', 1);
  v_local := v_host = 'localhost'
          or v_host ~ '^127\.'
          or v_host ~ '^10\.'
          or v_host ~ '^192\.168\.'
          or v_host ~ '^172\.(1[6-9]|2[0-9]|3[01])\.';

  if v_gw !~ '^https://' and not (v_gw ~ '^http://' and v_local) then
    return jsonb_build_object('success', false,
      'message', 'ที่อยู่เกตเวย์ต้องขึ้นต้นด้วย https:// ไม่งั้นเบราว์เซอร์จะบล็อกภาพทิ้ง (ยกเว้นเครื่องในวง LAN ใช้ http:// ได้)');
  end if;

  if p_id is null then
    insert into cam_sources (name, place, subdistrict, latitude, longitude,
                             gateway_url, path_wide, path_zoom, active, sort_order, note)
    values (p_row->>'name', p_row->>'place', p_row->>'subdistrict',
            nullif(p_row->>'latitude','')::double precision,
            nullif(p_row->>'longitude','')::double precision,
            v_gw, p_row->>'path_wide', nullif(p_row->>'path_zoom',''),
            coalesce((p_row->>'active')::boolean, true),
            coalesce((p_row->>'sort_order')::int, 0), p_row->>'note')
    returning id into v_id;
  else
    update cam_sources set
      name = p_row->>'name', place = p_row->>'place', subdistrict = p_row->>'subdistrict',
      latitude = nullif(p_row->>'latitude','')::double precision,
      longitude = nullif(p_row->>'longitude','')::double precision,
      gateway_url = v_gw, path_wide = p_row->>'path_wide',
      path_zoom = nullif(p_row->>'path_zoom',''),
      active = coalesce((p_row->>'active')::boolean, true),
      sort_order = coalesce((p_row->>'sort_order')::int, 0),
      note = p_row->>'note', updated_at = now()
    where id = p_id
    returning id into v_id;
    if v_id is null then
      return jsonb_build_object('success', false, 'message', 'ไม่พบกล้องนี้');
    end if;
  end if;

  return jsonb_build_object('success', true, 'message', 'บันทึกแล้ว', 'id', v_id);
end $$;

grant execute on function cam_save(text, bigint, jsonb) to anon, authenticated;

-- ============================================================
-- ตรวจผลหลังรัน
-- ============================================================
-- ควรผ่าน:   http://localhost:8888 · http://192.168.1.50:8888 · https://cctv.go.th:8888
-- ควรไม่ผ่าน: http://cctv.go.th:8888
