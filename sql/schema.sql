-- ============================================================
-- Traffic Risk Report System — Supabase Schema
-- รันใน Supabase Dashboard → SQL Editor → New query → Run
-- ============================================================

-- ตารางจุดเสี่ยง (ชีทเดิม: ข้อมูลจุดเสี่ยง)
create table if not exists risk_points (
  id bigint generated always as identity primary key,
  registration_date timestamptz default now(),
  location text not null,
  road text,
  village text,
  subdistrict text,
  district text,
  province text,
  coordinates text,
  additional_details text,
  image1_url text,
  image2_url text,
  status text default 'ยังไม่ได้ดำเนินการ',
  note text
);

-- ตารางการดำเนินการ (ชีทเดิม: ข้อมูลการดำเนินการ)
create table if not exists risk_actions (
  id bigint generated always as identity primary key,
  action_date timestamptz default now(),
  location text,
  road text,
  image1_url text,
  image2_url text,
  detail text
);

-- ตารางผู้เสียชีวิต (ชีทเดิม: ข้อมูลผู้เสียชีวิต คอลัมน์ A-P)
create table if not exists deaths (
  id bigint generated always as identity primary key,
  incident_datetime timestamptz,
  age int,
  gender text,
  status text,
  vehicle_type text,
  safety_equipment text,
  col_g text,
  col_h text,
  license text,
  road_type text,
  cause text,
  col_l text,
  road_name text,
  subdistrict text,
  coordinates text,
  domicile text
);

-- ตารางอุบัติเหตุ (ชีทเดิม: ข้อมูลอุบัติเหตุ — ระบบเดิมใช้นับจำนวนอย่างเดียว)
create table if not exists accidents (
  id bigint generated always as identity primary key,
  incident_datetime timestamptz,
  raw jsonb
);

-- ตารางผู้บาดเจ็บ (ชีทเดิม: ข้อมูลผู้บาดเจ็บ)
create table if not exists injuries (
  id bigint generated always as identity primary key,
  incident_datetime timestamptz,
  raw jsonb
);

-- ============================================================
-- Row Level Security
-- ============================================================
alter table risk_points enable row level security;
alter table risk_actions enable row level security;
alter table deaths enable row level security;
alter table accidents enable row level security;
alter table injuries enable row level security;

-- ทุกคนอ่านได้ (เว็บสาธารณะ)
create policy "public read" on risk_points for select using (true);
create policy "public read" on risk_actions for select using (true);
create policy "public read" on deaths for select using (true);
create policy "public read" on accidents for select using (true);
create policy "public read" on injuries for select using (true);

-- ประชาชนแจ้งจุดเสี่ยงได้ (insert เท่านั้น — แก้/ลบต้องทำผ่าน Dashboard)
create policy "public insert" on risk_points for insert with check (true);
