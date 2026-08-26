-- ตารางเก็บระยะทางถนนจริงระหว่างจุดเกิดเหตุ
-- ถ้ามีอักขระแปลกปลอมต่อท้ายบรรทัดสุดท้าย ให้ลบออกก่อนกด Run
-- รันไฟล์นี้ก่อน แล้วค่อย deploy Edge Function ชื่อ roaddist
--
-- ทำไมต้องเก็บไว้
--   ระยะทางถนนระหว่างจุดสองจุดไม่เปลี่ยน ถามครั้งเดียวใช้ได้ตลอด
--   ถ้าถามใหม่ทุกครั้งที่ตรวจจุดเสี่ยง จะเปลืองโควตาโดยไม่ได้อะไรเพิ่ม
--
-- ทำไมต้องกรองด้วยเส้นตรงก่อน
--   ระยะถนนยาวกว่าระยะเส้นตรงเสมอ เป็นความจริงทางเรขาคณิต ไม่มีข้อยกเว้น
--   คู่ที่เส้นตรงห่างเกินเกณฑ์จับกลุ่ม จึงเป็นไปไม่ได้ที่ระยะถนนจะต่ำกว่าเกณฑ์
--   ตัดทิ้งได้เลยโดยไม่ต้องถาม ไม่เสียโควตา และไม่เสียความถูกต้อง
--
--   ระยะกรองจึงผูกกับเกณฑ์จับกลุ่ม ไม่ใช่ตัวเลขตายตัว บวกเผื่อไว้หนึ่งในสี่
--   เผื่อวันหน้าปรับเกณฑ์จาก 120 ขึ้นเป็น 150 จะได้ไม่ต้องถามใหม่ทั้งหมด
--   วัดจากข้อมูลจริงทั้งฐาน  กรองที่ 150 เมตรได้ 9,094 คู่  ถ้ากรองที่ 300 จะเป็น 15,836 คู่
--   เกินความจำเป็นเท่าตัวโดยไม่ได้อะไรกลับมาเลย
--
-- ค่าที่เป็น null ในช่อง metres แปลว่าถามแล้วแต่หาเส้นทางไม่ได้
-- ต่างจากยังไม่ได้ถาม ซึ่งคือไม่มีแถวเลย ต้องแยกสองอย่างนี้ให้ออก
-- ไม่งั้นระบบจะวนถามคู่ที่ตอบไม่ได้ซ้ำไปเรื่อย ๆ ทุกวัน

create table if not exists road_dist (
  a_id       bigint      not null,
  b_id       bigint      not null,
  metres     int,
  straight_m int         not null,
  asked_at   timestamptz not null default now(),
  primary key (a_id, b_id),
  constraint road_dist_order check (a_id < b_id)
);

alter table road_dist enable row level security;
revoke all on road_dist from anon, authenticated;

create index if not exists road_dist_metres_idx on road_dist (metres);

-- ==========================================================
-- รายการคู่ที่ยังไม่เคยถาม
-- ==========================================================
-- คืนพิกัดมาให้พร้อม ตัวเรียกภายนอกจึงไม่ต้องแตะตาราง accidents เอง

create or replace function road_dist_todo(p_days int default 60, p_limit int default 200)
returns table (a_id bigint, b_id bigint, alat float8, alng float8, blat float8, blng float8, straight_m int)
language sql
stable
security definer
set search_path = public
as $fn$
  with acc as (
    select a.id, a.latitude, a.longitude,
           st_transform(st_setsrid(st_makepoint(a.longitude, a.latitude), 4326), 32647) as g
    from accidents a
    where a.latitude is not null and a.longitude is not null
      and a.latitude between 14 and 17 and a.longitude between 99 and 101
      and a.incident_datetime >= now() - make_interval(days => p_days)
  )
  select x.id, y.id, x.latitude, x.longitude, y.latitude, y.longitude,
         round(st_distance(x.g, y.g))::int
  from acc x join acc y on x.id < y.id
  where st_dwithin(x.g, y.g,
         -- กรองเท่าเกณฑ์จับกลุ่ม บวกเผื่อไว้หนึ่งในสี่เผื่อวันหน้าปรับเกณฑ์ขึ้น
         coalesce((select (val #>> array[]::text[])::float8 from bs_settings
                    where key = 'hotspotClusterMetres'), 120) * 1.25)
    and not exists (select 1 from road_dist d where d.a_id = x.id and d.b_id = y.id)
  order by st_distance(x.g, y.g)
  limit p_limit;
$fn$;

-- ==========================================================
-- บันทึกผลที่ถามมาได้
-- ==========================================================
-- รับเป็นรายการเดียว เพื่อให้เขียนครั้งเดียวจบ ไม่ต้องยิงทีละแถว

create or replace function road_dist_save(p_rows jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $fn$
declare v_n int;
begin
  if jsonb_typeof(p_rows) <> 'array' then
    return jsonb_build_object('success', false, 'message', 'ต้องส่งมาเป็นรายการ');
  end if;

  insert into road_dist (a_id, b_id, metres, straight_m)
  select (e->>'a')::bigint, (e->>'b')::bigint,
         nullif(e->>'m', '')::int, coalesce((e->>'s')::int, 0)
  from jsonb_array_elements(p_rows) as e
  on conflict (a_id, b_id) do update
     set metres = excluded.metres, asked_at = now();

  get diagnostics v_n = row_count;
  return jsonb_build_object('success', true, 'saved', v_n);
end;
$fn$;

-- ฟังก์ชันสองตัวนี้เรียกได้เฉพาะจากฝั่งเซิร์ฟเวอร์เท่านั้น
-- ถ้าเปิดให้ anon เรียกได้ ใครก็ได้จะอ่านพิกัดอุบัติเหตุทั้งหมดออกไปทีละสองร้อยคู่
revoke execute on function road_dist_todo(int, int) from anon, authenticated;
revoke execute on function road_dist_save(jsonb) from anon, authenticated;

-- ==========================================================
-- ตรวจผล  คำสั่งสุดท้ายคำสั่งเดียวที่จะแสดงผล
-- ==========================================================

select 'ตารางเก็บระยะถนน' as รายการ,
       (select count(*)::text from road_dist) || ' คู่ที่เคยถามแล้ว' as ผล
union all
select 'คู่ที่รอถาม ย้อนหลัง 60 วัน',
       (select count(*)::text from road_dist_todo(60, 100000)) || ' คู่'
union all
select 'ประมาณการโควตาที่จะใช้',
       (select count(*)::text from road_dist_todo(60, 100000)) || ' ครั้ง จากโควตาเดือนละแสนครั้ง'
union all
select 'ขั้นต่อไป', 'deploy Edge Function ชื่อ roaddist แล้วบอกผม';
