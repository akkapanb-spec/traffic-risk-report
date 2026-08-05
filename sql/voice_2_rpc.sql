-- ============================================================
-- เสียงจากประชาชน - RPC (2 ของ 2)
-- ============================================================
-- ต้องรัน voice_1_tables.sql ก่อน และต้องมี admin_check_ จาก deaths_admin.sql
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
-- ถ้าบรรทัดแรกเป็นข้อความไทยลอย ๆ แปลว่า paste ขาดหัว ให้วางใหม่
--
-- ฝั่งประชาชนเรียกได้โดยไม่ต้อง login แต่ทุกตัวเป็น security definer
-- และเขียนได้อย่างเดียว อ่านกลับไม่ได้ จึงไม่มีทางดึงข้อมูลคนอื่นออกไป
-- ============================================================

-- ============================================================
-- ส่งความคิดเห็น - ประชาชนเรียกได้ ไม่ต้อง login
--   จำกัด 5 ครั้งต่อ session ต่อชั่วโมง กัน bot ถล่มโดยไม่ต้องใช้ CAPTCHA
--   ซึ่งเป็นอุปสรรคกับคนแก่และคนตาไม่ดีมากกว่ากันบอทได้จริง
-- ============================================================
create or replace function vc_feedback_add(p_row jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_key text; v_recent int;
begin
  v_key := coalesce(nullif(p_row->>'session_key',''), 'anon');

  if coalesce(p_row->>'message','') = '' and (p_row->>'rating') is null then
    return jsonb_build_object('success', false, 'message', 'กรุณาให้คะแนนหรือเขียนความคิดเห็นอย่างน้อยหนึ่งอย่าง');
  end if;

  select count(*) into v_recent from vc_feedback
   where session_key = v_key and created_at > now() - interval '1 hour';
  if v_recent >= 5 then
    return jsonb_build_object('success', false, 'message', 'ส่งความคิดเห็นบ่อยเกินไป กรุณารอสักครู่แล้วลองใหม่');
  end if;

  insert into vc_feedback(rating, topic, message, contact, page, session_key)
  values (nullif(p_row->>'rating','')::int, nullif(p_row->>'topic',''),
    left(nullif(p_row->>'message',''), 1000), left(nullif(p_row->>'contact',''), 120),
    nullif(p_row->>'page',''), v_key);

  return jsonb_build_object('success', true, 'message', 'ขอบคุณสำหรับความคิดเห็น เราจะนำไปปรับปรุงระบบ');
end $$;

-- ============================================================
-- บันทึกการใช้งานแบบรวมส่งทีเดียว
--   ตัดที่ 50 เหตุการณ์ต่อครั้ง กันกรณีสคริปต์ฝั่งเว็บพลาดแล้วยิงรัว
-- ============================================================
create or replace function vc_events_add(p_session text, p_device text, p_events jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare e jsonb; v_n int := 0;
begin
  if coalesce(p_session,'') = '' then
    return jsonb_build_object('success', false, 'message', 'ไม่มีรหัสการเข้าชม');
  end if;

  for e in select value from jsonb_array_elements(coalesce(p_events, '[]'::jsonb))
  loop
    exit when v_n >= 50;
    if coalesce(e->>'event','') = '' then continue; end if;
    insert into vc_events(session_key, event, page, section, device, meta)
    values (p_session, e->>'event', nullif(e->>'page',''), nullif(e->>'section',''),
      nullif(p_device,''), e->'meta');
    v_n := v_n + 1;
  end loop;

  return jsonb_build_object('success', true, 'saved', v_n);
end $$;

-- ============================================================
-- กดความรู้สึกในคลิป - กดซ้ำอันเดิมคือยกเลิก กดอันใหม่คือเปลี่ยนใจ
-- ============================================================
create or replace function vc_react(p_target_type text, p_target_id text, p_kind text, p_session text)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_type text; v_cur text; v_action text;
begin
  if coalesce(p_target_id,'') = '' or coalesce(p_session,'') = '' then
    return jsonb_build_object('success', false, 'message', 'ข้อมูลไม่ครบ');
  end if;
  if p_kind not in ('heart','sad','idea','share') then
    return jsonb_build_object('success', false, 'message', 'ชนิดความรู้สึกไม่ถูกต้อง');
  end if;
  v_type := coalesce(nullif(p_target_type,''), 'video');

  select kind into v_cur from vc_reactions
   where target_type = v_type and target_id = p_target_id and session_key = p_session;

  if v_cur = p_kind then
    delete from vc_reactions
     where target_type = v_type and target_id = p_target_id and session_key = p_session;
    v_action := 'removed';
  else
    insert into vc_reactions(target_type, target_id, kind, session_key)
    values (v_type, p_target_id, p_kind, p_session)
    on conflict (target_type, target_id, session_key) do update set kind = excluded.kind;
    v_action := case when v_cur is null then 'added' else 'changed' end;
  end if;

  return jsonb_build_object('success', true, 'action', v_action,
    'totals', coalesce((select jsonb_object_agg(kind, n) from vc_reaction_totals
      where target_type = v_type and target_id = p_target_id), '{}'::jsonb));
end $$;

-- ============================================================
-- ฝั่งเจ้าหน้าที่ - อ่านความคิดเห็นและสรุปการใช้งาน
-- ============================================================
create or replace function vc_admin_data(p_token text, p_days int) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb; v_from timestamptz;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  v_from := now() - make_interval(days => coalesce(p_days, 30));

  return jsonb_build_object('success', true,
    'feedback', coalesce((select jsonb_agg(to_jsonb(f) order by f.created_at desc)
      from (select id, rating, topic, message, contact, page, status, admin_note, handled_by, created_at
              from vc_feedback order by created_at desc limit 300) f), '[]'::jsonb),
    'avgRating', (select round(avg(rating)::numeric, 2) from vc_feedback where rating is not null),
    'pending', (select count(*) from vc_feedback where status = 'ใหม่'),
    -- ผู้เข้าชมนับจากจำนวน session ที่ไม่ซ้ำ ไม่ใช่จำนวนเหตุการณ์
    'visitors', (select count(distinct session_key) from vc_events where created_at >= v_from),
    'byDevice', coalesce((select jsonb_object_agg(coalesce(device,'ไม่ระบุ'), n) from (
        select device, count(distinct session_key) n from vc_events
         where created_at >= v_from group by device) t), '{}'::jsonb),
    -- หัวข้อที่คนเลื่อนไปถึง เรียงจากมากไปน้อย ตัวท้ายตารางคือหัวข้อที่แทบไม่มีคนดู
    'bySection', coalesce((select jsonb_agg(to_jsonb(t) order by t.sessions desc) from (
        select coalesce(page,'-') as page, coalesce(section,'-') as section,
               count(distinct session_key)::int as sessions, count(*)::int as hits
          from vc_events where created_at >= v_from and event in ('reach','click')
         group by page, section) t), '[]'::jsonb),
    'byHour', coalesce((select jsonb_object_agg(h, n) from (
        select extract(hour from (created_at at time zone 'Asia/Bangkok'))::int h,
               count(distinct session_key) n
          from vc_events where created_at >= v_from group by 1) t), '{}'::jsonb),
    'reactions', coalesce((select jsonb_agg(to_jsonb(r) order by r.n desc)
      from vc_reaction_totals r), '[]'::jsonb));
end $$;

create or replace function vc_feedback_update(p_token text, p_id bigint, p_status text, p_note text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb; v_user jsonb;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  v_user := officer_session_user(p_token);

  update vc_feedback set
    status = coalesce(nullif(p_status,''), status),
    admin_note = coalesce(nullif(p_note,''), admin_note),
    handled_by = (v_user->>'rank') || ' ' || (v_user->>'firstName') || ' ' || (v_user->>'lastName'),
    updated_at = now()
   where id = p_id;

  return jsonb_build_object('success', true, 'message', 'อัปเดตสถานะแล้ว');
end $$;

-- ============================================================
-- ยุบข้อมูลดิบเก่าเป็นยอดรายวัน แล้วลบทิ้ง
--   เรียกเองเป็นครั้งคราว หรือผูกกับ pg_cron ภายหลังก็ได้
-- ============================================================
create or replace function vc_compact(p_token text, p_keep_days int) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_err jsonb; v_cut date; v_moved int;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;
  v_cut := (now() at time zone 'Asia/Bangkok')::date - coalesce(p_keep_days, 90);

  insert into vc_daily(day, page, section, device, n, sessions)
  select (created_at at time zone 'Asia/Bangkok')::date, coalesce(page,'-'), coalesce(section,'-'),
         coalesce(device,'-'), count(*), count(distinct session_key)
    from vc_events
   where (created_at at time zone 'Asia/Bangkok')::date < v_cut
   group by 1,2,3,4
  on conflict (day, page, section, device) do update
    set n = excluded.n, sessions = excluded.sessions;

  delete from vc_events where (created_at at time zone 'Asia/Bangkok')::date < v_cut;
  get diagnostics v_moved = row_count;

  return jsonb_build_object('success', true, 'removed', v_moved,
    'message', 'ยุบข้อมูลดิบก่อน ' || v_cut || ' เป็นยอดรายวันแล้ว ลบไป ' || v_moved || ' แถว');
end $$;

-- ============================================================
-- สิทธิ์เรียกใช้
--   สามตัวแรกประชาชนเรียกได้โดยไม่ต้อง login (เขียนอย่างเดียว)
--   ที่เหลือเป็นของเจ้าหน้าที่ ตรวจ token ข้างในอยู่แล้ว
-- ============================================================
grant execute on function vc_feedback_add(jsonb) to anon, authenticated;
grant execute on function vc_events_add(text, text, jsonb) to anon, authenticated;
grant execute on function vc_react(text, text, text, text) to anon, authenticated;

revoke execute on function vc_feedback_update(text, bigint, text, text) from public;
revoke execute on function vc_compact(text, int) from public;
grant execute on function vc_admin_data(text, int) to anon, authenticated;
grant execute on function vc_feedback_update(text, bigint, text, text) to anon, authenticated;
grant execute on function vc_compact(text, int) to anon, authenticated;
