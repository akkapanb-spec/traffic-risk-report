-- ============================================================
-- โพสต์เฟซบุ๊กอัตโนมัติ  ไฟล์ที่ 1c จาก 3  ตัวสร้างข้อความสรุปรายสัปดาห์
-- ============================================================
-- รันเรียงตามลำดับ 1a 1b 1c  ห้ามข้าม
-- ไฟล์ละหนึ่งฟังก์ชัน จะได้รู้ทันทีว่าพังไฟล์ไหน
--
-- ห้ามมีปีกกาในไฟล์นี้ ตัวแก้ไขจะเติมแบ็กสแลชให้
-- ก่อนกด Run ให้ลบสิ่งที่ตัวแก้ไขเติมไว้ท้ายสุดออกก่อน เป็นดอลลาร์ตามด้วยเลขศูนย์
--
-- ฟังก์ชันนี้ไม่ส่งอะไรออกไปข้างนอกเลย คืนมาแค่ข้อความ
-- รันดูกี่ครั้งก็ได้ ปลอดภัย และไม่มีอะไรโผล่ไปที่เพจ
--
-- ตั้งใจให้เป็นตัวเลขรวมล้วน ไม่มีชื่อ อายุ เพศ หรือบทบาทของใครเลย
-- เพราะเพจเฟซบุ๊กเป็นสาธารณะถาวร ค้นเจอด้วยกูเกิล และแคปไปแชร์ต่อได้
-- ต่างจากกลุ่มไลน์ที่เป็นวงจำกัดและกดออกได้
-- รายละเอียดรายบุคคลให้อยู่ในไลน์ต่อไป อย่าย้ายมาที่นี่

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

  -- ถนนสามอันดับแรก  ขึ้นบรรทัดด้วย chr(10) ไม่ใช้อักขระหลีก
  -- เพราะแบ็กสแลชในไฟล์เอสคิวแอลของโปรเจกต์นี้เคยทำให้ของพังมาแล้ว
  select string_agg(t.nm || '  ' || t.c || ' ครั้ง', chr(10) order by t.c desc)
    into v_roads
    from (
      select coalesce(nullif(trim(road), ''), 'ไม่ระบุถนน') as nm, count(*) as c
        from accidents
       where incident_datetime >= v_from
       group by 1
       order by count(*) desc
       limit 3
    ) t;

  -- สาเหตุที่พบบ่อยที่สุดเพียงอันดับเดียว  ข้ามแถวที่ไม่ได้กรอกสาเหตุไว้
  select cause into v_cause
    from accidents
   where incident_datetime >= v_from
     and coalesce(trim(cause), '') <> ''
   group by cause
   order by count(*) desc
   limit 1;

  select val #>> array[]::text[] into v_site from bs_settings where key = 'publicSiteUrl';

  -- ช่วงวันที่เป็นพุทธศักราช เพราะหน้าเว็บฝั่งประชาชนใช้พุทธศักราชอยู่แล้ว
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

-- ไม่ให้หน้าเว็บสาธารณะเรียก  ข้อความนี้มีไว้ให้ระบบหลังบ้านใช้
revoke execute on function fb_weekly_text(int) from public, anon, authenticated;

-- ตรวจ  อ่านข้อความที่จะโพสต์จริงได้เลย โดยยังไม่มีอะไรถูกส่งออกไป
-- อยากดูรอบยาวกว่านี้ เปลี่ยนเลขในวงเล็บได้ เช่น 30
select fb_weekly_text(7) as ข้อความที่จะโพสต์;

-- จบไฟล์  อย่าเคาะบรรทัดใหม่ต่อท้ายบรรทัดนี้ ->