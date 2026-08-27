-- ให้ประชาชนพิมพ์ถามแล้วได้ตัวเลขสดทันที
-- ถ้ามีอักขระแปลกปลอมต่อท้ายบรรทัดสุดท้าย ให้ลบออกก่อนกด Run
--
-- ------------------------------------------------------------
-- ปัญหาของวิธีเดิม
-- ------------------------------------------------------------
-- ตอนนี้การตอบกลับคีย์เวิร์ดตั้งอยู่ในระบบของไลน์เอง เป็นข้อความสำเร็จรูป
-- ที่พิมพ์ตัวเลขแช่ไว้ตั้งแต่วันที่สร้าง และมีวันหมดอายุ
--   สรุปรอบสัปดาห์  เขียนว่า 17-23 ส.ค. ซึ่งผ่านไปแล้ว  หมดอายุ 30 ส.ค.
--   สรุปรอบเดือน    หมดอายุ 31 ส.ค.
-- พอหมดอายุ ประชาชนพิมพ์แล้วเงียบ ซึ่งแย่กว่าไม่มีให้พิมพ์ตั้งแต่แรก
-- เพราะเขาจะสรุปว่าระบบพัง แล้วเลิกถามไปเลย
--
-- ไฟล์นี้ย้ายการตอบมาไว้ในฐานข้อมูล ซึ่งนับจากข้อมูลจริงทุกครั้งที่ถูกถาม
-- ไม่มีวันหมดอายุ ไม่ต้องมีใครมาพิมพ์ใหม่ทุกเดือน และตัวเลขตรงกับหน้าเว็บเสมอ
--
-- ------------------------------------------------------------
-- วางไว้เป็นฟังก์ชันแยก ไม่ยัดลงใน line_reply
-- ------------------------------------------------------------
-- line_reply มีตรรกะกิจกรรมแจกหมวกอยู่ด้วย ซึ่งพังแล้วกระทบเรื่องเงิน
-- การแก้ไฟล์นั้นบ่อย ๆ จึงเสี่ยงเกินความจำเป็น
-- ไฟล์นี้จึงแทรกเข้าไปเพียงสามบรรทัด แล้วงานจริงอยู่ใน line_pub_answer
-- วันหลังอยากเพิ่มคำถาม แก้แค่ฟังก์ชันนี้ ไม่ต้องแตะ line_reply อีกเลย

-- ==========================================================
-- 1  สรุปรอบเดือนและรอบปี
-- ==========================================================
-- ใช้ line_acc_counts ตัวเดียวกับที่สรุปรายวันใช้ ตัวเลขจึงนับด้วยกติกาเดียวกัน
-- ถ้านับคนละแบบ ประชาชนจะเจอเลขที่บวกกันไม่ลงตัวแล้วไม่เชื่อทั้งสองอัน

create or replace function line_msg_pub_month()
returns text
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_first date := date_trunc('month', line_today())::date;
  c jsonb;
begin
  c := line_acc_counts(timezone('Asia/Bangkok', v_first::timestamp),
                       timezone('Asia/Bangkok', (line_today() + 1)::timestamp));
  return array_to_string(array[
    '📊 สรุปอุบัติเหตุเดือนนี้',
    line_thai_date(timezone('Asia/Bangkok', v_first::timestamp)) || ' ถึงวันนี้',
    '',
    '• อุบัติเหตุ ' || (c->>'accidents') || ' ครั้ง',
    '• เสียชีวิต ' || (c->>'deaths') || ' ราย',
    '• สาหัส/หมดสติ ' || (c->>'severe') || ' ราย',
    '• บาดเจ็บเล็กน้อย ' || (c->>'minor') || ' ราย'
  ], chr(10));
end;
$fn$;

create or replace function line_msg_pub_year()
returns text
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_first date := date_trunc('year', line_today())::date;
  c jsonb;
begin
  c := line_acc_counts(timezone('Asia/Bangkok', v_first::timestamp),
                       timezone('Asia/Bangkok', (line_today() + 1)::timestamp));
  return array_to_string(array[
    '📊 สรุปอุบัติเหตุปีนี้',
    line_thai_date(timezone('Asia/Bangkok', v_first::timestamp)) || ' ถึงวันนี้',
    '',
    '• อุบัติเหตุ ' || (c->>'accidents') || ' ครั้ง',
    '• เสียชีวิต ' || (c->>'deaths') || ' ราย',
    '• สาหัส/หมดสติ ' || (c->>'severe') || ' ราย',
    '• บาดเจ็บเล็กน้อย ' || (c->>'minor') || ' ราย'
  ], chr(10));
end;
$fn$;

-- ==========================================================
-- 2  ฝนตอนนี้
-- ==========================================================
-- อ่านผลเรดาร์ครั้งล่าสุดที่ระบบเก็บไว้ ไม่ได้ยิงถามใหม่ตอนมีคนพิมพ์
-- เพราะการยิงถามใช้เวลาราวห้าวินาที ซึ่งนานเกินกว่าที่ไลน์รอคำตอบ
-- ระบบตรวจทุก 15 นาทีอยู่แล้ว ข้อมูลจึงไม่มีทางเก่ากว่านั้นมาก
--
-- ถ้าผลล่าสุดเก่ากว่าหนึ่งชั่วโมง ต้องบอกว่าอ่านไม่ได้ ห้ามบอกว่าไม่มีฝน
-- คนที่ได้ยินว่าไม่มีฝนแล้วออกไปเจอฝน จะไม่เชื่อข้อความเตือนอีกเลย

create or replace function line_msg_pub_rain()
returns text
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_body text;
  v_when timestamptz;
  v_j    jsonb;
  v_pct  numeric;
  v_heavy int;
  v_age  int;
begin
  select x.content, x.created into v_body, v_when
  from rain_probe p join net._http_response x on x.id = p.req_id
  order by p.req_id desc limit 1;

  if v_body is null then
    return 'ยังไม่มีผลตรวจเรดาร์ล่าสุด ลองใหม่อีกครั้งในอีกสักครู่';
  end if;

  begin
    v_j := v_body::jsonb;
  exception when others then
    return 'อ่านผลเรดาร์ไม่ได้ในขณะนี้';
  end;

  if coalesce((v_j->>'ok')::boolean, false) is not true then
    return 'อ่านผลเรดาร์ไม่ได้ในขณะนี้';
  end if;

  v_age := extract(epoch from (now() - v_when))::int / 60;
  if v_age > 60 then
    return 'ผลตรวจเรดาร์ล่าสุดเก่ากว่าหนึ่งชั่วโมง จึงยังบอกไม่ได้ว่าตอนนี้ฝนตกหรือไม่';
  end if;

  v_pct   := coalesce((v_j->>'rainPercent')::numeric, 0);
  v_heavy := coalesce((v_j->>'heavyPixels')::int, 0);

  return array_to_string(array[
    '🌧️ ฝนรอบตัวเมืองตอนนี้',
    'ตรวจเมื่อ ' || v_age || ' นาทีที่แล้ว',
    '',
    case when v_pct <= 0 then '• ไม่พบกลุ่มฝนในรัศมี 8 กม. รอบแยกเดชาติวงศ์'
         else '• มีกลุ่มฝนครอบคลุม ' || v_pct || ' เปอร์เซ็นต์ของรัศมี 8 กม.' end,
    case when v_heavy > 0 then '• มีฝนหนักปนอยู่ด้วย' else '' end,
    '',
    'ดูแผนที่ฝนสดได้ที่หน้าจุดเสี่ยงบนเว็บของเรา'
  ], chr(10));
end;
$fn$;

-- ==========================================================
-- 3  ตัวจับคำถามของประชาชน
-- ==========================================================
-- คืน null เมื่อไม่ใช่คำถามที่รู้จัก เพื่อให้ line_reply ทำงานต่อตามเดิม
-- ไม่ตอบมั่วเมื่อไม่เข้าใจ เพราะบอทที่ตอบทุกอย่างจะถูกเตะออกจากกลุ่ม

create or replace function line_pub_answer(p_q text)
returns text
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_q text := btrim(coalesce(p_q, ''));
  v_site text := coalesce((select val #>> array[]::text[] from bs_settings
                            where key = 'publicSiteUrl'), '');
begin
  if v_q = '' then return null; end if;

  if v_q in ('สรุปวันนี้', 'วันนี้', 'อุบัติเหตุวันนี้') then
    return line_msg_acc_day(null);

  elsif v_q in ('สรุปสัปดาห์', 'สัปดาห์นี้', 'รอบสัปดาห์') then
    return line_msg_acc_week(null);

  elsif v_q in ('สรุปเดือน', 'เดือนนี้', 'รอบเดือน') then
    return line_msg_pub_month();

  elsif v_q in ('สรุปปี', 'ปีนี้', 'ทั้งปี', 'รอบปี') then
    return line_msg_pub_year();

  elsif v_q in ('ฝน', 'ฝนตอนนี้', 'ฝนไหม', 'ฝนมั้ย') then
    return line_msg_pub_rain();

  elsif v_q in ('จุดเสี่ยง', 'จุดอันตราย', 'จุดเกิดเหตุซ้ำ') then
    return array_to_string(array[
      '⚠️ จุดเสี่ยงในเขตเมืองนครสวรรค์',
      '',
      'ระบบเฝ้าจุดที่เกิดอุบัติเหตุซ้ำในรอบ 30 วัน',
      'และแจ้งเข้ากลุ่มเมื่อมีจุดใหม่หรือตัวเลขเปลี่ยน',
      '',
      'เปิดแผนที่ดูว่าจุดไหนอยู่ตรงไหน พร้อมเส้นทางที่ควรเลี่ยง',
      v_site
    ], chr(10));

  elsif v_q in ('เมนู', 'พิมพ์อะไรได้บ้าง', 'คำสั่ง', 'ถามอะไรได้บ้าง') then
    return array_to_string(array[
      '🤖 พิมพ์คำเหล่านี้ได้เลย',
      '',
      'สรุปวันนี้     อุบัติเหตุวันนี้',
      'สรุปสัปดาห์   รอบเจ็ดวันล่าสุด',
      'สรุปเดือน     ตั้งแต่ต้นเดือนถึงวันนี้',
      'สรุปปี         ตั้งแต่ต้นปีถึงวันนี้',
      'ฝน            ฝนรอบตัวเมืองตอนนี้',
      'จุดเสี่ยง       จุดที่เกิดเหตุซ้ำ',
      '',
      'ทุกคำตอบนับจากข้อมูลจริง ณ เวลาที่ถาม'
    ], chr(10));
  end if;

  return null;
end;
$fn$;

-- ==========================================================
-- 4  ต่อเข้ากับตัวตอบเดิม โดยแตะให้น้อยที่สุด
-- ==========================================================
-- อ่านโค้ดที่ติดตั้งอยู่จริงมาแก้ แล้วติดตั้งกลับ
-- ไม่พิมพ์ line_reply ใหม่ทั้งตัว เพราะข้างในมีตรรกะกิจกรรมแจกหมวก
-- ที่พิมพ์ผิดตัวเดียวแล้วคนไม่ได้รับหมวก
--
-- นับจำนวนจุดยึดก่อนแทนที่ ถ้าไม่เจอพอดีหนึ่งแห่งให้หยุดทั้งไฟล์
-- ไฟล์นี้ทั้งไฟล์อยู่ในรายการเดียว ถ้าหยุดกลางทางจะไม่มีอะไรถูกติดตั้งเลย

do $fn$
declare
  v_src text;
  v_crlf text := chr(13) || chr(10);
  v_a1 text;
  v_a2 text;
  v_n int;
begin
  select pg_get_functiondef(p.oid) into v_src
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'line_reply';

  if v_src is null then
    raise exception 'ไม่พบฟังก์ชัน line_reply';
  end if;

  if position('line_pub_answer' in v_src) > 0 then
    raise notice 'ต่อไว้แล้ว ไม่ต้องทำซ้ำ';
    return;
  end if;

  -- จุดยึดที่หนึ่ง  เพิ่มตัวแปรเก็บคำตอบ
  v_a1 := '  v_end     date;';
  v_n := (length(v_src) - length(replace(v_src, v_a1, ''))) / length(v_a1);
  if v_n <> 1 then
    raise exception 'จุดยึดที่หนึ่งพบ % แห่ง ไม่ใช่ 1 แห่ง จึงไม่แก้', v_n;
  end if;
  v_src := replace(v_src, v_a1, v_a1 || v_crlf || '  v_pub     text;');

  -- จุดยึดที่สอง  แทรกการตอบคำถามประชาชนก่อนตรรกะเดิม
  v_a2 := '  -- ---------- ของเดิม ไม่แก้อะไรเลย ----------';
  v_n := (length(v_src) - length(replace(v_src, v_a2, ''))) / length(v_a2);
  if v_n <> 1 then
    raise exception 'จุดยึดที่สองพบ % แห่ง ไม่ใช่ 1 แห่ง จึงไม่แก้', v_n;
  end if;
  v_src := replace(v_src, v_a2,
    '  -- คำถามของประชาชน ตอบด้วยตัวเลขสดจากฐานข้อมูล' || v_crlf ||
    '  -- วางไว้ก่อนตรรกะเดิม เพราะไม่ต้องพึ่งตาราง line_keywords' || v_crlf ||
    '  v_pub := line_pub_answer(v_q);' || v_crlf ||
    '  if v_pub is not null then' || v_crlf ||
    '    return jsonb_build_object(''action'', ''pub'', ''text'', v_pub);' || v_crlf ||
    '  end if;' || v_crlf || v_crlf ||
    v_a2);

  execute v_src;
  raise notice 'ต่อเข้ากับ line_reply แล้ว';
end;
$fn$;

-- ==========================================================
-- ตรวจผล  คำสั่งสุดท้ายคำสั่งเดียวที่จะแสดงผล
-- ==========================================================
-- เรียกของจริงออกมาดู จะได้เห็นว่าตัวเลขขึ้นถูกต้องก่อนบอกประชาชน

select 'ต่อเข้ากับตัวตอบแล้วหรือยัง' as รายการ,
       coalesce((select case when prosrc like '%line_pub_answer%' then 'ต่อแล้ว' else 'ยังไม่ต่อ' end
                 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                 where n.nspname='public' and p.proname='line_reply'), 'ไม่พบ') as ผล
union all
select 'ลองถาม  สรุปวันนี้', coalesce(line_pub_answer('สรุปวันนี้'), 'ไม่ตอบ')
union all
select 'ลองถาม  สรุปเดือน', coalesce(line_pub_answer('สรุปเดือน'), 'ไม่ตอบ')
union all
select 'ลองถาม  สรุปปี', coalesce(line_pub_answer('สรุปปี'), 'ไม่ตอบ')
union all
select 'ลองถาม  ฝน', coalesce(line_pub_answer('ฝน'), 'ไม่ตอบ')
union all
select 'ลองถาม  เมนู', coalesce(line_pub_answer('เมนู'), 'ไม่ตอบ')
union all
select 'ลองถามคำที่ไม่รู้จัก', coalesce(line_pub_answer('สวัสดี'), 'ไม่ตอบ ซึ่งถูกต้อง');
