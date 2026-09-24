-- ============================================================
-- รวมชื่อถนน  ไฟล์ 7b จาก 3  ตัวเลขบนการ์ดสรุปรายสัปดาห์
-- ============================================================
-- รันหลัง 7a เท่านั้น เพราะเรียก fb_road_key กับ fb_road_label
--
-- ห้ามมีปีกกาในไฟล์นี้ ตัวแก้ไขจะเติมแบ็กสแลชให้
-- ก่อนกด Run ให้ลบสิ่งที่ตัวแก้ไขเติมไว้ท้ายสุดออกก่อน เป็นดอลลาร์ตามด้วยเลขศูนย์
--
-- ทับฟังก์ชันเดิมทั้งตัว  ที่เปลี่ยนมีแค่ส่วนจัดอันดับถนน
-- ตัวเลขอุบัติเหตุ เสียชีวิต บาดเจ็บ สาหัส และสาเหตุ นับเหมือนเดิมทุกอย่าง
--
-- ต้องแก้คู่กับ 7c เสมอ ไม่งั้นภาพกับข้อความในโพสต์เดียวกันจะบอกถนนคนละชุด

create or replace function fb_weekly_data(p_days int default 7)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_from  timestamptz;
  v_f     date;
  v_t     date;
  v_acc   int;
  v_die   int;
  v_hurt  int;
  v_bad   int;
  v_roads jsonb;
  v_cause text;
  v_range text;
  v_mon   text[] := array[
    'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
    'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'];
begin
  if p_days is null or p_days < 1 or p_days > 92 then
    p_days := 7;
  end if;
  v_from := now() - make_interval(days => p_days);

  select count(*) into v_acc  from accidents where incident_datetime >= v_from;
  select count(*) into v_die  from deaths    where incident_datetime >= v_from;
  select count(*) into v_hurt from injuries  where incident_datetime >= v_from;

  select count(*) into v_bad from injuries
   where incident_datetime >= v_from
     and coalesce(raw ->> 'severity', '') in ('สาหัส', 'หมดสติ');

  -- ถนนสามอันดับแรก  จัดกลุ่มด้วยชื่อกลาง ไม่ใช่ข้อความที่กรอกมาดิบ ๆ
  -- เพราะถนนสายเดียวกันถูกกรอกทั้งแบบมีคำว่า ถนน นำหน้าและไม่มี
  select jsonb_agg(jsonb_build_object('name', t.nm, 'n', t.c) order by t.c desc)
    into v_roads
    from (
      select fb_road_label(fb_road_key(road)) as nm, count(*) as c
        from accidents
       where incident_datetime >= v_from
         and coalesce(btrim(road), '') <> ''
       group by 1
       order by count(*) desc
       limit 3
    ) t;

  select cause into v_cause
    from accidents
   where incident_datetime >= v_from
     and coalesce(trim(cause), '') <> ''
   group by cause
   order by count(*) desc
   limit 1;

  v_f := (v_from at time zone 'Asia/Bangkok')::date;
  v_t := (now()   at time zone 'Asia/Bangkok')::date;

  if extract(month from v_f) = extract(month from v_t)
     and extract(year from v_f) = extract(year from v_t) then
    v_range := extract(day from v_f)::int || ' - ' || extract(day from v_t)::int || ' ' ||
               v_mon[extract(month from v_t)::int] || ' ' ||
               (extract(year from v_t)::int + 543)::text;
  else
    v_range := extract(day from v_f)::int || ' ' || v_mon[extract(month from v_f)::int] ||
               ' - ' ||
               extract(day from v_t)::int || ' ' || v_mon[extract(month from v_t)::int] || ' ' ||
               (extract(year from v_t)::int + 543)::text;
  end if;

  return jsonb_build_object(
    'days',      p_days,
    'range',     v_range,
    'accidents', v_acc,
    'deaths',    v_die,
    'injuries',  v_hurt,
    'serious',   v_bad,
    'roads',     coalesce(v_roads, jsonb_build_array()),
    'cause',     coalesce(nullif(trim(coalesce(v_cause, '')), ''), ''));
end;
$fn$;

revoke execute on function fb_weekly_data(int) from public, anon, authenticated;

-- ตรวจ  ตัวเลขชุดนี้คือสิ่งที่จะขึ้นบนการ์ด  ดูช่อง roads ว่าไม่มีถนนซ้ำแล้ว
select fb_weekly_data(7) as ตัวเลขบนการ์ด;

-- จบไฟล์  อย่าเคาะบรรทัดใหม่ต่อท้ายบรรทัดนี้ ->
