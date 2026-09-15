-- ============================================================
-- เกมทดสอบการตัดสินใจ  ไฟล์ที่ 1d จาก 4  ฟังก์ชันตารางสรุปรายคน
-- ============================================================
-- รันเรียงตามลำดับ 1a 1b 1c 1d  ห้ามข้าม
-- แยกเป็นไฟล์เล็กเพราะไฟล์รวมสามฟังก์ชันรันไม่ผ่านในตัวแก้ไข
-- ไฟล์ละหนึ่งฟังก์ชัน จึงมีตัวคั่นคู่เดียว และรู้ได้ทันทีว่าพังไฟล์ไหน
--
-- ห้ามมีปีกกาในไฟล์นี้ ตัวแก้ไขจะเติมแบ็กสแลชให้
-- ก่อนกด Run ให้ลบสิ่งที่ตัวแก้ไขเติมไว้ท้ายสุดออกก่อน เป็นดอลลาร์ตามด้วยเลขศูนย์
--
-- เรียงตามคะแนนเฉลี่ยต่อข้อ ถ้าเท่ากันให้คนที่ทำมามากกว่าอยู่บน
-- ขึ้นกระดานเมื่อทำครบยี่สิบห้าข้อขึ้นไป เพราะค่าเฉลี่ยจากไม่กี่ข้อยังไม่บอกอะไร

create or replace function game_board(p_limit int default 20)
returns jsonb
language sql
security definer
set search_path = public
as $fn$
  with per as (
    select
      r.device_key,
      max(r.cycle)                                          as cycle,
      count(*)                                              as rounds,
      sum(r.asked)                                          as answered,
      sum(r.correct)                                        as correct,
      sum(r.total_ms)                                       as ms,
      sum(r.points)                                         as pts,
      (array_agg(r.player_name order by r.played_at desc))[1] as name
    from game_rounds r
    group by r.device_key
  ),
  cyc as (
    select p.device_key, count(distinct (x ->> 'qid')) as done_in_cycle
      from per p
      join game_rounds r on r.device_key = p.device_key and r.cycle = p.cycle
      cross join lateral jsonb_array_elements(r.answers) as x
     group by p.device_key
  )
  select coalesce(jsonb_agg(z order by z.rank), jsonb_build_array())
  from (
    select
      row_number() over (order by p.pts / nullif(p.answered, 0) desc, p.answered desc) as rank,
      p.name,
      p.cycle,
      coalesce(c.done_in_cycle, 0)                                   as done,
      p.rounds,
      p.answered,
      p.correct,
      round(100.0 * p.correct / nullif(p.answered, 0), 0)            as pct,
      round(p.ms / 1000.0 / nullif(p.answered, 0), 1)                as avg_sec,
      round(p.pts / nullif(p.answered, 0), 2)                        as avg_points
    from per p
    left join cyc c on c.device_key = p.device_key
    where p.answered >= 25
    order by p.pts / nullif(p.answered, 0) desc, p.answered desc
    limit least(greatest(coalesce(p_limit, 20), 1), 100)
  ) z;$fn$;

grant execute on function game_board(int) to anon;

-- ตรวจ  ต้องได้ฟังก์ชันครบสามตัว และกระดานว่าง
select
  (select count(*) from game_rounds)                                as แถวในตาราง,
  (select count(*) from pg_proc where proname = 'game_progress')    as ความคืบหน้า,
  (select count(*) from pg_proc where proname = 'game_round_save')  as บันทึก,
  (select count(*) from pg_proc where proname = 'game_board')       as กระดาน,
  game_board(5)                                                     as กระดานปัจจุบัน;

-- จบไฟล์  อย่าเคาะบรรทัดใหม่ต่อท้ายบรรทัดนี้ ->