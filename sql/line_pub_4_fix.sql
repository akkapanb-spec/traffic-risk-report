-- คืนตัวจับคีย์เวิร์ดให้ครบห้าคำ
-- ถ้ามีอักขระแปลกปลอมต่อท้ายบรรทัดสุดท้าย ให้ลบออกก่อนกด Run
--
-- ทำไมต้องมีไฟล์นี้
--   line_pub_2_msgs.sql กับ line_pub_3_hotspot.sql ต่างก็สร้าง line_pub_answer
--   ไฟล์ 2 รันทีหลัง จึงสร้างทับฉบับที่รู้จัก ac-r กับ help
--   ผลคือพิมพ์ ac-r แล้วบอทเงียบ ทั้งที่ตัวสร้างข้อความติดตั้งครบแล้ว
--
--   ไฟล์ 2 ในคลังถูกแก้ให้ไม่สร้างตัวจับคีย์เวิร์ดอีกแล้ว
--   ไฟล์นี้เอาไว้แก้ของที่ติดตั้งไปแล้วให้กลับมาครบ

create or replace function line_pub_answer(p_q text)
returns text
language plpgsql
volatile
security definer
set search_path = public
as $fn$
declare
  v_q text := lower(btrim(coalesce(p_q, '')));
  v_h jsonb;
begin
  if v_q = '' then return null; end if;

  if v_q = '#ac-w' then
    return line_msg_ac_w();
  elsif v_q = '#ac-m' then
    return line_msg_ac_m();
  elsif v_q = '#ac-y' then
    return line_msg_ac_y();
  elsif v_q = '#help' then
    return line_msg_help();
  elsif v_q = '#ac-r' then
    v_h := line_hotspot_build();
    if coalesce((v_h->>'found')::int, 0) = 0 then
      return array_to_string(array[
        '⚠️ จุดอุบัติเหตุซ้ำในรอบ 30 วัน',
        '',
        'ยังไม่มีจุดใดเข้าเกณฑ์ในรอบ 30 วันที่ผ่านมา',
        'ซึ่งเป็นเรื่องดี'
      ], chr(10));
    end if;
    return v_h->>'text';
  end if;

  return null;
end;
$fn$;

-- ==========================================================
-- ตรวจผล  คำสั่งสุดท้ายคำสั่งเดียวที่จะแสดงผล
-- ==========================================================

select 'คีย์เวิร์ดที่รับได้ตอนนี้' as รายการ,
       coalesce((select string_agg(m[1], '  ') from pg_proc p
                 join pg_namespace n on n.oid = p.pronamespace,
                 lateral regexp_matches(p.prosrc, 'v_q = ''(#[a-z-]+)''', 'g') m
                 where n.nspname = 'public' and p.proname = 'line_pub_answer'), 'ไม่พบ') as ผล
union all
select 'ทดสอบ ac-r', left(coalesce(line_pub_answer('#ac-r'), 'ไม่ตอบ'), 120)
union all
select 'ทดสอบ help', left(coalesce(line_pub_answer('#help'), 'ไม่ตอบ'), 120);
