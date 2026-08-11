-- ============================================================
-- LINE Bot — ซ่อนคำสั่ง #id จากเมนู
-- ============================================================
-- ไฟล์ที่ 8  ต้องรัน line_1 ถึง line_2 มาก่อน
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
--
-- #id เป็นเครื่องมือตอนตั้งค่า ไม่ใช่คำสั่งที่เจ้าหน้าที่ต้องใช้ประจำ
-- อยู่ในเมนูแล้วรกและชวนสับสน
--
-- แต่ไม่ปิดทิ้ง เพราะต้องใช้อีกทุกครั้งที่เพิ่มบอทเข้ากลุ่มใหม่
-- ถ้าปิดไปเลย คราวหน้าจะหา group id ไม่ได้แล้วติดตรงเดิม
-- จึงแค่ซ่อนจากเมนู ส่วนพิมพ์ #id ยังใช้ได้ตามปกติ
-- ============================================================

set search_path = public, extensions;

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

  if v_action = 'id' then
    return jsonb_build_object('action', 'id', 'text', null);
  end if;

  if v_action = 'ac-d' then
    return jsonb_build_object('action', v_action, 'text', line_msg_acc_day());
  elsif v_action = 'ac-w' then
    return jsonb_build_object('action', v_action, 'text', line_msg_acc_week());

  elsif v_action = 'help' then
    -- ไม่แสดง id ในเมนู แต่ยังตอบเมื่อพิมพ์เข้ามา
    v_lines := array['🤖 คำสั่งที่ใช้ได้', ''];
    for r in
      select string_agg(keyword, ' / ' order by keyword) as ks,
             max(case action when 'ac-d' then 'สรุปอุบัติเหตุวันนี้'
                             when 'ac-w' then 'สรุปอุบัติเหตุรอบสัปดาห์'
                             else action end) as ds
        from line_keywords where enabled and action not in ('help', 'id')
       group by action order by min(sort_order)
    loop
      v_lines := v_lines || (r.ks || '  —  ' || r.ds);
    end loop;
  end if;

  if v_lines is null or array_length(v_lines, 1) is null then return null; end if;
  return jsonb_build_object('action', v_action, 'text', array_to_string(v_lines, chr(10)));
end $line_reply$;

grant execute on function line_reply(text) to anon, authenticated;

-- ============================================================
-- ตรวจผลหลังรัน
-- ============================================================
-- เมนูต้องเหลือแค่ #ac-d กับ #ac-w
--   select line_reply('#help');
--
-- แต่ #id ต้องยังตอบอยู่ (คืน action=id ให้ Edge Function เติม id เอง)
--   select line_reply('#id');
--
-- ============================================================
-- ถ้าอยากปิด #id ไปเลยจริง ๆ
-- ============================================================
-- update line_keywords set enabled = false where keyword = '#id';
-- เปิดกลับ: update line_keywords set enabled = true where keyword = '#id';
