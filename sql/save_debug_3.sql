-- ============================================================
-- ตรวจทุกอย่างในคำสั่งเดียว ผลออกมาเป็นตารางเดียว
-- ============================================================
-- ไฟล์นี้ "อ่านอย่างเดียว" ไม่สร้าง ไม่แก้ ไม่ลบ ไม่เพิ่มอะไรเลย
-- ไม่ต้องใช้ token ไม่ต้องแก้อะไรก่อนรัน
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
--
-- ทำไมต้องเขียนใหม่
--   ไฟล์ที่แล้วผมแยกเป็น 5 คำสั่ง แต่ Supabase แสดงผลของคำสั่งสุดท้ายอันเดียว
--   ข้อ 1 ถึง 4 จึงรันไปแล้วแต่ไม่มีใครได้เห็นผล เป็นความผิดพลาดในการออกแบบไฟล์ของผมเอง
--   คราวนี้รวมเป็นคำสั่งเดียว ทุกอย่างจะโผล่ในตารางเดียวกัน
--
-- ไฟล์นี้เลี่ยงวงเล็บปีกกาและแบ็กสแลชทั้งหมด
-- เพราะเครื่องนี้มีอะไรบางอย่างแทรกแบ็กสแลชหน้าวงเล็บปีกกาปิด
--
-- สิ่งที่ตรวจ
--   1 คำสั่งบันทึกมีกี่ตัว  ถ้ามีหลายตัวอาจเรียกผิดตัว
--   2 บรรทัดในโค้ดจริงที่แปลงข้อความเป็น json   <-- ข้อที่ต้องการที่สุด
--   3 ทริกเกอร์บนตารางที่คำสั่งบันทึกเขียนลง    รวมตารางผู้เสียชีวิตและผู้บาดเจ็บที่ผมเคยลืมตรวจ
--   4 ฟังก์ชันอื่นที่แปลงข้อความเป็น json        เผื่อพังในฟังก์ชันที่ถูกเรียกต่ออีกทอด
-- ============================================================

select 'ตรวจแล้ว' as หมวด,
       'ถ้าไม่มีหมวดอื่นโผล่เลย แปลว่าไม่พบจุดที่แปลงข้อความเป็น json' as รายละเอียด

union all
select '1 คำสั่งบันทึกที่มีอยู่', p.oid::regprocedure::text
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname = 'officer_save_accident'

union all
select '2 บรรทัดที่แปลงเป็น json', t.ln || ' : ' || t.txt
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 cross join lateral unnest(string_to_array(p.prosrc, chr(10)))
       with ordinality as t(txt, ln)
 where n.nspname = 'public' and p.proname = 'officer_save_accident'
   and t.txt ~ '::json([^b]|$)|to_json|json_build|json_agg'

union all
select '3 ทริกเกอร์', c.relname || ' เรียก ' || p2.proname
  from pg_trigger tg
  join pg_class c on c.oid = tg.tgrelid
  join pg_proc p2 on p2.oid = tg.tgfoid
 where not tg.tgisinternal
   and c.relname in ('accidents', 'deaths', 'injuries')

union all
select '4 ฟังก์ชันอื่นที่แปลงเป็น json', p.proname
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.prosrc ~ '::json([^b]|$)'

order by 1, 2;

-- ============================================================
-- ส่งภาพตารางผลลัพธ์มาให้ดูครับ ถ้ามีหลายแถวจนเลื่อนไม่หมด
-- ถ่ายเฉพาะแถวที่ขึ้นต้นด้วยเลข 2 ก็พอ
-- ============================================================
