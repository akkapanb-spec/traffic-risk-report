-- ============================================================
-- สะสมคะแนนเกมทดสอบการตัดสินใจ และจัดอันดับ
-- ============================================================
-- เกมเดิมเก็บคะแนนไว้ในหน้าจอเท่านั้น ปิดหน้าแล้วหาย และเทียบกับใครไม่ได้
-- ไฟล์นี้เพิ่มการสะสมคะแนนข้ามรอบ แล้วจัดอันดับจากคะแนนสะสม
--
-- ทำไมสะสม ไม่ใช่เก็บคะแนนสูงสุด
--   เก็บคะแนนสูงสุดจะให้รางวัลคนที่เล่นรอบเดียวแล้วฟลุก
--   สะสมให้รางวัลคนที่กลับมาเล่นซ้ำ ซึ่งคือพฤติกรรมที่เราต้องการจริง
--   เพราะคนที่เล่นซ้ำคือคนที่ได้อ่านคำอธิบายซ้ำ
--
-- ============================================================
-- ผู้เล่นคือใคร
-- ============================================================
-- เกมนี้ไม่มีระบบสมัครสมาชิกและไม่ควรมี เพราะจะทำให้คนเลิกเล่นตั้งแต่หน้าแรก
-- จึงให้เครื่องของผู้เล่นสร้างรหัสประจำเครื่องขึ้นมาเองหนึ่งชุด เก็บไว้ในเครื่อง
-- คะแนนผูกกับรหัสนั้น ไม่ได้ผูกกับชื่อ ชื่อเป็นแค่สิ่งที่เอามาแสดง
--
-- ผลที่ตามมาซึ่งต้องยอมรับไว้ตั้งแต่ต้น
--   ล้างข้อมูลเบราว์เซอร์ คะแนนสะสมจะขาดตอน เริ่มนับใหม่
--   เปลี่ยนเครื่อง คะแนนไม่ตามไป
--   คนคนเดียวเปิดหลายเบราว์เซอร์ จะนับเป็นหลายคน
-- นี่คือราคาของการไม่บังคับสมัครสมาชิก และเป็นราคาที่คุ้มสำหรับสื่อรณรงค์
-- อันดับนี้จึงใช้กระตุ้นให้คนเล่นซ้ำ ไม่ใช่ใช้ตัดสินรางวัลที่มีมูลค่า
-- ถ้าวันหนึ่งจะเอาไปแจกของจริง ต้องเปลี่ยนไปผูกกับบัญชีไลน์ก่อน
--
-- ============================================================
-- ห้ามเขียนปีกกาและสัญลักษณ์เงินดอลลาร์ในไฟล์นี้
-- ============================================================
-- ตัวแก้ไขของ Supabase อ่านไฟล์ที่ลากเข้าไปเป็นสนิปเปต แล้วเติมแบ็กสแลชหน้าปีกกา
-- ถ้าไปตกอยู่ในสตริง ไฟล์จะรันผ่านแล้วเก็บความเสียหายไว้ในฐานข้อมูลเงียบ ๆ
-- จึงใช้ jsonb_build_object แทนการเขียนวงเล็บปีกกาเปล่า
-- ตัวคั่นตัวฟังก์ชันที่เขียนด้วยเครื่องหมายดอลลาร์สองตัวรอดมาได้ ยืนยันแล้ว
-- ============================================================

create table if not exists game_scores (
  id          bigint generated always as identity primary key,
  device_key  uuid        not null,
  player_name text        not null,
  score       int         not null,
  total       int         not null,
  played_at   timestamptz not null default now()
);

create index if not exists game_scores_device_idx on game_scores (device_key);
create index if not exists game_scores_played_idx on game_scores (played_at desc);

alter table game_scores enable row level security;
-- ตั้งใจไม่สร้างนโยบายใด ๆ  ทุกทางเข้าออกผ่านฟังก์ชันข้างล่างเท่านั้น
-- ถ้าเปิดให้ anon เขียนตรง ๆ ใครก็ยิงคะแนนเต็มเข้ามาได้ด้วยคำสั่งเดียว

-- ============================================================
-- บันทึกผลหนึ่งรอบ แล้วคืนอันดับล่าสุดกลับไปให้แสดงทันที
-- ============================================================
-- ด่านกันค่าเพี้ยนที่ต้องมี เพราะค่าทั้งหมดส่งมาจากเบราว์เซอร์ซึ่งแก้ได้
--   คะแนนต้องไม่ติดลบ และต้องไม่เกินจำนวนข้อที่เล่น
--   จำนวนข้อต้องอยู่ในช่วงที่เกมใช้จริง
--   เครื่องเดิมบันทึกถี่กว่าสามสิบวินาทีจะถูกปฏิเสธ เพราะเล่นยี่สิบข้อไม่ทันแน่
-- ปฏิเสธแล้วไม่ถือเป็นความผิดพลาด คืนสถานะไปให้หน้าจอบอกผู้เล่นตามปกติ
create or replace function game_score_save(
  p_key   uuid,
  p_name  text,
  p_score int,
  p_total int
) returns jsonb
language plpgsql
security definer
set search_path = public
as '
declare
  v_name  text;
  v_last  timestamptz;
  v_sum   int;
  v_games int;
  v_rank  int;
begin
  if p_key is null then
    return jsonb_build_object(''success'', false, ''message'', ''ไม่พบรหัสประจำเครื่อง'');
  end if;

  if p_total is null or p_total < 5 or p_total > 200
     or p_score is null or p_score < 0 or p_score > p_total then
    return jsonb_build_object(''success'', false, ''message'', ''คะแนนไม่ถูกต้อง'');
  end if;

  v_name := nullif(btrim(coalesce(p_name, '''')), '''');
  if v_name is null then
    v_name := ''ผู้เล่นไม่ระบุชื่อ'';
  end if;
  v_name := left(v_name, 30);

  select max(played_at) into v_last from game_scores where device_key = p_key;
  if v_last is not null and now() - v_last < interval ''30 seconds'' then
    return jsonb_build_object(''success'', false, ''message'', ''เพิ่งบันทึกไปเมื่อครู่ ลองใหม่อีกสักครู่'');
  end if;

  insert into game_scores (device_key, player_name, score, total)
  values (p_key, v_name, p_score, p_total);

  select coalesce(sum(score), 0), count(*)
    into v_sum, v_games
    from game_scores where device_key = p_key;

  select count(*) + 1 into v_rank
  from (
    select device_key, sum(score) as s
      from game_scores
     group by device_key
  ) t
  where t.s > v_sum;

  return jsonb_build_object(
    ''success'', true,
    ''name'',    v_name,
    ''sum'',     v_sum,
    ''games'',   v_games,
    ''rank'',    v_rank
  );
end;
';

-- ============================================================
-- ตารางอันดับ
-- ============================================================
-- เรียงตามคะแนนสะสม ถ้าเท่ากันให้คนที่ใช้จำนวนรอบน้อยกว่าอยู่บน
-- เพราะได้คะแนนเท่ากันโดยเล่นน้อยรอบกว่า แปลว่าแม่นกว่าจริง
-- ชื่อที่แสดงคือชื่อที่ใช้ในรอบล่าสุด เผื่อผู้เล่นเปลี่ยนชื่อระหว่างทาง
create or replace function game_score_top(p_limit int default 20)
returns jsonb
language sql
security definer
set search_path = public
as '
  select coalesce(jsonb_agg(r order by r.rank), jsonb_build_array())
  from (
    select
      row_number() over (order by g.total_score desc, g.games asc, g.first_at asc) as rank,
      g.name,
      g.total_score,
      g.games
    from (
      select
        device_key,
        sum(score)                                      as total_score,
        count(*)                                        as games,
        min(played_at)                                  as first_at,
        (array_agg(player_name order by played_at desc))[1] as name
      from game_scores
      group by device_key
    ) g
    order by g.total_score desc, g.games asc, g.first_at asc
    limit least(greatest(coalesce(p_limit, 20), 1), 100)
  ) r;
';

grant execute on function game_score_save(uuid, text, int, int) to anon;
grant execute on function game_score_top(int) to anon;

-- ตรวจหลังรัน  ต้องได้ตารางว่างหนึ่งชุดและฟังก์ชันสองตัว
select
  (select count(*) from game_scores)                                          as แถวในตาราง,
  (select count(*) from pg_proc where proname = 'game_score_save')            as ฟังก์ชันบันทึก,
  (select count(*) from pg_proc where proname = 'game_score_top')             as ฟังก์ชันอันดับ,
  game_score_top(5)                                                           as อันดับปัจจุบัน;
-- ============================================================
-- ไฟล์นี้ไม่มีเครื่องหมายดอลลาร์เลยแม้แต่ตัวเดียว  ตั้งใจให้เป็นแบบนั้น
-- ============================================================
-- ตัวแก้ไขของ Supabase อ่านไฟล์ที่ลากเข้าไปเป็นสนิปเปต
-- ในไวยากรณ์สนิปเปต เครื่องหมายดอลลาร์ตามด้วยชื่อคือตัวแปร
-- ตัวแปรที่ไม่รู้จักจะถูกแทนด้วยค่าว่าง ตัวคั่นตัวฟังก์ชันจึงพังได้ทั้งไฟล์
-- และเพราะตัวแก้ไขรันทั้งไฟล์เป็นทรานแซกชันเดียว ของทั้งไฟล์จะย้อนกลับหมด
-- อาการที่เห็นคือรันแล้วเหมือนไม่มีอะไรเกิดขึ้น ไม่มีตารางและไม่มีฟังก์ชันสักตัว
--
-- ตัวฟังก์ชันในไฟล์นี้จึงครอบด้วยเครื่องหมายคำพูดเดี่ยว ไม่ใช่ตัวคั่นแบบดอลลาร์
-- เครื่องหมายคำพูดเดี่ยวที่อยู่ข้างในตัวฟังก์ชัน จึงต้องเขียนซ้ำสองตัวทุกตัว
-- ถ้าจะแก้ไฟล์นี้ต่อ ให้รักษากติกาข้อนี้ไว้ และอย่าเติมเครื่องหมายดอลลาร์กลับเข้ามา
-- แม้แต่ในคอมเมนต์ก็อย่าเขียน เพราะคอมเมนต์ก็ถูกอ่านเป็นสนิปเปตเหมือนกัน
-- ตรวจก่อนส่งเสมอ  ไฟล์ต้องไม่มีปีกกาและไม่มีเครื่องหมายดอลลาร์เลย