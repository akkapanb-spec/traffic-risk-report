-- ============================================================
-- เกมทดสอบการตัดสินใจ  ไฟล์ที่ 1b จาก 4  ฟังก์ชันบอกข้อที่เคยเจอแล้ว
-- ============================================================
-- รันเรียงตามลำดับ 1a 1b 1c 1d  ห้ามข้าม
-- แยกเป็นไฟล์เล็กเพราะไฟล์รวมสามฟังก์ชันรันไม่ผ่านในตัวแก้ไข
-- ไฟล์ละหนึ่งฟังก์ชัน จึงมีตัวคั่นคู่เดียว และรู้ได้ทันทีว่าพังไฟล์ไหน
--
-- ห้ามมีปีกกาในไฟล์นี้ ตัวแก้ไขจะเติมแบ็กสแลชให้
-- ก่อนกด Run ให้ลบสิ่งที่ตัวแก้ไขเติมไว้ท้ายสุดออกก่อน เป็นดอลลาร์ตามด้วยเลขศูนย์
--
-- คืนรหัสข้อที่เครื่องนี้เคยเจอในรอบใหญ่ที่กำลังเล่นอยู่ ให้หน้าเกมตัดออกก่อนสุ่ม
-- ทำครบทั้งคลังเมื่อไร จะขึ้นรอบใหญ่ใหม่และเริ่มสุ่มได้ทั้งหมดอีกครั้ง
-- ประวัติเดิมไม่ถูกลบ ยังอยู่ครบในตาราง

create or replace function game_progress(p_key uuid, p_pool int default 100)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_cycle int;
  v_seen  text[];
  v_pool  int;
begin
  v_pool := greatest(coalesce(p_pool, 100), 1);

  if p_key is null then
    return jsonb_build_object('cycle', 1, 'seen', jsonb_build_array(), 'done', 0, 'pool', v_pool);
  end if;

  select coalesce(max(cycle), 1) into v_cycle from game_rounds where device_key = p_key;

  select coalesce(array_agg(distinct t.qid), array[]::text[]) into v_seen
    from (
      select x ->> 'qid' as qid
        from game_rounds r cross join lateral jsonb_array_elements(r.answers) as x
       where r.device_key = p_key and r.cycle = v_cycle
    ) t
   where t.qid is not null;

  -- ทำครบทั้งคลังแล้ว ขึ้นรอบใหญ่รอบใหม่ เริ่มนับข้อที่ทำแล้วใหม่ทั้งหมด
  -- ประวัติเดิมไม่ได้ถูกลบ ยังอยู่ครบในตาราง แค่ไม่ถูกนับเป็นข้อที่เคยเจอในรอบนี้
  if coalesce(array_length(v_seen, 1), 0) >= v_pool then
    v_cycle := v_cycle + 1;
    v_seen := array[]::text[];
  end if;

  return jsonb_build_object(
    'cycle', v_cycle,
    'seen',  to_jsonb(v_seen),
    'done',  coalesce(array_length(v_seen, 1), 0),
    'pool',  v_pool
  );
end;$fn$;

grant execute on function game_progress(uuid, int) to anon;

-- ตรวจ  ต้องได้ฟังก์ชัน 1 และเรียกใช้ได้
select
  (select count(*) from pg_proc where proname = 'game_progress') as ฟังก์ชัน,
  game_progress(null, 100)                                        as ลองเรียก;

-- จบไฟล์  อย่าเคาะบรรทัดใหม่ต่อท้ายบรรทัดนี้ ->