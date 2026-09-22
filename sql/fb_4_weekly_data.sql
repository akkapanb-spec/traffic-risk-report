-- ============================================================
-- โพสต์เฟซบุ๊กอัตโนมัติ  ตัวเลขสำหรับการ์ดสรุปรายสัปดาห์
-- ============================================================
-- ห้ามมีปีกกาในไฟล์นี้ ตัวแก้ไขจะเติมแบ็กสแลชให้
-- ก่อนกด Run ให้ลบสิ่งที่ตัวแก้ไขเติมไว้ท้ายสุดออกก่อน เป็นดอลลาร์ตามด้วยเลขศูนย์
--
-- ฟังก์ชันนี้ไม่ส่งอะไรออกไปข้างนอก คืนมาแค่ตัวเลข รันดูกี่ครั้งก็ได้
--
-- ใช้คู่กับตัววาดภาพชื่อ fbcard  ตัววาดภาพเรียกฟังก์ชันนี้ แล้วเขียนตัวเลขลงบนแบบการ์ด
-- ตัวเลขทุกตัวนับด้วยเงื่อนไขเดียวกับ fb_weekly_text ทุกประการ
-- ถ้าแก้ที่ไฟล์นี้ ต้องแก้ที่ fb_1c_weekly.sql ให้ตรงกันด้วย
-- ไม่อย่างนั้นภาพกับข้อความในโพสต์เดียวกันจะบอกตัวเลขคนละชุด
--
-- ในการ์ดเขียนว่า สาหัส  แต่นับสาหัสรวมหมดสติ เหมือนที่ข้อความสรุปนับ
-- เพราะหมดสติคืออาการที่หนักไม่น้อยกว่าสาหัส และระบบนับสองคำนี้รวมกันมาตลอด

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

  -- ถนนสามอันดับแรก เรียงมากไปน้อย  ชื่อถนนใช้ค่าที่บันทึกไว้ทั้งก้อน
  -- ไม่ตัดท้ายที่ขีดทับ เพราะในเขตเทศบาลกับนอกเขตเทศบาลเป็นคนละจุดกัน
  select jsonb_agg(jsonb_build_object('name', t.nm, 'n', t.c) order by t.c desc)
    into v_roads
    from (
      select coalesce(nullif(trim(road), ''), 'ไม่ระบุถนน') as nm, count(*) as c
        from accidents
       where incident_datetime >= v_from
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

  -- ช่วงวันที่เป็นพุทธศักราช เดือนย่อภาษาไทย  เดือนเดียวกันบอกเดือนครั้งเดียว
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

-- ตัววาดภาพเรียกด้วยกุญแจฝั่งเซิร์ฟเวอร์ ไม่ใช่กุญแจของหน้าเว็บ
revoke execute on function fb_weekly_data(int) from public, anon, authenticated;

-- ตรวจ  อ่านตัวเลขที่จะขึ้นบนการ์ดได้เลย โดยยังไม่มีอะไรถูกส่งออกไป
select fb_weekly_data(7) as ตัวเลขบนการ์ด;

-- จบไฟล์  อย่าเคาะบรรทัดใหม่ต่อท้ายบรรทัดนี้ ->
