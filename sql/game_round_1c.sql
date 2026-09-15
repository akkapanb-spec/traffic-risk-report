-- ============================================================
-- เกมทดสอบการตัดสินใจ  ไฟล์ที่ 1c จาก 4  ฟังก์ชันบันทึกผลหนึ่งรอบ
-- ============================================================
-- รันเรียงตามลำดับ 1a 1b 1c 1d  ห้ามข้าม
-- แยกเป็นไฟล์เล็กเพราะไฟล์รวมสามฟังก์ชันรันไม่ผ่านในตัวแก้ไข
-- ไฟล์ละหนึ่งฟังก์ชัน จึงมีตัวคั่นคู่เดียว และรู้ได้ทันทีว่าพังไฟล์ไหน
--
-- ห้ามมีปีกกาในไฟล์นี้ ตัวแก้ไขจะเติมแบ็กสแลชให้
-- ก่อนกด Run ให้ลบสิ่งที่ตัวแก้ไขเติมไว้ท้ายสุดออกก่อน เป็นดอลลาร์ตามด้วยเลขศูนย์
--
-- คิดคะแนนในฐานข้อมูลทั้งหมด ตอบถูกสิบคะแนน ตอบผิดศูนย์
-- ตอบถูกได้คะแนนความเร็วเพิ่มไม่เกินห้า เต็มที่สิบสองวินาที เป็นศูนย์ที่สี่สิบห้าวินาที
-- ให้เฉพาะข้อที่ตอบถูก เพราะเกมนี้สอนให้ชะลอและดูให้รอบคอบก่อนตัดสินใจ
-- ถ้าให้รางวัลความเร็วมากเกินไปก็จะสอนตรงข้ามกับเนื้อหาของตัวเอง
--
-- ฐานข้อมูลไม่มีคลังคำถาม จึงตรวจเองไม่ได้ว่าข้อไหนตอบถูกจริง
-- ต้องเชื่อค่าที่หน้าเกมส่งมา กระดานนี้จึงมีไว้กระตุ้นให้เล่นซ้ำ
-- ไม่ได้มีไว้ตัดสินรางวัลที่มีมูลค่า

create or replace function game_round_save(
  p_key     uuid,
  p_name    text,
  p_cycle   int,
  p_answers jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_name   text;
  v_cycle  int;
  v_last   timestamptz;
  v_asked  int := 0;
  v_ok     int := 0;
  v_ms     bigint := 0;
  v_pts    numeric := 0;
  v_clean  jsonb := jsonb_build_array();
  e        jsonb;
  q        text;
  b        boolean;
  m        int;
  bonus    numeric;
  v_rounds int;
  v_tot    int;
  v_okall  int;
  v_msall  bigint;
  v_ptsall numeric;
  v_done   int;
  v_rank   int;
  v_avg    numeric;
begin
  if p_key is null then
    return jsonb_build_object('success', false, 'message', 'ไม่พบรหัสประจำเครื่อง');
  end if;

  if p_answers is null or jsonb_typeof(p_answers) <> 'array'
     or jsonb_array_length(p_answers) = 0 then
    return jsonb_build_object('success', false, 'message', 'ไม่มีข้อมูลการตอบ');
  end if;

  if jsonb_array_length(p_answers) > 100 then
    return jsonb_build_object('success', false, 'message', 'จำนวนข้อเกินกว่าที่เป็นไปได้');
  end if;

  -- กันการยิงซ้ำรัว ๆ  เล่นยี่สิบห้าข้อไม่มีทางจบภายในยี่สิบวินาที
  select max(played_at) into v_last from game_rounds where device_key = p_key;
  if v_last is not null and now() - v_last < interval '20 seconds' then
    return jsonb_build_object('success', false, 'message', 'เพิ่งบันทึกไปเมื่อครู่ ลองใหม่อีกสักครู่');
  end if;

  for e in select je from jsonb_array_elements(p_answers) as je loop
    q := e ->> 'qid';
    b := coalesce((e ->> 'ok')::boolean, false);
    m := coalesce((e ->> 'ms')::int, 0);

    if q is null or length(q) < 2 or length(q) > 12 then
      return jsonb_build_object('success', false, 'message', 'รหัสข้อไม่ถูกต้อง');
    end if;

    -- เวลาที่ส่งมาจากเบราว์เซอร์แก้ได้ จึงบีบให้อยู่ในช่วงที่เป็นไปได้จริงเสมอ
    -- ต่ำกว่าครึ่งวินาทีคือกดโดยไม่ได้อ่าน  เกินห้านาทีคือวางเครื่องทิ้งไว้
    m := greatest(500, least(m, 300000));

    v_asked := v_asked + 1;
    v_ms := v_ms + m;

    if b then
      v_ok := v_ok + 1;
      -- คะแนนความเร็ว  เต็มห้าคะแนนถ้าตอบภายในสิบสองวินาที  ลดลงจนเป็นศูนย์ที่สี่สิบห้าวินาที
      -- ให้เฉพาะข้อที่ตอบถูกเท่านั้น ตอบผิดเร็วแค่ไหนก็ได้ศูนย์
      bonus := 5.0 * (45000 - m) / 33000.0;
      if bonus < 0 then bonus := 0; end if;
      if bonus > 5 then bonus := 5; end if;
      v_pts := v_pts + 10 + bonus;
    end if;

    v_clean := v_clean || jsonb_build_array(jsonb_build_object('qid', q, 'ok', b, 'ms', m));
  end loop;

  v_name := nullif(btrim(coalesce(p_name, '')), '');
  if v_name is null then
    v_name := 'ผู้เล่นไม่ระบุชื่อ';
  end if;
  v_name := left(v_name, 30);

  v_cycle := greatest(coalesce(p_cycle, 1), 1);

  insert into game_rounds (device_key, player_name, cycle, answers, asked, correct, total_ms, points)
  values (p_key, v_name, v_cycle, v_clean, v_asked, v_ok, v_ms, round(v_pts, 2));

  select count(*), coalesce(sum(asked), 0), coalesce(sum(correct), 0),
         coalesce(sum(total_ms), 0), coalesce(sum(points), 0)
    into v_rounds, v_tot, v_okall, v_msall, v_ptsall
    from game_rounds where device_key = p_key;

  -- ทำไปแล้วกี่ข้อในรอบใหญ่นี้  นับรหัสข้อที่ไม่ซ้ำกัน ไม่ใช่นับจำนวนครั้งที่ตอบ
  select count(distinct (x ->> 'qid')) into v_done
    from game_rounds r cross join lateral jsonb_array_elements(r.answers) as x
   where r.device_key = p_key and r.cycle = v_cycle;

  v_avg := round(v_ptsall / nullif(v_tot, 0), 2);

  select count(*) + 1 into v_rank
    from (
      select device_key, sum(points) / nullif(sum(asked), 0) as ap, sum(asked) as an
        from game_rounds group by device_key
    ) t
   where t.an >= 25 and t.ap > v_avg;

  return jsonb_build_object(
    'success',     true,
    'name',        v_name,
    'cycle',       v_cycle,
    'done',        v_done,
    'rounds',      v_rounds,
    'answered',    v_tot,
    'correct',     v_okall,
    'avg_sec',     round(v_msall / 1000.0 / nullif(v_tot, 0), 1),
    'avg_points',  v_avg,
    'rank',        v_rank,
    'ranked',      (v_tot >= 25)
  );
end;$fn$;

grant execute on function game_round_save(uuid, text, int, jsonb) to anon;

-- ตรวจ  ต้องได้ฟังก์ชัน 1
select (select count(*) from pg_proc where proname = 'game_round_save') as ฟังก์ชัน;

-- จบไฟล์  อย่าเคาะบรรทัดใหม่ต่อท้ายบรรทัดนี้ ->