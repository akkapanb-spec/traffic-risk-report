-- แก้ #ac-r ที่ไม่เคยตอบเลย  ด้วยการเตรียมคำตอบไว้ล่วงหน้าแทนการคำนวณสด
-- ถ้ามีอักขระแปลกปลอมต่อท้ายบรรทัดสุดท้าย ให้ลบออกก่อนกด Run
-- ไม่ต้อง deploy Edge Function  แก้ที่ฐานข้อมูลอย่างเดียว
--
-- ============================================================
-- อาการ และหลักฐาน
-- ============================================================
-- 10 ก.ย. 2569 ผู้ใช้พิมพ์ #ac-r สองครั้ง บอทเงียบทั้งสองครั้ง
-- ขณะที่ #ac-w #ac-m #ac-y #help ตอบได้ปกติทุกคำสั่งในนาทีเดียวกัน
--
-- บันทึกของเซิร์ฟเวอร์
--   10:40:53   POST /rpc/line_reply
--   10:40:57   canceling statement due to statement timeout   รหัส 57014
--   10:40:57   POST 500 /rpc/line_reply
-- เกิดซ้ำแบบเดียวกันตอน 10:41:09 ถึง 10:41:12
--
-- บทบาท anon ที่บอทใช้ ถูกตั้ง statement_timeout ไว้ 3 วินาที
-- แต่ line_hotspot_build จัดกลุ่มอุบัติเหตุ 30 วันด้วยระยะถนน ใช้เวลาราว 4 วินาที
-- จึงถูกตัดทิ้งทุกครั้ง  ไม่ใช่เพิ่งพัง แต่ไม่เคยทำงานเลยตั้งแต่ติดตั้ง
--
-- ------------------------------------------------------------
-- ทำไมไม่แก้ด้วยการขยายเวลาให้ anon
-- ------------------------------------------------------------
-- anon คือบทบาทที่หน้าเว็บของประชาชนใช้ด้วย ไม่ใช่ของบอทอย่างเดียว
-- ขยายเป็นสิบวินาทีแปลว่าคำสั่งที่ค้างจะกอดการเชื่อมต่อไว้นานสิบวินาที
-- คนเข้าพร้อมกันหลายคนตอนฝนตก การเชื่อมต่อจะหมดก่อน แล้วทั้งหน้าเว็บจะล่ม
-- ขีดจำกัดสามวินาทีมีไว้ปกป้องสิ่งนั้น ไม่ควรถอดออกเพื่อคำสั่งเดียว
--
-- และต่อให้ขยายวันนี้พอ พรุ่งนี้ข้อมูลมากขึ้นก็จะช้าขึ้นอีก
-- การไล่ขยายเวลาตามข้อมูลที่โตขึ้นเรื่อย ๆ ไม่ใช่การแก้ปัญหา
--
-- ------------------------------------------------------------
-- วิธีที่ใช้  คำนวณไว้ก่อน แล้วให้คำสั่งแค่หยิบไปตอบ
-- ------------------------------------------------------------
-- งานหนักย้ายไปอยู่ในงานตามเวลา ซึ่งรันด้วยสิทธิ์ที่ไม่มีขีดจำกัดสามวินาที
-- คำสั่ง #ac-r เหลือแค่อ่านหนึ่งแถว ซึ่งใช้เวลาไม่ถึงหนึ่งในพันวินาที
-- จะช้าแค่ไหนในอนาคตก็ไม่กระทบเวลาตอบอีกต่อไป
--
-- รีเฟรชทุกชั่วโมง ซึ่งละเอียดเกินพอ เพราะข้อมูลเปลี่ยนเฉพาะตอนเจ้าหน้าที่บันทึกเหตุ
-- และรายงานนี้เองก็ส่งเข้ากลุ่มสัปดาห์ละครั้งอยู่แล้ว
--
-- คำตอบจะบอกเวลาที่คำนวณกำกับไว้ด้วย คนอ่านจะได้รู้ว่าข้อมูลสดแค่ไหน
-- ไม่ใช่เดาเอาเองว่าเป็นวินาทีนี้
--
-- ------------------------------------------------------------
-- เรื่องที่ยังไม่ได้แก้ และอยากให้รู้ไว้
-- ------------------------------------------------------------
-- ตัวรับ webhook เขียนบันทึกว่า ไม่เข้าคีย์เวิร์ด จึงเงียบ ทั้งสองกรณี
-- คือกรณีที่ไม่ใช่คีย์เวิร์ดจริง ๆ และกรณีที่เรียกฐานข้อมูลแล้วพัง
-- สองอย่างนี้ต้องแก้คนละวิธีสิ้นเชิง แต่บันทึกบอกเหมือนกัน
-- ทำให้ไล่หาสาเหตุครั้งนี้ช้ากว่าที่ควร
-- แก้ได้แต่ต้อง deploy Edge Function ใหม่ ซึ่งเป็นขั้นที่พังง่ายที่สุดในระบบนี้
-- จึงแยกไว้ทำต่างหาก ไม่รวมมาในไฟล์นี้

-- ==========================================================
-- 1  ที่เก็บคำตอบที่คำนวณไว้แล้ว
-- ==========================================================
-- เก็บทั้งก้อน jsonb ที่ line_hotspot_build คืนมา ไม่ได้เก็บแค่ข้อความ
-- เพราะผู้เรียกต้องดู found ก่อนว่ามีจุดเข้าเกณฑ์ไหม
-- ถ้าเก็บแค่ข้อความจะแยกไม่ออกระหว่างไม่มีจุด กับคำนวณไม่สำเร็จ

create table if not exists line_hotspot_cache (
  id       int primary key,
  body     jsonb not null,
  built_at timestamptz not null default now(),
  took_ms  int
);

alter table line_hotspot_cache enable row level security;
revoke all on line_hotspot_cache from anon, authenticated;

-- ==========================================================
-- 2  ตัวคำนวณและเก็บ
-- ==========================================================
-- ให้เฉพาะงานตามเวลาเรียก ประชาชนเรียกไม่ได้
-- ถ้าเปิดให้เรียกได้ ใครก็สั่งให้ฐานข้อมูลทำงานหนักซ้ำ ๆ ได้ตามใจ

create or replace function line_hotspot_refresh()
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_t0 timestamptz := clock_timestamp();
  v_h  jsonb;
  v_ms int;
begin
  v_h  := line_hotspot_build();
  v_ms := round(extract(epoch from (clock_timestamp() - v_t0)) * 1000);

  insert into line_hotspot_cache (id, body, built_at, took_ms)
  values (1, v_h, now(), v_ms)
  on conflict (id) do update
    set body = excluded.body, built_at = excluded.built_at, took_ms = excluded.took_ms;

  return jsonb_build_object(
    'ok', true,
    'found', coalesce((v_h->>'found')::int, 0),
    'tookMs', v_ms);
end;
$fn$;

revoke execute on function line_hotspot_refresh() from anon, authenticated;

-- ==========================================================
-- 3  คำนวณรอบแรกทันที
-- ==========================================================
-- ไฟล์นี้รันด้วยสิทธิ์ที่ไม่มีขีดจำกัดสามวินาที จึงคำนวณตรงนี้ได้
-- ถ้าไม่ทำ #ac-r จะยังเงียบไปอีกหนึ่งชั่วโมงจนกว่างานตามเวลาจะรันรอบแรก

select line_hotspot_refresh();

-- ==========================================================
-- 4  คำสั่งตอบคีย์เวิร์ด  เปลี่ยนเฉพาะ ac-r
-- ==========================================================
-- อีกสี่คำสั่งไม่แตะเลยแม้แต่ตัวอักษรเดียว คัดมาจากที่ติดตั้งอยู่จริง

create or replace function line_pub_answer(p_q text)
returns text
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_q  text := lower(btrim(coalesce(p_q, '')));
  v_h  jsonb;
  v_at timestamptz;
  v_when text;
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

    -- หยิบคำตอบที่คำนวณไว้แล้ว ไม่คำนวณสด
    -- นี่คือบรรทัดเดียวที่ทำให้คำสั่งนี้ไม่ชนขีดจำกัดสามวินาทีอีกต่อไป
    select body, built_at into v_h, v_at from line_hotspot_cache where id = 1;

    if v_h is null then
      return array_to_string(array[
        '⚠️ จุดอุบัติเหตุซ้ำในรอบ 30 วัน',
        '',
        'ระบบกำลังประมวลผลรอบแรก',
        'รบกวนลองใหม่อีกครั้งในอีกสักครู่ครับ'
      ], chr(10));
    end if;

    v_when := 'ข้อมูล ณ ' ||
              to_char(v_at at time zone 'Asia/Bangkok', 'DD/MM/') ||
              (extract(year from v_at at time zone 'Asia/Bangkok')::int + 543) ||
              ' เวลา ' || to_char(v_at at time zone 'Asia/Bangkok', 'HH24:MI') || ' น.';

    if coalesce((v_h->>'found')::int, 0) = 0 then
      return array_to_string(array[
        '⚠️ จุดอุบัติเหตุซ้ำในรอบ 30 วัน',
        '',
        'ยังไม่มีจุดใดเข้าเกณฑ์ในรอบ 30 วันที่ผ่านมา',
        'ซึ่งเป็นเรื่องดี',
        '',
        v_when
      ], chr(10));
    end if;

    return (v_h->>'text') || chr(10) || chr(10) || v_when;
  end if;

  return null;
end;
$fn$;

-- ==========================================================
-- 5  งานตามเวลา  รีเฟรชทุกชั่วโมง
-- ==========================================================
-- ลบของเดิมก่อนถ้ามี กันสร้างซ้อนกันหลายตัวเวลารันไฟล์นี้ซ้ำ

do $fn$
begin
  perform cron.unschedule('hotspot-cache');
exception when others then
  raise notice 'ยังไม่เคยมีงานนี้ ข้ามการลบ';
end;
$fn$;

select cron.schedule('hotspot-cache', '5 * * * *', 'select line_hotspot_refresh()');

-- ==========================================================
-- ตรวจผล  คำสั่งสุดท้ายคำสั่งเดียวที่จะแสดงผล
-- ==========================================================

select 'คำนวณไว้แล้วเมื่อ' as รายการ,
  coalesce((select to_char(built_at at time zone 'Asia/Bangkok','DD/MM HH24:MI:SS') ||
            '   ใช้เวลา ' || took_ms || ' มิลลิวินาที'
            from line_hotspot_cache where id = 1), 'ยังไม่มี') as ผล
union all
select 'ใช้เวลาเทียบกับขีดจำกัดของ anon',
  coalesce((select case when took_ms > 3000
                        then took_ms || ' มิลลิวินาที  เกิน 3000 จริง  นี่คือสาเหตุที่เคยเงียบ'
                        else took_ms || ' มิลลิวินาที  ไม่เกิน 3000' end
            from line_hotspot_cache where id = 1), '-')
union all
select 'จุดที่เข้าเกณฑ์ตอนนี้',
  coalesce((select (body->>'found') || ' จุด' from line_hotspot_cache where id = 1), '-')
union all
select 'ac-r อ่านจากที่เก็บแล้ว',
  coalesce((select case when prosrc like '%line_hotspot_cache%' then 'ใช่' else 'ยังคำนวณสดอยู่ ต้องแก้' end
            from pg_proc p join pg_namespace n on n.oid=p.pronamespace
            where n.nspname='public' and p.proname='line_pub_answer'),'ไม่พบ')
union all
select 'คีย์เวิร์ดที่ยังรับได้',
  coalesce((select string_agg(k, '  ') from (
              select unnest(array['#ac-w','#ac-m','#ac-y','#help','#ac-r']) as k
            ) z
            where exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
                          where n.nspname='public' and p.proname='line_pub_answer'
                            and p.prosrc like '%' || z.k || '%')), 'ไม่พบ')
union all
select 'งานตามเวลา',
  coalesce((select jobname || '  [' || schedule || ']  ' ||
            case when active then 'เปิด' else 'ปิด' end
            from cron.job where jobname = 'hotspot-cache'), 'ไม่พบ')
union all
select 'ทดลองเรียกจริง',
  left(replace(coalesce(line_pub_answer('#ac-r'), 'ไม่มีคำตอบ'), chr(10), ' / '), 150)
union all
select 'ขั้นต่อไป', 'พิมพ์ #ac-r ในแชทกับ OA ชอนตะวัน TF Police ต้องตอบแล้ว';
