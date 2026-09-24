-- ============================================================
-- รวมชื่อถนน  ไฟล์ 7c จาก 3  ข้อความสรุปรายสัปดาห์
-- ============================================================
-- รันหลัง 7a และ 7b
--
-- ห้ามมีปีกกาในไฟล์นี้ ตัวแก้ไขจะเติมแบ็กสแลชให้
-- ก่อนกด Run ให้ลบสิ่งที่ตัวแก้ไขเติมไว้ท้ายสุดออกก่อน เป็นดอลลาร์ตามด้วยเลขศูนย์
--
-- ทับฟังก์ชันเดิมทั้งตัว  ที่เปลี่ยนมีแค่ส่วนจัดอันดับถนน ให้ตรงกับ 7b
-- ภาพกับข้อความอยู่ในโพสต์เดียวกัน ถ้านับคนละแบบคนอ่านจะเห็นตัวเลขขัดกันเอง

create or replace function fb_weekly_text(p_days int default 7)
returns text
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_from  timestamptz;
  v_acc   int;
  v_die   int;
  v_hurt  int;
  v_bad   int;
  v_roads text;
  v_cause text;
  v_site  text;
  v_head  text;
  v_out   text;
begin
  if p_days is null or p_days < 1 or p_days > 92 then
    p_days := 7;
  end if;
  v_from := now() - make_interval(days => p_days);

  select count(*) into v_acc  from accidents where incident_datetime >= v_from;
  select count(*) into v_die  from deaths    where incident_datetime >= v_from;
  select count(*) into v_hurt from injuries  where incident_datetime >= v_from;

  -- นับเฉพาะสาหัสกับหมดสติ  ใช้คำเดียวกับที่หน้าบันทึกเหตุใช้ ห้ามเปลี่ยนคำ
  select count(*) into v_bad from injuries
   where incident_datetime >= v_from
     and coalesce(raw ->> 'severity', '') in ('สาหัส', 'หมดสติ');

  -- ถนนสามอันดับแรก  จัดกลุ่มด้วยชื่อกลางเหมือนที่การ์ดใช้
  -- ขึ้นบรรทัดด้วย chr(10) ไม่ใช้อักขระหลีก
  -- เพราะแบ็กสแลชในไฟล์เอสคิวแอลของโปรเจกต์นี้เคยทำให้ของพังมาแล้ว
  select string_agg(t.nm || '  ' || t.c || ' ครั้ง', chr(10) order by t.c desc)
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

  select val #>> array[]::text[] into v_site from bs_settings where key = 'publicSiteUrl';

  v_head := 'สรุปสถานการณ์อุบัติเหตุ สภ.เมืองนครสวรรค์' || chr(10) ||
    'รอบ ' || p_days || ' วัน  ' ||
    to_char(v_from at time zone 'Asia/Bangkok', 'DD/MM/') ||
    (extract(year from (v_from at time zone 'Asia/Bangkok'))::int + 543)::text ||
    ' ถึง ' ||
    to_char(now() at time zone 'Asia/Bangkok', 'DD/MM/') ||
    (extract(year from (now() at time zone 'Asia/Bangkok'))::int + 543)::text;

  -- รอบที่เงียบก็ยังโพสต์ได้ และควรโพสต์ เพราะเป็นข่าวดี
  if v_acc = 0 and v_die = 0 and v_hurt = 0 then
    return v_head || chr(10) || chr(10) ||
      'รอบนี้ไม่มีอุบัติเหตุที่บันทึกไว้ในระบบ' || chr(10) || chr(10) ||
      'ขับขี่ปลอดภัย สวมหมวกนิรภัย คาดเข็มขัดนิรภัย';
  end if;

  v_out := v_head || chr(10) || chr(10) ||
    'อุบัติเหตุ ' || v_acc || ' ครั้ง' || chr(10) ||
    'เสียชีวิต ' || v_die || ' ราย'  || chr(10) ||
    'บาดเจ็บ '  || v_hurt || ' ราย';

  if v_bad > 0 then
    v_out := v_out || '  ในจำนวนนี้อาการสาหัส ' || v_bad || ' ราย';
  end if;

  if v_roads is not null then
    v_out := v_out || chr(10) || chr(10) || 'ถนนที่เกิดเหตุมากที่สุด' || chr(10) || v_roads;
  end if;

  if coalesce(v_cause, '') <> '' then
    v_out := v_out || chr(10) || chr(10) || 'สาเหตุที่พบบ่อยที่สุด  ' || v_cause;
  end if;

  if coalesce(v_site, '') <> '' then
    v_out := v_out || chr(10) || chr(10) || 'ดูจุดเสี่ยงและสถิติทั้งหมดได้ที่' || chr(10) || v_site;
  end if;

  return v_out || chr(10) || chr(10) ||
    'ขับขี่ปลอดภัย สวมหมวกนิรภัย คาดเข็มขัดนิรภัย';
end;
$fn$;

revoke execute on function fb_weekly_text(int) from public, anon, authenticated;

-- ตรวจ  อ่านข้อความที่จะโพสต์จริง โดยยังไม่มีอะไรถูกส่งออกไป
-- ชื่อถนนในข้อความต้องตรงกับที่ขึ้นบนการ์ดทุกบรรทัด
select fb_weekly_text(7) as ข้อความที่จะโพสต์;

-- จบไฟล์  อย่าเคาะบรรทัดใหม่ต่อท้ายบรรทัดนี้ ->
