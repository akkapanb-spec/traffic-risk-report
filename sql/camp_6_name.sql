-- เก็บชื่อไลน์ของผู้เข้าร่วมด้วย
-- รันหลัง camp_3_verify.sql
-- ถ้ามี $0 ต่อท้ายไฟล์ ให้ลบออกก่อนกด Run
--
-- ทำไมต้องแก้
--   ตัวเก็บผลตัวเดิมอ่านแค่รหัสตอบกลับ 200 หรือ 404 แล้วทิ้งเนื้อหาไป
--   แต่คำตอบของจุดตรวจว่ายังเป็นเพื่อนไหม มีชื่อที่ผู้ใช้ตั้งไว้ติดมาด้วย
--   ถ้าไม่เก็บ เจ้าหน้าที่จะเห็นแต่รหัส 6 ตัวตอนแจกของ ไม่รู้ว่าเป็นใคร
--
-- ไม่เก็บรูปโปรไฟล์และข้อความสถานะ เก็บเท่าที่จำเป็นต่อการแจกของเท่านั้น

create or replace function camp_check_collect()
returns int
language plpgsql
volatile
security definer
set search_path = public
as $fn$
declare
  v_n    int := 0;
  v_name text;
  r      record;
begin
  for r in
    select p.req_id, p.line_user_id, p.kind, x.status_code, x.content
      from camp_probe p
      join net._http_response x on x.id = p.req_id
     where p.done = false
  loop
    if r.status_code = 200 then
      if r.kind = 'friend' then
        -- ดึงชื่อออกมาจากคำตอบ ถ้าแปลงไม่ได้ก็ข้ามไป ห้ามให้ทั้งรอบพังเพราะชื่อคนเดียว
        begin
          v_name := nullif(btrim(coalesce((r.content::jsonb) ->> 'displayName', '')), '');
        exception when others then
          v_name := null;
        end;

        update camp_members
           set is_friend    = true,
               display_name = coalesce(v_name, display_name),
               checked_at   = now()
         where line_user_id = r.line_user_id;
      else
        update camp_members set in_group = true, checked_at = now()
         where line_user_id = r.line_user_id;
      end if;
      v_n := v_n + 1;

    elsif r.status_code = 404 then
      -- 404 ของจุดตรวจเพื่อน แปลว่าบล็อกหรือลบบัญชีทางการไปแล้ว
      -- 404 ของจุดตรวจกลุ่ม แปลว่าออกจากกลุ่มไปแล้ว
      if r.kind = 'friend' then
        update camp_members set is_friend = false, checked_at = now()
         where line_user_id = r.line_user_id;
      else
        update camp_members set in_group = false, checked_at = now()
         where line_user_id = r.line_user_id;
      end if;
      v_n := v_n + 1;
    end if;

    -- รหัสอื่นนอกจาก 200 กับ 404 ถือว่ายังไม่รู้ ไม่แตะค่าเดิม
    -- โทเคนหมดอายุหรือไลน์ล่มชั่วคราว ต้องไม่ทำให้ทุกคนหลุดสิทธิ์พร้อมกัน
    update camp_probe set done = true where req_id = r.req_id;
  end loop;

  delete from camp_probe
   where fired_at < now() - interval '2 days';

  return v_n;
end;
$fn$;

-- ==========================================================
-- ตรวจผล  คำสั่งสุดท้ายคำสั่งเดียวที่จะแสดงผล
-- ==========================================================

select 'ตัวเก็บผลอ่านเนื้อหาคำตอบแล้วหรือยัง' as รายการ,
       case when (select position('displayName' in prosrc) > 0
                    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                   where n.nspname = 'public' and p.proname = 'camp_check_collect')
            then 'อ่านแล้ว จะเก็บชื่อให้ตั้งแต่รอบตรวจถัดไป'
            else 'ยังไม่อ่าน' end as ผล
union all
select 'ผู้เข้าร่วมที่ยังไม่มีชื่อ',
       (select count(*)::text from camp_members where display_name is null) || ' คน'
union all
select 'รอบตรวจถัดไป',
       'ยิงคำถามนาทีที่ 0 และ 30  เก็บผลนาทีที่ 5 และ 35'
union all
select 'อยากตรวจเดี๋ยวนี้ไม่ต้องรอ',
       'รัน  select camp_check_fire();  แล้วรออีกสิบวินาที ค่อยรัน  select camp_check_collect();';
