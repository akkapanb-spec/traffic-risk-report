-- ============================================================
-- กิจกรรมชวนเพื่อน  ตรวจเร็วขึ้น  ไฟล์ 13a จาก 3  ตรวจซ้ำคนที่ยังไม่ผ่าน
-- ============================================================
-- รันเรียง 13a 13b 13c  ห้ามข้าม
--
-- ปัญหาเดิม  ตรวจแล้วรออีก 6 ชั่วโมงกว่าจะตรวจใหม่ ไม่ว่าผลจะเป็นอย่างไร
-- คนที่ส่งรหัสก่อนแล้วค่อยกดเข้ากลุ่มทีหลัง จึงค้างเป็นไม่ผ่านไปอีก 6 ชั่วโมง
-- ยิ่งตรวจถี่ ยิ่งเจอบ่อย เพราะจะถูกตรวจก่อนทันเข้ากลุ่ม
--
-- แก้  คนที่ยังไม่ผ่านครบทั้งสองข้อ และเข้าร่วมมาไม่เกิน 3 วัน ตรวจซ้ำทุก campRetryMinutes นาที
-- คนที่ผ่านแล้วยังตรวจซ้ำทุก 6 ชั่วโมงเหมือนเดิม ไว้จับคนที่ออกจากกลุ่มทีหลัง
--
-- คงชื่อและพารามิเตอร์ของฟังก์ชันไว้เหมือนเดิมทุกตัว
-- ถ้าเพิ่มพารามิเตอร์จะกลายเป็นฟังก์ชันซ้อนสองตัว งานตามเวลาที่เรียกแบบไม่ใส่ค่า
-- จะหาไม่ได้ว่าต้องใช้ตัวไหน แล้วหยุดตรวจทั้งกิจกรรมโดยไม่มีใครรู้
--
-- เนื้อฟังก์ชันคัดมาจาก camp_8_period.sql ตัวล่าสุดใน sql  เปลี่ยนเฉพาะเงื่อนไขเลือกคน
-- ตัวถามไลน์เป็นการอ่านข้อมูล ไม่กินโควตาข้อความ
--
-- ห้ามมีปีกกาในไฟล์นี้ ตัวแก้ไขจะเติมแบ็กสแลชให้
-- ก่อนกด Run ให้ลบสิ่งที่ตัวแก้ไขเติมไว้ท้ายสุดออกก่อน เป็นดอลลาร์ตามด้วยเลขศูนย์

insert into bs_settings(key, val) values ('campRetryMinutes', '10'::jsonb)
on conflict (key) do nothing;

create or replace function camp_check_fire(p_limit int default 60, p_stale_hours int default 6)
returns int
language plpgsql
volatile
security definer
set search_path = public
as $fn$
declare
  v_group text;
  v_tok   text;
  v_n     int := 0;
  v_retry int := greatest(1, camp_cfg('campRetryMinutes', '10')::int);
  r       record;
  v_req   bigint;
begin
  if not camp_open() then
    return 0;
  end if;

  v_group := camp_cfg('campGroupId', '');
  if v_group = '' then
    raise notice 'ยังไม่ได้ตั้ง campGroupId จึงยังตรวจการอยู่ในกลุ่มไม่ได้';
    return 0;
  end if;

  v_tok := line_token();

  for r in
    select line_user_id
      from camp_members
     where checked_at is null
        or checked_at < now() - make_interval(hours => p_stale_hours)
        or (    (is_friend is not true or in_group is not true)
            and created_at > now() - make_interval(days => 3)
            and checked_at < now() - make_interval(mins => v_retry))
     order by checked_at nulls first
     limit p_limit
  loop
    select net.http_get(
             url := 'https://api.line.me/v2/bot/profile/' || r.line_user_id,
             headers := jsonb_build_object('Authorization', 'Bearer ' || v_tok)
           ) into v_req;
    insert into camp_probe (req_id, line_user_id, kind)
    values (v_req, r.line_user_id, 'friend')
    on conflict (req_id) do nothing;

    select net.http_get(
             url := 'https://api.line.me/v2/bot/group/' || v_group
                    || '/member/' || r.line_user_id,
             headers := jsonb_build_object('Authorization', 'Bearer ' || v_tok)
           ) into v_req;
    insert into camp_probe (req_id, line_user_id, kind)
    values (v_req, r.line_user_id, 'group')
    on conflict (req_id) do nothing;

    v_n := v_n + 1;
  end loop;

  return v_n;
end;
$fn$;

-- ตรวจ  ต้องมีฟังก์ชันตัวเดียว ถ้าได้ 2 แปลว่ามีตัวซ้อน งานตามเวลาจะพัง
select
  (select count(*) from pg_proc where proname = 'camp_check_fire')             as ฟังก์ชันต้องเป็น1,
  (select val from bs_settings where key = 'campRetryMinutes')                as ตรวจซ้ำทุกกี่นาที;

-- จบไฟล์  อย่าเคาะบรรทัดใหม่ต่อท้ายบรรทัดนี้ ->
