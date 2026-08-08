-- ============================================================
-- ส่งรหัส/มาตรา/ค่าปรับ ของข้อหากลับไปให้หน้าเว็บด้วย
-- ============================================================
-- ต้องรัน checkpoint_2_rpc.sql และ checkpoint_3_ptm_charges.sql มาก่อน
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
--
-- cp_list เขียนไว้ตั้งแต่ตอนที่ cp_charges มีแค่ชื่อกับกลุ่ม
--   select name, grp, sort_order from cp_charges
-- พอ checkpoint_3 เพิ่มคอลัมน์ code / section / fine / common เข้ามา
-- ฟังก์ชันนี้ก็ยังส่งกลับเท่าเดิม หน้าเว็บจึงไม่มีข้อมูลจะเอาไปแสดง
-- ทั้งที่ในตารางมีครบ เช่นข้อหาสายรัดคางมี 10375 / ม.148,122 ว.3 / 400 บาท
--
-- ไฟล์นี้แก้เฉพาะรายการ column ที่ส่งกลับ ตรรกะอื่นเหมือนเดิมทุกอย่าง
-- ============================================================

set search_path = public, extensions;

create or replace function cp_list(p_token text, p_from date, p_to date) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_user jsonb;
begin
  v_user := officer_session_user(p_token);
  if v_user is null then
    return jsonb_build_object('success', false, 'code', 'AUTH_REQUIRED', 'message', 'กรุณาเข้าสู่ระบบใหม่');
  end if;

  return jsonb_build_object('success', true,
    'isAdmin', coalesce((v_user->>'isAdmin')::boolean, false),
    -- เพิ่ม code / section / fine / common ตรงนี้ คือทั้งหมดที่ไฟล์นี้แก้
    'charges', coalesce((select jsonb_agg(to_jsonb(x) order by x.sort_order, x.name)
      from (select name, grp, sort_order, code, section, fine, common
            from cp_charges where active) x), '[]'::jsonb),
    'rows', coalesce((select jsonb_agg(to_jsonb(x) order by x.duty_date desc, x.id desc)
      from (
        select c.id, c.kind, c.duty_date, c.start_time, c.end_time, c.place,
               c.road_id, c.road_name, c.subdistrict, c.in_municipality,
               c.latitude, c.longitude, c.commander, c.officer_count,
               c.vehicles_checked, c.breath_tested, c.arrest_count, c.note,
               coalesce((select jsonb_agg(to_jsonb(a) order by a.id)
                 from (select id, person_ref, gender, age, vehicle, charge, charge_group,
                              alcohol_mg, fine_amount, note
                         from cp_arrests where checkpoint_id = c.id) a), '[]'::jsonb) as arrests
          from cp_checkpoints c
         where (p_from is null or c.duty_date >= p_from)
           and (p_to   is null or c.duty_date <= p_to)
      ) x), '[]'::jsonb));
end $$;

grant execute on function cp_list(text, date, date) to anon, authenticated;

-- ============================================================
-- ตรวจผลหลังรัน
-- ============================================================
-- ต้องเห็น code / section / fine ในผลลัพธ์ ไม่ใช่แค่ name กับ grp
-- select jsonb_pretty((cp_list('ใส่ token', null, null)->'charges')->0);
