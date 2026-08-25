-- ============================================================
-- รูปแบบข้อความสรุปรอบสัปดาห์ ตามที่กำหนดใหม่
-- ============================================================
-- เขียนทับฟังก์ชัน line_msg_weekly เดิมทั้งตัว ไม่แตะงานตั้งเวลา
-- ไม่ส่งอะไรออกไปตอนรัน
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
-- ถ้ามี $0 ค้างอยู่บรรทัดสุดท้าย ให้ลบทิ้งก่อนกด Run
-- ไฟล์นี้ไม่มีวงเล็บปีกกาเลยแม้แต่ตัวเดียว
--
-- สิ่งที่เปลี่ยน
--
--   1) ตัวเลขเทียบงวดก่อน ย่อให้สั้นลง
--      ของเดิมเขียนยาวแบบ (▲ +3 จาก 9) ซึ่งอ่านในไลน์แล้วรก
--      เปลี่ยนเป็น (▲ 3) (▼ 1) (▬) ตามที่กำหนด
--      ทำเป็นฟังก์ชันใหม่แยกต่างหาก ไม่แก้ของเดิม
--      เพราะข้อความสรุปรายวันกับตัวที่ตอบคีย์เวิร์ดยังใช้แบบยาวอยู่
--
--   2) ช่วงวันที่ ย่อไม่ให้ซ้ำชื่อเดือน
--      อยู่เดือนเดียวกัน  11 – 17 ส.ค. 2569
--      คนละเดือน         28 ก.ค. – 3 ส.ค. 2569
--      คนละปี            29 ธ.ค. 2569 – 4 ม.ค. 2570
--
--   3) เพิ่มรูปนำหน้าทุกบรรทัด คำคม ลิงก์หน้าเว็บ และคำลงท้าย
--
--   4) ลิงก์หน้าเว็บอ่านจากตารางตั้งค่า คีย์ publicSiteUrl
--      เปลี่ยนที่เดียวแล้วมีผลกับทุกข้อความ ทั้งรายสัปดาห์และเตือนภัยจุดเสี่ยง
--
-- หมายเหตุ รูปบาดเจ็บเล็กน้อยใช้หน้าพันแผล ซึ่งน่าจะตรงกับที่เรียกว่ามัมมี่
-- ถ้าหมายถึงรูปอื่น บอกได้ เปลี่ยนง่าย
-- ============================================================

-- ตัวเลขเทียบงวดก่อนแบบสั้น ใช้เฉพาะข้อความรายสัปดาห์
create or replace function line_delta_short(p_now int, p_prev int)
returns text language sql immutable set search_path = public, extensions as $lds$
  select case
    when p_now > p_prev then ' (▲ ' || (p_now - p_prev) || ')'
    when p_now < p_prev then ' (▼ ' || (p_prev - p_now) || ')'
    else ' (▬)'
  end;
$lds$;

create or replace function line_msg_weekly(p_end date default null)
returns text
language plpgsql stable security definer set search_path = public, extensions as $lmw$
declare
  v_end date := coalesce(p_end, line_today() - 1);
  v_start date;
  v_from timestamptz; v_to timestamptz; v_pfrom timestamptz;
  c jsonb; p jsonb;
  v_site text;
  v_range text;
  v_lines text[];
  v_th text[] := array['ม.ค.','ก.พ.','มี.ค.','เม.ย.','พ.ค.','มิ.ย.',
                       'ก.ค.','ส.ค.','ก.ย.','ต.ค.','พ.ย.','ธ.ค.'];
  v_m1 int; v_m2 int; v_y1 int; v_y2 int;
begin
  v_start := v_end - 6;
  v_from  := timezone('Asia/Bangkok', v_start::timestamp);
  v_to    := timezone('Asia/Bangkok', (v_end + 1)::timestamp);
  v_pfrom := timezone('Asia/Bangkok', (v_start - 7)::timestamp);

  c := line_acc_counts(v_from, v_to);
  p := line_acc_counts(v_pfrom, v_from);

  v_m1 := extract(month from v_start)::int;
  v_m2 := extract(month from v_end)::int;
  v_y1 := extract(year from v_start)::int + 543;
  v_y2 := extract(year from v_end)::int + 543;

  -- ไม่พิมพ์ชื่อเดือนหรือปีซ้ำถ้าไม่จำเป็น อ่านในไลน์แล้วสั้นกว่ามาก
  if v_y1 <> v_y2 then
    v_range := extract(day from v_start)::int || ' ' || v_th[v_m1] || ' ' || v_y1 ||
               ' – ' || extract(day from v_end)::int || ' ' || v_th[v_m2] || ' ' || v_y2;
  elsif v_m1 <> v_m2 then
    v_range := extract(day from v_start)::int || ' ' || v_th[v_m1] ||
               ' – ' || extract(day from v_end)::int || ' ' || v_th[v_m2] || ' ' || v_y2;
  else
    v_range := extract(day from v_start)::int ||
               ' – ' || extract(day from v_end)::int || ' ' || v_th[v_m2] || ' ' || v_y2;
  end if;

  v_site := coalesce(
    (select (val #>> array[]::text[]) from bs_settings where key = 'publicSiteUrl'), '');

  v_lines := array[
    '📊 สรุปอุบัติเหตุรอบสัปดาห์',
    '🗓️ ' || v_range,
    '',
    '🚨 อุบัติเหตุ ' || (c->>'accidents') || ' ครั้ง' ||
      line_delta_short((c->>'accidents')::int, (p->>'accidents')::int),
    '🚑 เสียชีวิต ' || (c->>'deaths') || ' ราย' ||
      line_delta_short((c->>'deaths')::int, (p->>'deaths')::int),
    '🩸 สาหัส/หมดสติ ' || (c->>'severe') || ' ราย' ||
      line_delta_short((c->>'severe')::int, (p->>'severe')::int),
    '🤕 บาดเจ็บเล็กน้อย ' || (c->>'minor') || ' ราย' ||
      line_delta_short((c->>'minor')::int, (p->>'minor')::int),
    '',
    '"อุบัติเหตุไม่เคยเลือกเวลา"',
    '"สถานที่และโอกาสให้บอกลา"'
  ];

  if v_site <> '' then
    v_lines := v_lines || array['', 'ติดตามรายละเอียด ได้ที่นี่', v_site];
  end if;

  v_lines := v_lines || array['', 'การสัญจรปลอดภัย คือความห่วงใยของเรา ❤️'];

  return array_to_string(v_lines, chr(10));
end $lmw$;

-- ============================================================
-- ดูข้อความจริงโดยไม่ส่งอะไรออกไป
-- ============================================================
--   select line_msg_weekly(current_date - 1);
--
-- ดูของสัปดาห์ที่แล้วเพื่อเทียบ
--   select line_msg_weekly(current_date - 8);
--
-- ตัวเลขเทียบงวดก่อนคือเทียบกับ 7 วันก่อนหน้าช่วงที่รายงาน
-- ▲ คือเพิ่มขึ้น ▼ คือลดลง ▬ คือเท่าเดิม
--
-- งานตั้งเวลาชื่อ line-weekly เดินเช้าวันจันทร์ 8 โมงเวลาบ้านเรา
-- รายงานช่วง 7 วันที่จบเมื่อวานนี้ คือจันทร์ถึงอาทิตย์ที่เพิ่งผ่านไป
-- ============================================================
