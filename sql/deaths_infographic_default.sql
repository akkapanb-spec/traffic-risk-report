-- ทำให้ช่องภาพอินโฟกราฟิกเป็นช่องที่ไม่ส่งมาก็ได้
-- ถ้ามีอักขระแปลกปลอมต่อท้ายบรรทัดสุดท้าย ให้ลบออกก่อนกด Run
-- รันทันที เพราะตอนนี้ฟอร์มบันทึกผู้เสียชีวิตบนเว็บใช้งานไม่ได้
--
-- ------------------------------------------------------------
-- เกิดอะไรขึ้น
-- ------------------------------------------------------------
-- 28 ส.ค. 2569 รัน deaths_infographic.sql ไปแล้ว ฐานข้อมูลจึงต้องการ p_infographic
-- และรุ่นเก่าที่ไม่มีช่องนั้นถูกลบทิ้งไปตามที่ตั้งใจ
--
-- แต่หน้าเว็บรุ่นใหม่ยังขึ้นไม่ได้ เพราะ Netlify ระงับการ deploy จากเครดิตหมด
-- เว็บที่ให้บริการอยู่จึงเป็นรุ่น 9:01 น. ซึ่งยังส่งชุดพารามิเตอร์แบบเดิม
--
-- PostgREST จับคู่ฟังก์ชันจากชุดพารามิเตอร์ที่ส่งมา พอไม่มีตัวไหนตรง
-- มันตอบว่าหาฟังก์ชันไม่เจอ เจ้าหน้าที่กดบันทึกแล้วขึ้นข้อผิดพลาดทุกครั้ง
--
-- ลำดับที่ถูกคือรัน SQL ก่อนแล้วค่อยลากไฟล์ขึ้นเว็บ
-- ครั้งนี้ทำครึ่งแรกได้ แต่ครึ่งหลังติดที่ผู้ให้บริการ จึงค้างอยู่ตรงกลาง
--
-- ------------------------------------------------------------
-- วิธีแก้ ใส่ค่าเริ่มต้นให้ช่องใหม่
-- ------------------------------------------------------------
-- เมื่อพารามิเตอร์มีค่าเริ่มต้น ผู้เรียกจะไม่ส่งมาก็ได้
-- หน้าเว็บรุ่นเก่าที่ส่ง 18 ช่อง จึงเรียกได้เหมือนเดิม ภาพจะเป็นค่าว่าง
-- หน้าเว็บรุ่นใหม่ที่ส่ง 19 ช่อง ก็เรียกได้เช่นกัน ใช้ได้ทั้งสองรุ่นพร้อมกัน
--
-- นี่ไม่ใช่การสร้างฟังก์ชันตัวที่สอง ยังมีตัวเดียวเหมือนเดิม
-- ถ้าสร้างตัวที่สองจะกลายเป็นสองตัวให้เลือก แล้วการเรียกจะกำกวมทั้งคู่
--
-- ------------------------------------------------------------
-- ทำไมไม่พิมพ์ฟังก์ชันใหม่ทั้งตัว
-- ------------------------------------------------------------
-- อ่านนิยามที่ติดตั้งอยู่จริงมาเติมคำว่าค่าเริ่มต้นเข้าไปตรงจุดเดียว
-- แล้วติดตั้งกลับ วิธีนี้ไม่มีทางทำให้เนื้อในเพี้ยนจากของจริง
-- นับจุดยึดก่อนแทนที่ ถ้าไม่เจอพอดีหนึ่งแห่งให้หยุด ไม่แก้อะไรเลย

do $fn$
declare
  r     record;
  v_src text;
  v_a   text := 'p_infographic text';
  v_b   text := 'p_infographic text DEFAULT NULL';
  v_n   int;
begin
  for r in
    select p.oid, p.proname
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('admin_add_death', 'admin_update_death')
  loop
    v_src := pg_get_functiondef(r.oid);

    if position(v_b in v_src) > 0 then
      raise notice '% ใส่ค่าเริ่มต้นไว้แล้ว ข้าม', r.proname;
      continue;
    end if;

    v_n := (length(v_src) - length(replace(v_src, v_a, ''))) / length(v_a);
    if v_n <> 1 then
      raise exception '% จุดยึดพบ % แห่ง ไม่ใช่ 1 แห่ง จึงไม่แก้', r.proname, v_n;
    end if;

    execute replace(v_src, v_a, v_b);
    raise notice '% ใส่ค่าเริ่มต้นแล้ว', r.proname;
  end loop;
end;
$fn$;

-- ==========================================================
-- ตรวจผล  คำสั่งสุดท้ายคำสั่งเดียวที่จะแสดงผล
-- ==========================================================

select 'จำนวนรุ่น admin_add_death' as รายการ,
       (select count(*)::text from pg_proc p join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'public' and p.proname = 'admin_add_death') || '   ต้องเป็น 1' as ผล
union all
select 'จำนวนรุ่น admin_update_death',
       (select count(*)::text from pg_proc p join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'public' and p.proname = 'admin_update_death') || '   ต้องเป็น 1'
union all
select 'admin_add_death ช่องภาพไม่บังคับแล้ว',
       case when exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                         where n.nspname = 'public' and p.proname = 'admin_add_death'
                           and pg_get_function_arguments(p.oid) ilike '%p_infographic text default%')
            then 'ใช่  หน้าเว็บรุ่นเก่าเรียกได้แล้ว' else 'ยังบังคับอยู่' end
union all
select 'admin_update_death ช่องภาพไม่บังคับแล้ว',
       case when exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                         where n.nspname = 'public' and p.proname = 'admin_update_death'
                           and pg_get_function_arguments(p.oid) ilike '%p_infographic text default%')
            then 'ใช่  หน้าเว็บรุ่นเก่าเรียกได้แล้ว' else 'ยังบังคับอยู่' end
union all
select 'ช่องภาพในตาราง ยังอยู่',
       case when exists (select 1 from information_schema.columns
                         where table_schema = 'public' and table_name = 'deaths'
                           and column_name = 'infographic_url')
            then 'อยู่ครบ' else 'หายไป' end
union all
select 'ขั้นต่อไป',
       'ลองบันทึกผู้เสียชีวิตในหน้าเจ้าหน้าที่  ต้องบันทึกผ่านแล้ว แม้ยังไม่มีช่องแนบภาพ';
