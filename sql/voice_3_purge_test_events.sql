-- ============================================================
-- ลบเหตุการณ์ทดสอบออกจากสถิติการใช้งาน
-- ============================================================
-- ต้องรัน voice_1_tables.sql และ voice_2_rpc.sql มาก่อน
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
--
-- ตอนแก้บั๊กระบบเก็บ log (sendBeacon ถูก CORS บล็อกจนไม่เคยบันทึกได้เลย)
-- ได้ยิงเหตุการณ์ทดสอบเข้าไปเพื่อพิสูจน์ว่าบันทึกได้จริง
-- เหตุการณ์พวกนั้นไม่ใช่การใช้งานของประชาชน ต้องเอาออกไม่ให้ปนสถิติ
--
-- ทำไมไม่ใช้ vc_compact ที่มีอยู่
--   vc_compact ลบตามอายุ จะลบข้อมูลจริงของประชาชนไปด้วย
--   ตรงนี้ต้องลบเฉพาะแถวที่ระบุได้ชัดว่าเป็นของทดสอบ
-- ============================================================

set search_path = public, extensions;

-- ============================================================
-- 1) ลบของรอบนี้ - ระบุชื่อหน้าตรงตัว ไม่ใช้ like กว้าง ๆ
-- ============================================================
-- ต้องมี where เสมอ Supabase เปิด sql_safe_updates ไว้ delete ทั้งตารางจะถูกบล็อก
delete from vc_events where page in ('ทดสอบ', 'ทดสอบระบบ');

-- ============================================================
-- 2) เครื่องมือไว้ใช้ครั้งหน้า - ลบเหตุการณ์ตามชื่อหน้า
-- ============================================================
-- เผื่อมีการทดสอบอีกในอนาคต จะได้ไม่ต้องเขียนไฟล์ใหม่ทุกครั้ง
-- คืนจำนวนแถวที่ลบไป จะได้รู้ว่าตรงกับที่คาดไว้หรือเปล่า
create or replace function vc_event_purge(p_token text, p_page text)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare v_err jsonb; v_n int;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;

  if nullif(btrim(coalesce(p_page,'')), '') is null then
    -- กันพลาดแบบที่ทำให้ข้อมูลหายทั้งตาราง
    return jsonb_build_object('success', false, 'message', 'ต้องระบุชื่อหน้าที่จะลบ');
  end if;

  delete from vc_events where page = btrim(p_page);
  get diagnostics v_n = row_count;

  return jsonb_build_object('success', true, 'deleted', v_n,
    'message', 'ลบ ' || v_n || ' เหตุการณ์ของหน้า ' || btrim(p_page));
end $$;

grant execute on function vc_event_purge(text, text) to anon, authenticated;

-- ============================================================
-- ตรวจผลหลังรัน
-- ============================================================
-- ต้องได้ 0 ทั้งสองบรรทัด
-- select count(*) as เหลือของทดสอบ from vc_events where page in ('ทดสอบ','ทดสอบระบบ');
-- select page, count(*) from vc_events group by 1 order by 2 desc;
