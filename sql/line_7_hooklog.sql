-- ============================================================
-- LINE Bot — สมุดบันทึกคำขอที่เข้ามาจาก LINE (ไว้ไล่ปัญหา)
-- ============================================================
-- ไฟล์ที่ 7  ต้องรัน line_1_tables.sql มาก่อน
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
--
-- ทำไมต้องมี
--   ตัวบันทึกที่ฝังใน Edge Function เก็บไว้ในหน่วยความจำ
--   Supabase ปั่นฟังก์ชันหลายตัวขนานกันได้ LINE ยิงเข้าตัวหนึ่ง
--   แต่ตอนอ่านอาจไปโดนอีกตัว จึงเห็นเป็นว่างทั้งที่มีคนส่งมาจริง
--   เขียนลงฐานข้อมูลแทน ทุกตัวเขียนที่เดียวกัน อ่านที่ไหนก็เห็นเหมือนกัน
--
--   และผลพลอยได้สำคัญ — group id จะถูกบันทึกไว้ด้วย
--   จึงเอามาตั้งค่าการแจ้งเตือนได้ แม้บอทจะยังตอบกลับไม่ได้ก็ตาม
--
-- ตารางนี้มีไว้ชั่วคราวสำหรับไล่ปัญหา เสร็จแล้วลบทิ้งได้
--   drop table line_hook_log cascade;
-- ============================================================

set search_path = public, extensions;

create table if not exists line_hook_log (
  id   bigint generated always as identity primary key,
  at   timestamptz not null default now(),
  note text
);

-- ปิดไม่ให้แตะตรง ๆ เพราะมี group id กับข้อความที่คนพิมพ์อยู่ข้างใน
alter table line_hook_log enable row level security;

-- เก็บแค่ 200 แถวล่าสุดพอ ไม่ให้บวมทิ้งไว้
create or replace function line_hook_write(p_note text)
returns void
language plpgsql security definer set search_path = public, extensions as $line_hook_write$
begin
  insert into line_hook_log (note) values (left(coalesce(p_note, ''), 4000));
  delete from line_hook_log
   where id < (select max(id) - 200 from line_hook_log);
end $line_hook_write$;

/* อ่านได้ต้องมีกุญแจ
   เขียนได้โดยไม่ต้องมีกุญแจ เพราะ Edge Function ต้องเรียกได้ตลอด
   แต่การอ่านต้องกันไว้ ไม่งั้นใครก็ได้ที่มี anon key จะดึง group id
   กับข้อความที่เจ้าหน้าที่พิมพ์ในกลุ่มออกไปได้ */
create or replace function line_hook_read(p_key text)
returns table (at timestamptz, note text)
language plpgsql security definer set search_path = public, extensions as $line_hook_read$
begin
  if coalesce(p_key, '') <> 'nswhook2569' then
    raise exception 'กุญแจไม่ถูกต้อง';
  end if;
  return query
    select l.at, l.note from line_hook_log l order by l.id desc limit 20;
end $line_hook_read$;

grant execute on function line_hook_write(text) to anon, authenticated;
grant execute on function line_hook_read(text)  to anon, authenticated;

-- ============================================================
-- ตรวจผลหลังรัน
-- ============================================================
-- select line_hook_write('ทดสอบเขียน');
-- select * from line_hook_read('nswhook2569');
--
-- ============================================================
-- เมื่อไล่ปัญหาเสร็จแล้ว ลบทิ้งด้วย
-- ============================================================
-- drop function if exists line_hook_read(text);
-- drop function if exists line_hook_write(text);
-- drop table if exists line_hook_log;
