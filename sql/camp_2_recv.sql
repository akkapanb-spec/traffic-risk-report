-- กิจกรรมแจกหมวกนิรภัย  ส่วนรับคนเข้าร่วมและบันทึกว่าใครชวนใคร
-- รันหลัง camp_1_tables.sql
-- ถ้ามี $0 ต่อท้ายไฟล์ ให้ลบออกก่อนกด Run
--
-- ไฟล์นี้แตะฟังก์ชัน line_reply ซึ่งบอทที่ทำงานอยู่เรียกใช้จริง
-- จึงเขียนให้ของเดิมทำงานเหมือนเดิมทุกอย่าง แม้ยังไม่ได้ deploy Edge Function ใหม่
--   Edge Function ตัวเก่าส่งมาแค่ p_text  -> p_user_id เป็น null -> ข้ามส่วนกิจกรรมทั้งหมด
--   Edge Function ตัวใหม่ส่ง p_user_id มาด้วย -> ส่วนกิจกรรมทำงาน
-- และถ้า campEnabled ยังเป็น false ส่วนกิจกรรมก็ไม่ทำงานอยู่ดี ปิดสองชั้น

-- ==========================================================
-- 1  เปิดคีย์เวิร์ด id เพื่อเอารหัสกลุ่ม
-- ==========================================================
-- ตอนนี้คีย์เวิร์ดในระบบปิดอยู่ทุกตัว บอทจึงเงียบสนิท
-- ต้องเปิด id ชั่วคราวเพื่อพิมพ์ในกลุ่มแล้วให้บอทตอบรหัสที่ขึ้นต้นด้วย C
-- ได้รหัสมาแล้วจะปิดกลับก็ได้ ด้วยคำสั่ง
--   update line_keywords set enabled = false where action = 'id';

update line_keywords set enabled = true where action = 'id';

-- ==========================================================
-- 2  ตัวช่วยของกิจกรรม
-- ==========================================================

-- อ่านค่าตั้งเป็นข้อความ  ไม่มีก็คืนค่าสำรอง
create or replace function camp_cfg(p_key text, p_default text)
returns text
language sql
stable
security definer
set search_path = public
as $fn$
  select coalesce((select val #>> array[]::text[] from bs_settings where key = p_key), p_default)
$fn$;

-- นับเพื่อนที่ผ่านครบทั้งสองเงื่อนไข ของผู้ชวนคนหนึ่ง
-- นับจากผลตรวจล่าสุดที่ camp_3 บันทึกไว้ ไม่ได้ยิงถามไลน์ตรงนี้
create or replace function camp_friend_count(p_user_id text)
returns int
language sql
stable
security definer
set search_path = public
as $fn$
  select count(*)::int
    from camp_members
   where referred_by = p_user_id
     and is_friend is true
     and in_group  is true
$fn$;

-- ลงทะเบียนผู้ใช้ ถ้ายังไม่มีก็ออกรหัสชวนให้
-- ปลอดภัยเมื่อเรียกซ้ำ เรียกกี่ครั้งก็ได้รหัสเดิม
create or replace function camp_touch(p_user_id text, p_display_name text default null)
returns camp_members
language plpgsql
volatile
security definer
set search_path = public
as $fn$
declare
  v_row camp_members;
begin
  if p_user_id is null or btrim(p_user_id) = '' then
    return null;
  end if;

  insert into camp_members (line_user_id, display_name, ref_code)
  values (p_user_id, p_display_name, camp_new_code())
  on conflict (line_user_id) do update
     set display_name = coalesce(excluded.display_name, camp_members.display_name)
  returning * into v_row;

  return v_row;
end;
$fn$;

-- ข้อความสรุปสถานะของผู้เข้าร่วมหนึ่งคน ใช้ตอบทั้งตอนทักมาถามและตอนสมัครใหม่
create or replace function camp_msg_status(p_user_id text)
returns text
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_code   text;
  v_need   int  := camp_cfg('campNeedFriends', '5')::int;
  v_have   int;
  v_share  text := camp_cfg('campShareBase', 'https://line.me/R/oaMessage/%40690vodvg/?');
  v_group  text := camp_cfg('campGroupUrl', '');
  v_prize  text := camp_cfg('campPrizeName', 'ของรางวัล');
  v_lines  text[];
begin
  select ref_code into v_code from camp_members where line_user_id = p_user_id;
  if v_code is null then return null; end if;

  v_have := camp_friend_count(p_user_id);

  v_lines := array[
    '🎁 กิจกรรมแจก' || v_prize,
    '',
    'รหัสของคุณ  ' || v_code,
    '',
    'ส่งลิงก์นี้ให้เพื่อน เพื่อนกดแล้วกดส่งข้อความได้เลย ไม่ต้องพิมพ์อะไร',
    v_share || v_code,
    '',
    'จากนั้นให้เพื่อนเข้ากลุ่มนี้ด้วย',
    v_group,
    '',
    'ต้องครบทั้งสองอย่าง เพิ่มเพื่อนและเข้ากลุ่ม จึงจะนับให้',
    'ตอนนี้นับได้ ' || v_have || ' จาก ' || v_need || ' คน'
  ];

  if v_have >= v_need then
    v_lines := v_lines || '' || ('🎉 ครบแล้ว ติดต่อรับ' || v_prize || ' ได้ที่ สภ.เมืองนครสวรรค์');
  end if;

  return array_to_string(v_lines, chr(10));
end;
$fn$;

-- ==========================================================
-- 3  line_reply ตัวใหม่
-- ==========================================================
-- ต้องลบตัวเก่าทิ้งก่อน ห้ามให้มีสองลายเซ็นอยู่พร้อมกัน
-- เพราะ PostgREST เลือกฟังก์ชันจากชุดอาร์กิวเมนต์ที่ส่งมา
-- ถ้ามีทั้ง line_reply(text) และ line_reply(text,text,text) อยู่ด้วยกัน
-- การเรียกด้วย p_text ตัวเดียวจะกำกวมและบอทจะพังทั้งตัว
--
-- ตัวใหม่ให้ค่าปริยายกับสองอาร์กิวเมนต์ใหม่ Edge Function ตัวเก่าจึงยังเรียกได้เหมือนเดิม

drop function if exists line_reply(text);

create or replace function line_reply(
  p_text        text,
  p_user_id     text default null,
  p_source_type text default null
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $fn$
declare
  v_q text := lower(btrim(coalesce(p_text, '')));
  v_action text; v_lines text[]; r record;
  v_on      boolean;
  v_inviter text;
  v_group   text;
begin
  if v_q = '' then return null; end if;

  -- ---------- ส่วนกิจกรรม ----------
  -- ทำเฉพาะเมื่อรู้ว่าใครพูด และพูดในแชทส่วนตัวกับบัญชีทางการเท่านั้น
  -- ในกลุ่มไม่ทำ เพราะรหัสชวนเป็นเรื่องส่วนตัว และบอทที่พูดในกลุ่มบ่อยจะถูกเตะออก
  if p_user_id is not null and coalesce(p_source_type, 'user') = 'user' then

    v_on := camp_cfg('campEnabled', 'false')::boolean;

    if v_on then
      -- ทุกคนที่ทักมาต้องมีรหัสของตัวเอง จะได้ชวนต่อได้
      perform camp_touch(p_user_id);

      -- หารหัสชวนที่ปนมาในข้อความ
      -- ไม่ใช้ regular expression เพราะรูปแบบนับจำนวนตัวอักษรต้องใช้วงเล็บปีกกา
      -- ซึ่งเขียนลงไฟล์ SQL ไม่ได้ ตัวแก้ไขของ Supabase จะทำให้เสีย
      select m.line_user_id into v_inviter
        from camp_members m
       where m.line_user_id <> p_user_id
         and m.ref_code = any (
               select upper(btrim(t))
                 from unnest(string_to_array(
                        replace(replace(p_text, chr(10), ' '), chr(13), ' '), ' ')) as t
               where btrim(t) <> ''
             )
       limit 1;

      if v_inviter is not null then
        -- ผูกได้ครั้งเดียว ใครผูกไปแล้วจะเปลี่ยนผู้ชวนทีหลังไม่ได้
        update camp_members
           set referred_by = v_inviter
         where line_user_id = p_user_id
           and referred_by is null;

        v_group := camp_cfg('campGroupUrl', '');

        return jsonb_build_object(
          'action', 'camp-join',
          'text', array_to_string(array[
            '✅ บันทึกแล้ว ขอบคุณที่เข้าร่วมกิจกรรม',
            '',
            'เหลืออีกขั้นเดียว กดเข้ากลุ่มนี้',
            v_group,
            '',
            'เมื่อเข้ากลุ่มแล้ว เพื่อนที่ชวนคุณมาจะได้รับเครดิตหนึ่งคน',
            'ถ้าออกจากกลุ่มหรือบล็อกบัญชีนี้ เครดิตจะหายไปเอง',
            '',
            'อยากชวนเพื่อนของคุณเองบ้าง พิมพ์คำว่า  กิจกรรม'
          ], chr(10))
        );
      end if;

      -- ถามสถานะของตัวเอง
      if v_q in ('กิจกรรม', 'รหัส', 'รหัสของฉัน', 'หมวก', 'ของรางวัล') then
        return jsonb_build_object('action', 'camp-status', 'text', camp_msg_status(p_user_id));
      end if;
    end if;
  end if;

  -- ---------- ของเดิม ไม่แก้อะไรเลย ----------
  select action into v_action from line_keywords
   where enabled and (v_q = keyword or v_q like keyword || ' %')
   order by sort_order, length(keyword) desc limit 1;

  if v_action is null then return null; end if;

  if v_action = 'id' then
    return jsonb_build_object('action', 'id', 'text', null);
  end if;

  if v_action = 'ac-d' then
    return jsonb_build_object('action', v_action, 'text', line_msg_acc_day());
  elsif v_action = 'ac-w' then
    return jsonb_build_object('action', v_action, 'text', line_msg_acc_week());

  elsif v_action = 'help' then
    -- ไม่แสดง id ในเมนู แต่ยังตอบเมื่อพิมพ์เข้ามา
    v_lines := array['🤖 คำสั่งที่ใช้ได้', ''];
    for r in
      select string_agg(keyword, ' / ' order by keyword) as ks,
             max(case action when 'ac-d' then 'สรุปอุบัติเหตุวันนี้'
                             when 'ac-w' then 'สรุปอุบัติเหตุรอบสัปดาห์'
                             else action end) as ds
        from line_keywords where enabled and action not in ('help', 'id')
       group by action order by min(sort_order)
    loop
      v_lines := v_lines || (r.ks || '  —  ' || r.ds);
    end loop;
  end if;

  if v_lines is null or array_length(v_lines, 1) is null then return null; end if;
  return jsonb_build_object('action', v_action, 'text', array_to_string(v_lines, chr(10)));
end;
$fn$;

-- สิทธิ์เรียกใช้ ให้เหมือนเดิมกับที่ Edge Function ใช้อยู่
grant execute on function line_reply(text, text, text) to anon, authenticated, service_role;

-- ==========================================================
-- 4  ค่าตั้งเพิ่ม
-- ==========================================================
-- ลิงก์ชวนเพื่อนแบบเปิดแชทพร้อมข้อความเติมไว้ให้แล้ว เพื่อนแค่กดส่ง ไม่ต้องพิมพ์
-- ใช้ตัวอักษรอังกฤษล้วน จึงไม่ต้องเข้ารหัส URL ให้ยุ่งยาก

insert into bs_settings (key, val) values
  ('campShareBase', to_jsonb('https://line.me/R/oaMessage/%40690vodvg/?'::text))
on conflict (key) do nothing;

-- ==========================================================
-- 5  สั่งให้ PostgREST อ่านสคีมาใหม่
-- ==========================================================
-- เปลี่ยนลายเซ็นฟังก์ชันแล้วต้องบอกให้ PostgREST รู้
-- ไม่งั้นมันจะยังจำลายเซ็นเดิมไว้ แล้วบอทจะเรียกไม่เจอและเงียบไปเฉย ๆ
-- ปกติ Supabase สั่งให้เองอยู่แล้ว แต่สั่งซ้ำไม่เสียหาย

notify pgrst, 'reload schema';

-- ==========================================================
-- ตรวจผล  คำสั่งสุดท้ายคำสั่งเดียวที่จะแสดงผล
-- ==========================================================

select 'ลายเซ็นของ line_reply ต้องมีอันเดียว' as รายการ,
       coalesce((select string_agg(p.oid::regprocedure::text, '  |  ')
                 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                 where n.nspname = 'public' and p.proname = 'line_reply'), 'หายไป') as ผล
union all
select 'เรียกแบบเดิมด้วย p_text อย่างเดียว ยังได้ผลเหมือนเดิม',
       coalesce(line_reply('#help')::text, 'คืนค่าว่าง ซึ่งถูกต้องเพราะคีย์เวิร์ด help ยังปิดอยู่')
union all
select 'คีย์เวิร์ด id เปิดแล้วหรือยัง',
       coalesce((select string_agg(keyword || ' = ' || enabled::text, ', ')
                 from line_keywords where action = 'id'), 'ไม่พบ')
union all
select 'ฟังก์ชันกิจกรรมที่สร้างแล้ว',
       coalesce((select string_agg(p.proname, ', ' order by p.proname)
                 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                 where n.nspname = 'public' and p.proname like 'camp%'), 'ไม่มี')
union all
select 'สวิตช์กิจกรรม ตอนนี้',
       camp_cfg('campEnabled', 'ไม่พบ') || '   (ยังไม่เปิด จึงยังไม่มีผลกับบอท)'
union all
select 'สิ่งที่ต้องทำต่อ',
       case when camp_cfg('campGroupId', '') = ''
            then 'พิมพ์  #id  ในกลุ่มไลน์ แล้วเอารหัสที่ขึ้นต้นด้วย C มาใส่ campGroupId'
            else 'มีรหัสกลุ่มแล้ว รอ deploy Edge Function ตัวใหม่' end;
