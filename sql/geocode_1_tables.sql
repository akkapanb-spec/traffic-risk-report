-- ============================================================
-- รหัสการปกครอง จังหวัด/อำเภอ/ตำบล (ส่วนที่ 1 ของ 2)
-- ============================================================
-- ต้องรัน roadnet_1_tables.sql ก่อน เพราะไฟล์นั้นเป็นตัวเปิด extension postgis
-- รันไฟล์นี้ก่อน แล้วค่อยรัน geocode_2_nakhonsawan.sql
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
--
-- ปัญหาที่ไฟล์นี้แก้
--   ตอนนี้ชื่อตำบลเก็บเป็นข้อความอิสระทุกที่ ทั้งในตาราง accidents deaths
--   pop_rows และตัวเลือกในฟอร์ม เวลาจะเทียบข้อมูลข้ามแหล่ง เช่น เทียบกับ
--   ThaiRSC หรือทะเบียนราษฎร ต้องจับคู่ด้วยชื่อ ซึ่งเขียนไม่ตรงกันเมื่อไหร่ก็หลุด
--
--   ตัวอย่างที่เกิดขึ้นจริงในฐานข้อมูลนี้
--   ระบบเราเขียน "วัดไทรย์" ทะเบียนกลางเขียน "วัดไทร" (รหัส 600113)
--   ในตาราง deaths มี 9 จาก 91 แถวที่ใช้ชื่อนี้ ถ้าจับคู่ด้วยชื่อจะหายไปทั้ง 9
--
--   วิธีแก้ไม่ใช่ไปไล่แก้ชื่อในระบบให้เป็น "วัดไทร" เพราะคนในพื้นที่เขียน
--   "วัดไทรย์" กันจริง และไฟล์ขอบเขตตำบลที่ใช้วาดแผนที่ก็ใช้ชื่อนี้
--   จึงเก็บทั้งสองชื่อไว้ แล้วผูกเข้ารหัสเดียวกันผ่านตารางชื่อพ้อง
-- ============================================================

set search_path = public, extensions;

-- ============================================================
-- 1) ตารางรหัสการปกครอง
-- ============================================================
create table if not exists geo_codes (
  sub_code     int primary key,        -- รหัสตำบล 6 หลัก เช่น 600113
  sub_name     text not null,
  sub_name_en  text,
  dist_code    int  not null,          -- รหัสอำเภอ 4 หลัก
  dist_name    text not null,
  dist_name_en text,
  prov_code    int  not null,          -- รหัสจังหวัด 2 หลัก
  prov_name    text not null,
  prov_name_en text,
  -- ขอบเขตตำบล ว่างไว้ก่อน ไฟล์รหัสไม่มีพิกัดมาด้วย
  -- เติมภายหลังได้ แล้ว geo_locate จะหาตำบลจากพิกัดให้ทันที
  geom         geometry(MultiPolygon, 4326)
);

create index if not exists geo_codes_sub_name_idx  on geo_codes (sub_name);
create index if not exists geo_codes_dist_idx      on geo_codes (dist_code);
create index if not exists geo_codes_prov_idx      on geo_codes (prov_code);
create index if not exists geo_codes_geom_idx      on geo_codes using gist (geom);

alter table geo_codes enable row level security;
drop policy if exists "public read" on geo_codes;
create policy "public read" on geo_codes for select using (true);

-- ============================================================
-- 2) ชื่อพ้อง - ชื่อที่ใช้จริงในพื้นที่ ผูกกลับเข้ารหัสทางการ
-- ============================================================
create table if not exists geo_aliases (
  alias    text primary key,
  sub_code int  not null references geo_codes(sub_code) on delete cascade,
  note     text
);

alter table geo_aliases enable row level security;
drop policy if exists "public read" on geo_aliases;
create policy "public read" on geo_aliases for select using (true);

-- ============================================================
-- 3) ตัวช่วยล้างชื่อก่อนเทียบ
-- ============================================================
-- ตัดคำนำหน้าและช่องว่างออก "ต.หนองกรด" "ตำบลหนองกรด" " หนองกรด " ต้องได้ค่าเดียวกัน
create or replace function geo_norm(p_name text)
returns text language sql immutable as $$
  select nullif(btrim(regexp_replace(coalesce(p_name,''), '^\s*(ตำบล|ต\.|แขวง|อำเภอ|อ\.|เขต|จังหวัด|จ\.)\s*', '')), '');
$$;

-- ============================================================
-- 4) หารหัสตำบลจากชื่อ
-- ============================================================
-- ไล่จากแคบไปกว้าง ชื่อตำบลซ้ำกันได้ทั้งประเทศ ถ้าไม่บอกอำเภอ/จังหวัดมาด้วย
-- แล้วเจอมากกว่าหนึ่งที่ จะคืน null ดีกว่าเดาผิด
create or replace function geo_resolve_sub(
  p_sub text, p_dist text default null, p_prov text default null
) returns int
language plpgsql stable set search_path = public, extensions as $$
declare
  v_sub  text := geo_norm(p_sub);
  v_dist text := geo_norm(p_dist);
  v_prov text := geo_norm(p_prov);
  v_code int;
  v_n    int;
begin
  if v_sub is null then return null; end if;

  -- ชื่อพ้องก่อน เพราะเป็นชื่อที่ตั้งใจผูกไว้แล้ว
  select sub_code into v_code from geo_aliases where alias = v_sub;
  if v_code is not null then return v_code; end if;

  select count(*), min(sub_code) into v_n, v_code
  from geo_codes
  where sub_name = v_sub
    and (v_dist is null or dist_name = v_dist)
    and (v_prov is null or prov_name = v_prov);

  if v_n = 1 then return v_code; end if;
  return null;   -- ไม่เจอ หรือเจอหลายที่จนชี้ชัดไม่ได้
end $$;

grant execute on function geo_norm(text) to anon, authenticated;
grant execute on function geo_resolve_sub(text, text, text) to anon, authenticated;

-- ============================================================
-- 5) หาตำบลจากพิกัด - ใช้ได้เมื่อเติม geom แล้วเท่านั้น
-- ============================================================
-- ตอนนี้ฝั่งเว็บหาตำบลจากพิกัดด้วยการวน point-in-polygon ใน JavaScript
-- ถ้าเติมขอบเขตลง geom ฟังก์ชันนี้จะทำแทนได้ โดยมี GIST index ช่วยคัดก่อน
create or replace function geo_locate(p_lat float8, p_lng float8)
returns jsonb
language sql stable set search_path = public, extensions as $$
  select coalesce((
    select jsonb_build_object('sub_code', g.sub_code, 'sub_name', g.sub_name,
                              'dist_name', g.dist_name, 'prov_name', g.prov_name)
    from geo_codes g
    where g.geom is not null
      and st_contains(g.geom, st_setsrid(st_makepoint(p_lng, p_lat), 4326))
    limit 1
  ), jsonb_build_object('sub_code', null));
$$;

grant execute on function geo_locate(float8, float8) to anon, authenticated;

-- ============================================================
-- 6) นำเข้ารหัสเป็นชุด - สำหรับหน้าเจ้าหน้าที่
-- ============================================================
-- geocode_2_nakhonsawan.sql ใส่เฉพาะนครสวรรค์ไว้ให้แล้ว (130 ตำบล)
-- ถ้าต้องการทั้งประเทศ 7,436 ตำบล ให้นำเข้าผ่านฟังก์ชันนี้แทนการวาง SQL
-- เพราะไฟล์ SQL ทั้งประเทศราว 650 KB วางในหน้าเว็บแล้วช้าและเสี่ยงขาดกลางทาง
create or replace function geo_codes_import(p_token text, p_rows jsonb)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare v_err jsonb; v_n int;
begin
  v_err := admin_check_(p_token);
  if v_err is not null then return v_err; end if;

  insert into geo_codes (sub_code, sub_name, sub_name_en, dist_code, dist_name, dist_name_en,
                         prov_code, prov_name, prov_name_en)
  select (r->>'sub_code')::int, r->>'sub_name', r->>'sub_name_en',
         (r->>'dist_code')::int, r->>'dist_name', r->>'dist_name_en',
         (r->>'prov_code')::int, r->>'prov_name', r->>'prov_name_en'
  from jsonb_array_elements(coalesce(p_rows, '[]'::jsonb)) r
  where r->>'sub_code' is not null
  on conflict (sub_code) do update set
    sub_name = excluded.sub_name, sub_name_en = excluded.sub_name_en,
    dist_code = excluded.dist_code, dist_name = excluded.dist_name,
    dist_name_en = excluded.dist_name_en,
    prov_code = excluded.prov_code, prov_name = excluded.prov_name,
    prov_name_en = excluded.prov_name_en;

  get diagnostics v_n = row_count;
  return jsonb_build_object('success', true, 'message', 'นำเข้า ' || v_n || ' ตำบล', 'count', v_n);
end $$;

grant execute on function geo_codes_import(text, jsonb) to anon, authenticated;
