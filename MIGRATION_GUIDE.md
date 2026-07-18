# คู่มือ Migrate ระบบแจ้งจุดเสี่ยงอุบัติเหตุ: GAS → GitHub Pages + Supabase + Cloudinary

> ระบบเดิม: Google Apps Script + Google Sheets + Google Drive
> ระบบใหม่: GitHub Pages (Frontend) + Supabase (Database + API) + Cloudinary (รูปภาพ)

---

## ภาพรวมสถาปัตยกรรม

```
เดิม:  Browser → GAS Web App → Google Sheets (5 ชีท) + Google Drive (รูป)

ใหม่:  Browser (GitHub Pages)
         ├→ Supabase (PostgreSQL + REST API อัตโนมัติ)  ← ข้อมูลทุกตาราง
         └→ Cloudinary (Unsigned Upload)                ← รูปภาพ
```

ข้อมูลที่ต้องย้าย (จาก Sheet ID `1ZRaMIkYdH7yO3Iy1f_RiIZQ3qYtDqrvXMM9ZFO1p60M`):

| ชีทเดิม | ตารางใหม่ใน Supabase |
|---|---|
| ข้อมูลจุดเสี่ยง | `risk_points` |
| ข้อมูลการดำเนินการ | `risk_actions` |
| ข้อมูลผู้เสียชีวิต | `deaths` |
| ข้อมูลอุบัติเหตุ | `accidents` |
| ข้อมูลผู้บาดเจ็บ | `injuries` |

รูปภาพ: Google Drive folder `1Bpjs2WsofYLWMeuM4RTYlEmSk51hP46x` → Cloudinary

---

# PHASE 1: สมัครบริการทั้ง 3 ตัว

## 1.1 สมัคร GitHub

1. เปิด https://github.com/signup
2. กรอก **Email** → ใช้ pex.elsa@gmail.com ได้เลย → กด **Continue**
3. ตั้ง **Password** (8 ตัวขึ้นไป มีตัวเลข+ตัวอักษร) → **Continue**
4. ตั้ง **Username** เช่น `traffic-nakhonsawan` หรือชื่อตัวเอง → **Continue**
5. ตอบคำถาม email preferences (พิมพ์ `n` ถ้าไม่ต้องการรับข่าว) → **Continue**
6. ทำ puzzle ยืนยันตัวตน → กด **Create account**
7. GitHub ส่งรหัส 8 หลักไปที่อีเมล → เปิด Gmail เอารหัสมากรอก
8. เสร็จแล้ว! ล็อกอินเข้า github.com ได้

### สร้าง Repository สำหรับเว็บ
1. มุมขวาบนกดปุ่ม **+** → **New repository**
2. Repository name: `traffic-risk-report`
3. เลือก **Public** (จำเป็นสำหรับ GitHub Pages ฟรี)
4. ติ๊ก **Add a README file**
5. กด **Create repository**

### เปิด GitHub Pages (ทำหลังอัปโหลดโค้ดแล้ว)
1. ในหน้า repo → แท็บ **Settings** → เมนูซ้าย **Pages**
2. Source: **Deploy from a branch**
3. Branch: `main` / Folder: `/ (root)` → **Save**
4. รอ 1-2 นาที เว็บจะขึ้นที่ `https://<username>.github.io/traffic-risk-report/`

---

## 1.2 สมัคร Supabase

1. เปิด https://supabase.com → กด **Start your project** (หรือ Sign Up)
2. เลือก **Continue with GitHub** ← แนะนำ (ใช้บัญชี GitHub ที่เพิ่งสมัคร ไม่ต้องจำรหัสเพิ่ม)
3. GitHub จะถามว่าอนุญาตให้ Supabase เข้าถึงไหม → กด **Authorize supabase**
4. เข้าสู่หน้า Dashboard → กด **New project**
5. กรอก:
   - **Organization**: ใช้ค่า default ที่มันสร้างให้
   - **Project name**: `traffic-risk`
   - **Database Password**: ตั้งรหัสแล้ว **จดเก็บไว้ให้ดี** (ใช้ตอนต่อ DB ตรง)
   - **Region**: เลือก **Southeast Asia (Singapore)** ← ใกล้ไทยที่สุด เร็วสุด
6. กด **Create new project** → รอ ~2 นาที ให้มัน provision
7. เก็บค่าสำคัญ 2 ตัว: ไปที่ **Project Settings (ไอคอนเฟือง) → API**
   - **Project URL** เช่น `https://xxxxx.supabase.co`
   - **anon public key** (ตัวยาวๆ ขึ้นต้น `eyJ...`)
   - สองตัวนี้ใส่ใน frontend ได้เลย ไม่ถือเป็นความลับ (ความปลอดภัยคุมด้วย RLS)
   - ⚠️ ส่วน `service_role` key **ห้าม**เอาใส่หน้าเว็บเด็ดขาด

Free tier: 500MB database, 5GB bandwidth/เดือน — เกินพอสำหรับระบบนี้

---

## 1.3 สมัคร Cloudinary

1. เปิด https://cloudinary.com/users/register_free
2. กรอกชื่อ, Email (pex.elsa@gmail.com), Password → หรือกด **Sign up with Google** ก็ได้ (เร็วกว่า)
3. ถ้าถาม "What best describes you?" เลือก **Developer** / Programmable Media
4. ยืนยันอีเมล (เช็ค Gmail กดลิงก์ยืนยัน)
5. เข้า Dashboard → หน้าแรก (Getting Started / Dashboard) จะเห็น:
   - **Cloud name** เช่น `dxxxxxxx` ← จดไว้
   - API Key / API Secret (ใช้เฉพาะตอน migrate รูปจากฝั่งเครื่องเรา ไม่ใส่หน้าเว็บ)

### สร้าง Unsigned Upload Preset (ให้หน้าเว็บอัปโหลดรูปได้โดยไม่ต้องมี secret)
1. ไปที่ **Settings (ไอคอนเฟือง) → Upload** → หัวข้อ **Upload presets**
2. กด **Add upload preset**
3. ตั้งค่า:
   - **Preset name**: `traffic_risk`
   - **Signing Mode**: เปลี่ยนเป็น **Unsigned** ← สำคัญมาก
   - **Folder**: `traffic-risk` (รูปจะถูกเก็บรวมในโฟลเดอร์นี้)
4. (แนะนำ) แท็บ Transformations → ตั้ง Incoming Transformation จำกัดขนาด เช่น width 1600 limit — กันคนอัปรูปใหญ่เกิน
5. กด **Save**

Free tier: 25 GB storage/bandwidth ต่อเดือน (25 credits) — เพียงพอ

---

# PHASE 2: Export ข้อมูลจาก Google Sheets

1. เปิด Google Sheet เดิม (ID `1ZRaMIkYdH7yO3Iy1f_RiIZQ3qYtDqrvXMM9ZFO1p60M`)
2. คลิกที่ชีท **ข้อมูลจุดเสี่ยง** → เมนู **File → Download → Comma Separated Values (.csv)**
   - ⚠️ Google จะ export **เฉพาะชีทที่เปิดอยู่** — ต้องทำทีละชีท
3. ทำซ้ำกับอีก 4 ชีท: ข้อมูลการดำเนินการ, ข้อมูลผู้เสียชีวิต, ข้อมูลอุบัติเหตุ, ข้อมูลผู้บาดเจ็บ
4. เอาไฟล์ .csv ทั้ง 5 มาวางไว้ในโฟลเดอร์ `C:\@Coding\Project\Traffic\data\` แล้วเปลี่ยนชื่อเป็นอังกฤษ:
   - `risk_points.csv`, `risk_actions.csv`, `deaths.csv`, `accidents.csv`, `injuries.csv`

---

# PHASE 3: สร้างตารางใน Supabase

ไปที่ Supabase Dashboard → เมนูซ้าย **SQL Editor** → **New query** → วาง SQL นี้แล้วกด **Run**:

```sql
-- ตารางจุดเสี่ยง (ตรงกับชีท "ข้อมูลจุดเสี่ยง" 13 คอลัมน์)
create table risk_points (
  id bigint generated always as identity primary key,
  registration_date timestamptz default now(),
  location text not null,
  road text,
  village text,
  subdistrict text,
  district text,
  province text,
  coordinates text,          -- "lat, lng" คงรูปแบบเดิมไว้ก่อน
  additional_details text,
  image1_url text,
  image2_url text,
  status text default 'ยังไม่ได้ดำเนินการ',
  note text
);

-- ตารางการดำเนินการ (ตรงกับชีท "ข้อมูลการดำเนินการ")
create table risk_actions (
  id bigint generated always as identity primary key,
  action_date timestamptz default now(),
  location text,
  road text,
  image1_url text,
  image2_url text,
  detail text
);

-- ตารางผู้เสียชีวิต (ตรงกับชีท "ข้อมูลผู้เสียชีวิต" คอลัมน์ A-P)
create table deaths (
  id bigint generated always as identity primary key,
  incident_datetime timestamptz,
  age int,
  gender text,
  status text,               -- ขับขี่/โดยสาร/เดินเท้า
  vehicle_type text,
  safety_equipment text,
  col_g text,
  col_h text,
  license text,
  road_type text,
  cause text,
  col_l text,
  road_name text,
  subdistrict text,          -- คอลัมน์ N
  coordinates text,          -- คอลัมน์ O
  domicile text              -- คอลัมน์ P
);

-- ตารางอุบัติเหตุ / ผู้บาดเจ็บ (ระบบเดิมใช้แค่นับจำนวน + กรองวันที่คอลัมน์แรก)
create table accidents (
  id bigint generated always as identity primary key,
  incident_datetime timestamptz,
  raw jsonb                  -- เก็บคอลัมน์ที่เหลือทั้งแถวไว้ก่อน ค่อยแตกทีหลัง
);

create table injuries (
  id bigint generated always as identity primary key,
  incident_datetime timestamptz,
  raw jsonb
);

-- เปิด Row Level Security ทุกตาราง
alter table risk_points enable row level security;
alter table risk_actions enable row level security;
alter table deaths enable row level security;
alter table accidents enable row level security;
alter table injuries enable row level security;

-- นโยบาย: ใครก็อ่านได้ (เว็บสาธารณะ)
create policy "public read" on risk_points for select using (true);
create policy "public read" on risk_actions for select using (true);
create policy "public read" on deaths for select using (true);
create policy "public read" on accidents for select using (true);
create policy "public read" on injuries for select using (true);

-- นโยบาย: ประชาชนแจ้งจุดเสี่ยงได้ (insert อย่างเดียว แก้/ลบไม่ได้)
create policy "public insert" on risk_points for insert with check (true);
```

> หมายเหตุ: การแก้สถานะ/เพิ่มข้อมูลการดำเนินการ ควรทำผ่าน Supabase Dashboard หรือทำระบบ login เจ้าหน้าที่ (Supabase Auth) ในเฟสถัดไป — RLS ข้างบนตั้งใจไม่เปิด update/delete ให้คนทั่วไป

## Import CSV เข้าตาราง

วิธีง่ายสุด (ผ่านหน้าเว็บ):
1. Supabase → **Table Editor** → เลือกตาราง เช่น `risk_points`
2. กดปุ่ม **Insert → Import data from CSV**
3. ลากไฟล์ CSV ลงไป → จับคู่คอลัมน์ CSV กับคอลัมน์ตาราง → **Import**

⚠️ จุดที่มักติด: วันที่ในชีทเป็นรูปแบบ `dd/MM/yyyy HH:mm:ss` ซึ่ง Postgres ไม่รับตรงๆ ใน timestamptz
ทางแก้ที่ง่าย: import คอลัมน์วันที่ลงเป็น text ก่อน (สร้างคอลัมน์ชั่วคราว) แล้วแปลงด้วย SQL:
```sql
update deaths set incident_datetime = to_timestamp(raw_date, 'DD/MM/YYYY HH24:MI:SS')
```
หรือให้ Claude เขียนสคริปต์แปลง CSV ให้ก่อน import (แนะนำ — แค่ส่งไฟล์ CSV มา)

---

# PHASE 4: ย้ายรูปจาก Google Drive → Cloudinary

หลักการ: รูปเดิมอยู่ใน Drive folder และ URL ในชีทเป็น `https://lh3.googleusercontent.com/d/<FILE_ID>`

ขั้นตอน:
1. เปิด Drive folder `1Bpjs2WsofYLWMeuM4RTYlEmSk51hP46x` → คลิกขวา → **Download** (Google จะ zip ให้ทั้งโฟลเดอร์)
2. แตก zip ไว้ที่ `C:\@Coding\Project\Traffic\images\`
3. อัปโหลดขึ้น Cloudinary — 2 ทางเลือก:
   - **ทางง่าย**: เข้า Cloudinary → **Media Library** → สร้าง folder `traffic-risk` → ลากรูปทั้งหมดลงไป
   - **ทางอัตโนมัติ**: ใช้สคริปต์ Node.js/Python อัปโหลดด้วย API Key + Secret แล้วสร้างตาราง mapping `ชื่อไฟล์เดิม → URL ใหม่` อัตโนมัติ (ให้ Claude เขียนให้ได้)
4. อัปเดต URL ในตาราง `risk_points` / `risk_actions` ให้ชี้ไป Cloudinary URL ใหม่
   (`https://res.cloudinary.com/<cloud_name>/image/upload/traffic-risk/<ชื่อไฟล์>`)

> ข้อควรระวัง: ชื่อไฟล์ใน Drive กับ FILE_ID ใน URL ไม่ตรงกัน — การ map URL เก่า→ใหม่ ต้องใช้สคริปต์ที่ list ไฟล์จาก Drive API (ได้ทั้ง id และชื่อ) จะแม่นที่สุด ขั้นตอนนี้แนะนำให้ทำด้วยสคริปต์

---

# PHASE 5: แก้ Frontend

สิ่งที่เปลี่ยนใน index.html (โครง UI เดิมใช้ได้หมด เปลี่ยนเฉพาะชั้นข้อมูล):

| เดิม (GAS) | ใหม่ |
|---|---|
| `fetch(GOOGLE_SCRIPT_URL, {action:'submitReport'})` | `supabase.from('risk_points').insert({...})` |
| `action:'getRiskData'` | `supabase.from('risk_points').select('*')` |
| `action:'getActionData'` | `supabase.from('risk_actions').select('*').eq('location',..).eq('road',..)` |
| `action:'getStatistics'` | `select` + นับฝั่ง client หรือใช้ Postgres function |
| `action:'getDeathStatistics'` | ดึง `deaths` แล้วคำนวณกลุ่มฝั่ง client (logic เดิมย้ายจาก GAS มาไว้ใน JS ได้ตรงๆ) |
| อัปโหลดรูปเป็น base64 ไป GAS → Drive | `POST https://api.cloudinary.com/v1_1/<cloud_name>/image/upload` พร้อม `upload_preset=traffic_risk` |

เพิ่มใน `<head>`:
```html
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
```

ตัวอย่าง config + อัปโหลดรูป:
```js
const supabase = window.supabase.createClient(
  'https://xxxxx.supabase.co',   // Project URL
  'eyJ...'                        // anon key
);

async function uploadToCloudinary(file) {
  const fd = new FormData();
  fd.append('file', file);
  fd.append('upload_preset', 'traffic_risk');
  const res = await fetch('https://api.cloudinary.com/v1_1/<cloud_name>/image/upload',
    { method: 'POST', body: fd });
  const data = await res.json();
  return data.secure_url;
}
```

ข้อดีที่ได้ทันที: ไม่ต้องแปลง base64, ไม่ติด limit 6 นาทีของ GAS, โหลดข้อมูลเร็วขึ้นมาก

---

# PHASE 6: Deploy ขึ้น GitHub Pages

1. ติดตั้ง Git for Windows: https://git-scm.com/download/win (ถ้ายังไม่มี)
2. ในโฟลเดอร์โปรเจกต์:
```bash
git init
git add .
git commit -m "Initial commit: traffic risk report system"
git branch -M main
git remote add origin https://github.com/<username>/traffic-risk-report.git
git push -u origin main
```
3. เปิด GitHub Pages ตามขั้นตอนใน Phase 1.1
4. เว็บออนไลน์ที่ `https://<username>.github.io/traffic-risk-report/`

---

# Checklist สรุป

- [ ] สมัคร GitHub + สร้าง repo
- [ ] สมัคร Supabase (ผ่าน GitHub) + สร้าง project region Singapore + จด URL/anon key
- [ ] สมัคร Cloudinary + จด cloud name + สร้าง unsigned preset `traffic_risk`
- [ ] Export CSV ทั้ง 5 ชีท
- [ ] รัน SQL สร้างตาราง + RLS
- [ ] Import CSV (แปลงรูปแบบวันที่ก่อน)
- [ ] Download รูปจาก Drive → อัปโหลด Cloudinary → อัปเดต URL ในตาราง
- [ ] แก้ index.html ใช้ supabase-js + Cloudinary upload
- [ ] Push ขึ้น GitHub + เปิด Pages
- [ ] ทดสอบ: แจ้งจุดเสี่ยงใหม่, ดูตาราง, ดูแผนที่, Dashboard, สถิติผู้เสียชีวิต
