// ============================================================
// อ่านเรดาร์ฝนรอบแยกเดชาติวงศ์
// ============================================================
// ฐานข้อมูลอ่านค่าสีจากภาพ PNG เองไม่ได้ จึงต้องมีตัวกลางตัวนี้
// หน้าที่เดียว คือตอบว่า "ตอนนี้มีฝนในรัศมีรอบแยกเดชาติวงศ์หรือไม่" เป็นตัวเลข
// การตัดสินใจว่าจะส่งข้อความหรือไม่ อยู่ฝั่งฐานข้อมูล ไม่ใช่ที่นี่
//
// deploy: Supabase Dashboard -> Edge Functions -> rain -> Code -> Deploy updates
//         และต้องปิด "Verify JWT with legacy secret" ในแท็บ Settings ทุกครั้งหลัง deploy
// ไม่ต้องตั้ง secret ใด ๆ ทั้งสองแหล่งเปิดให้ใช้โดยไม่ต้องมีกุญแจ
//
// ------------------------------------------------------------
// สองแหล่ง ใช้ตาคลีเป็นหลัก RainViewer เป็นตัวสำรอง
// ------------------------------------------------------------
// เรดาร์ตาคลีดีกว่าในทุกด้านที่สำคัญ วัดเทียบเมื่อ 25 ส.ค. 2569
//   ความละเอียด 600 เมตรต่อพิกเซล เทียบกับ 1,177 เมตรของ RainViewer
//   ในวง 8 กม. จึงได้ 553 พิกเซล เทียบกับ 145
//   มีแถบมาตราส่วน dBZ อยู่ในภาพ จึงรู้ความแรงเป็นตัวเลขจริง ไม่ต้องเดาจากสี
//   เป็นของราชการไทย ไม่ใช่บริการต่างประเทศที่เคยประกาศจะปิด
//
// แต่ยังเก็บ RainViewer ไว้ เพราะแหล่งเดียวล่มแล้วระบบเงียบคือความเสี่ยงที่แท้จริง
// ไม่ใช่เรื่องความละเอียดของภาพ
// ============================================================

import { withSupabase } from 'npm:@supabase/server@^1';
import { decode } from 'npm:fast-png@6.2.0';

const LAT = 15.693907;                // แยกเดชาติวงศ์ จากพิกัดที่เจ้าหน้าที่บันทึกไว้เอง
const LNG = 100.122704;
const KM  = 8;                        // รัศมีที่เฝ้า ให้เวลาล่วงหน้าราว 15 นาที

/* แนะนำตัวตามจริง ไม่ปลอมเป็นเบราว์เซอร์
   ทดสอบแล้วว่าเซิร์ฟเวอร์ของกรมฯ ยอมรับ และถ้าวันหนึ่งเขาอยากติดต่อกลับ
   เขาจะรู้ว่าใครดึงภาพไปใช้ทำอะไร */
const UA = 'TrafficRiskNakhonSawan/1.0 (+https://traffic-risk-muangnakhonsawan.netlify.app; traffic safety alerts)';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Content-Type': 'application/json; charset=utf-8'
};

// ------------------------------------------------------------
// เรดาร์ตาคลี  กรมฝนหลวงและการบินเกษตร
// ------------------------------------------------------------
// ค่าคงที่ทั้งหมดวัดมาจากภาพจริง ไม่ได้เชื่อคำบรรยายในภาพอย่างเดียว
// วิธีวัด คือฟิตวงกลมเข้ากับวงระยะสีขาวในภาพ ได้วงที่ 83 167 250 333 พิกเซล
// ตรงกับ 50 100 150 200 กิโลเมตร จึงยืนยันได้ว่า 0.600 กม. ต่อพิกเซล
// และจุดศูนย์กลางอยู่ที่ 399, 399
const TKL_URL   = 'https://weather.tmd.go.th/tkl/tkl240_latest.png';
const TKL_CX    = 399;
const TKL_CY    = 399;
const TKL_KMPX  = 0.6;
const TKL_LAT   = 15.250974;          // ที่ตั้งเรดาร์ ระบุไว้มุมล่างของภาพ
const TKL_LNG   = 100.33700;

/* แถบมาตราส่วนในภาพ อ่านค่าสีมาแล้วทีละช่อง
   ไล่จากอ่อนไปแรง หน่วยเป็น dBZ ซึ่งเป็นความเข้มของสัญญาณสะท้อน */
const TKL_SCALE: Array<[number, number, number, number]> = [
  [0, 102, 79, 8], [0, 176, 71, 12], [0, 204, 51, 16], [51, 255, 0, 20],
  [232, 247, 59, 24], [255, 255, 0, 28], [255, 214, 0, 32], [255, 176, 0, 36],
  [255, 125, 0, 40], [255, 51, 0, 44], [255, 0, 0, 48], [255, 179, 255, 52],
  [255, 51, 255, 56], [255, 0, 255, 60], [0, 102, 255, 64], [0, 51, 255, 68],
  [0, 0, 255, 72]
];

/* ต้องใกล้สีในมาตราส่วนจริง ๆ ถึงจะนับ
   ในวง 8 กม. มีทั้งพื้นหลังภูมิประเทศ เส้นเขตจังหวัด วงระยะสีขาว จุดและชื่อเมือง
   ทดสอบแล้วตัดออกได้ถูกต้อง 537 จาก 553 พิกเซล ในวันที่ไม่มีฝน */
const TKL_TOL = 900;                  // ระยะห่างสีกำลังสอง เท่ากับห่างได้ราว 30 หน่วยต่อช่อง

/* 8 ถึง 16 dBZ คือละอองบางหรือสัญญาณรบกวน ไม่ใช่ฝนที่ต้องเตือน
   20 ขึ้นไปจึงเริ่มเป็นฝนจริง  36 ขึ้นไปถือว่าหนัก */
const TKL_MIN_DBZ   = 20;
const TKL_HEAVY_DBZ = 36;

function dbzAt(r: number, g: number, b: number): number | null {
  let best = Infinity, val: number | null = null;
  for (const [pr, pg, pb, v] of TKL_SCALE) {
    const d = (r - pr) ** 2 + (g - pg) ** 2 + (b - pb) ** 2;
    if (d < best) { best = d; val = v; }
  }
  return best <= TKL_TOL ? val : null;
}

async function sha16(buf: Uint8Array): Promise<string> {
  const h = await crypto.subtle.digest('SHA-256', buf);
  return Array.from(new Uint8Array(h)).slice(0, 8)
    .map(b => b.toString(16).padStart(2, '0')).join('');
}

async function readTakhli(km: number) {
  const res = await fetch(TKL_URL, { headers: { 'User-Agent': UA }, cache: 'no-store' });
  if (!res.ok) throw new Error('ตาคลีตอบ ' + res.status);
  const buf = new Uint8Array(await res.arrayBuffer());
  const img = decode(buf);
  const ch  = img.channels;
  const dat = img.data as Uint8Array;

  /* กันภาพผิดขนาด ถ้ากรมฯ เปลี่ยนรูปแบบภาพ ค่าคงที่ทั้งหมดข้างบนจะใช้ไม่ได้
     ต้องหยุดแล้วบอกว่าอ่านไม่ได้ ห้ามคำนวณต่อด้วยพิกัดที่ไม่ตรงกับภาพ */
  if (img.width !== 1020 || img.height !== 800) {
    throw new Error('ภาพตาคลีเปลี่ยนขนาดเป็น ' + img.width + 'x' + img.height + ' ต้องวัดมาตราส่วนใหม่');
  }

  const north = (LAT - TKL_LAT) * 111.32;
  const east  = (LNG - TKL_LNG) * 111.32 * Math.cos((LAT + TKL_LAT) / 2 * Math.PI / 180);
  const cx = TKL_CX + east / TKL_KMPX;
  const cy = TKL_CY - north / TKL_KMPX;
  const rad = km / TKL_KMPX;

  let checked = 0, rain = 0, heavy = 0, maxDbz = 0, atPoint = false;
  for (let dy = -Math.ceil(rad); dy <= Math.ceil(rad); dy++) {
    for (let dx = -Math.ceil(rad); dx <= Math.ceil(rad); dx++) {
      if (dx * dx + dy * dy > rad * rad) continue;
      const x = Math.round(cx + dx), y = Math.round(cy + dy);
      if (x < 0 || y < 0 || x >= img.width || y >= img.height) continue;
      const o = (y * img.width + x) * ch;
      const v = dbzAt(dat[o], dat[o + 1], dat[o + 2]);
      checked++;
      if (v === null || v < TKL_MIN_DBZ) continue;
      rain++;
      if (v > maxDbz) maxDbz = v;
      if (v >= TKL_HEAVY_DBZ) heavy++;
      if (dx === 0 && dy === 0) atPoint = true;
    }
  }

  return {
    source: 'takhli',
    sourceThai: 'เรดาร์ตาคลี กรมฝนหลวงและการบินเกษตร',
    metrePerPixel: Math.round(TKL_KMPX * 1000),
    pixelsChecked: checked,
    rainPixels: rain,
    heavyPixels: heavy,
    maxDbz,
    rainPercent: checked ? Math.round(rain * 1000 / checked) / 10 : 0,
    atPoint,
    /* ชื่อไฟล์เป็น latest เฉย ๆ ไม่มีเวลากำกับ และเซิร์ฟเวอร์ไม่ส่ง Last-Modified มา
       จึงบอกอายุภาพจากตัวมันเองไม่ได้ ต้องให้ฝั่งฐานข้อมูลเทียบลายนิ้วมือนี้กับรอบก่อน
       ถ้าเหมือนเดิมติดกันหลายรอบ แปลว่าระบบเขาค้าง ไม่ใช่ว่าฟ้าใส */
    imageHash: await sha16(buf),
    imageBytes: buf.length
  };
}

// ------------------------------------------------------------
// RainViewer  ตัวสำรอง
// ------------------------------------------------------------
// ข้อจำกัดที่วัดมาแล้วเมื่อ 25 ส.ค. 2569 และเป็นเหตุผลของตัวเลขในส่วนนี้
//   1 แบบฟรีมีภาพเรดาร์จริงถึงระดับซูม 7 เท่านั้น
//     ซูม 8 ขึ้นไปคืนภาพสำรองสีเทาเหมือนกันทุกใบ ทุกพิกัด ทุกชุดสี
//     ถ้าเผลอไปอ่านที่ซูม 8 จะได้ผลว่าฝนตกตลอดเวลาทั้งที่ฟ้าใส
//   2 ที่ซูม 7 หนึ่งพิกเซลกว้างราว 1,177 เมตร รัศมี 8 กม. จึงเป็นวงราว 7 พิกเซล
//   3 พารามิเตอร์ชุดสีถูกละเลย ขอชุดไหนก็ได้ภาพเดียวกัน จึงต้องอ่านสีชุดมาตรฐาน
//   4 ในภาพมีสีเทาอมเขียวจำนวนมากซึ่งไม่ใช่ฝน เป็นสัญญาณรบกวนจากภูมิประเทศ
//     และสีน้ำตาลอ่อนที่เป็นขอบนอกซึ่งแผ่กว้างกว่าฝนจริงมาก ทั้งสองอย่างไม่นับ

const RV_ZOOM = 7;

function worldPx(lat: number, lng: number, z: number) {
  const n = 256 * Math.pow(2, z);
  const x = (lng + 180) / 360 * n;
  const s = Math.sin(lat * Math.PI / 180);
  const y = (0.5 - Math.log((1 + s) / (1 - s)) / (4 * Math.PI)) * n;
  return { x, y };
}

function rvClass(r: number, g: number, b: number, a: number): 'none' | 'wet' | 'heavy' {
  if (a === 0) return 'none';
  if (r > 180 && b < 100) return 'heavy';   // เหลือง ส้ม แดง
  if (b - r > 40) return 'wet';             // ฟ้า น้ำเงิน
  return 'none';                            // เทาอมเขียว และน้ำตาลอ่อน
}

async function readRainViewer(km: number) {
  const meta = await (await fetch('https://api.rainviewer.com/public/weather-maps.json',
    { cache: 'no-store' })).json();
  const past = meta?.radar?.past ?? [];
  if (!past.length) throw new Error('RainViewer ไม่มีเฟรมให้');
  const frame = past[past.length - 1];

  const c   = worldPx(LAT, LNG, RV_ZOOM);
  const mpp = 156543.03392 * Math.cos(LAT * Math.PI / 180) / Math.pow(2, RV_ZOOM);
  const rad = km * 1000 / mpp;

  const tiles = new Map<string, { data: Uint8Array; ch: number }>();
  async function tile(tx: number, ty: number) {
    const key = tx + '/' + ty;
    const hit = tiles.get(key);
    if (hit) return hit;
    const u = meta.host + frame.path + '/256/' + RV_ZOOM + '/' + tx + '/' + ty + '/2/1_1.png';
    const img = decode(new Uint8Array(await (await fetch(u)).arrayBuffer()));
    const val = { data: img.data as Uint8Array, ch: img.channels };
    tiles.set(key, val);
    return val;
  }

  let checked = 0, wet = 0, heavy = 0, atPoint = false;
  for (let dy = -Math.ceil(rad); dy <= Math.ceil(rad); dy++) {
    for (let dx = -Math.ceil(rad); dx <= Math.ceil(rad); dx++) {
      if (dx * dx + dy * dy > rad * rad) continue;
      const px = Math.floor(c.x + dx), py = Math.floor(c.y + dy);
      const tx = Math.floor(px / 256), ty = Math.floor(py / 256);
      const t  = await tile(tx, ty);
      const o  = ((py - ty * 256) * 256 + (px - tx * 256)) * t.ch;
      const a  = t.ch >= 4 ? t.data[o + 3] : 255;
      const k  = rvClass(t.data[o], t.data[o + 1], t.data[o + 2], a);
      checked++;
      if (k === 'wet' || k === 'heavy') wet++;
      if (k === 'heavy') heavy++;
      if (dx === 0 && dy === 0 && k !== 'none') atPoint = true;
    }
  }

  return {
    source: 'rainviewer',
    sourceThai: 'RainViewer ตัวสำรอง',
    frameTime: frame.time,
    frameThai: new Date(frame.time * 1000).toLocaleString('sv-SE', { timeZone: 'Asia/Bangkok' }),
    metrePerPixel: Math.round(mpp),
    pixelsChecked: checked,
    rainPixels: wet,
    heavyPixels: heavy,
    rainPercent: checked ? Math.round(wet * 1000 / checked) / 10 : 0,
    atPoint
  };
}

// ------------------------------------------------------------

const handler = async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: CORS });

  const url = new URL(req.url);
  const km  = Number(url.searchParams.get('km') || KM) || KM;
  const want = url.searchParams.get('source') || 'auto';

  const tried: string[] = [];
  const order = want === 'rv' ? ['rv'] : want === 'tmd' ? ['tmd'] : ['tmd', 'rv'];

  for (const s of order) {
    try {
      const out = s === 'tmd' ? await readTakhli(km) : await readRainViewer(km);
      return new Response(JSON.stringify({
        ok: true, radiusKm: km, triedBefore: tried, ...out
      }, null, 2), { headers: CORS });
    } catch (e) {
      tried.push(s + ': ' + String(e).slice(0, 160));
    }
  }

  /* พังทุกแหล่งแล้วต้องบอกว่าพัง ห้ามตอบว่าไม่มีฝน
     ถ้าตอบว่าไม่มีฝนตอนที่อ่านไม่ได้ ระบบจะเงียบสนิทในวันที่ควรเตือนที่สุด */
  return new Response(JSON.stringify({ ok: false, error: tried.join(' | ') }),
    { status: 502, headers: CORS });
};

export default { fetch: withSupabase({ auth: 'none' }, handler) };
