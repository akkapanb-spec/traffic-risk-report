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
const KM  = 8;                        // รัศมีที่ใช้ตัดสินว่าฝนเข้าเมืองแล้ว

/* วงนอกใช้มองหาฝนที่ยังมาไม่ถึง เพื่อบอกทิศทางและเวลาที่คาดว่าจะถึง
   30 กม. ที่ความเร็วฝนราว 18 กม./ชม. เท่ากับเห็นล่วงหน้าราวหนึ่งชั่วโมง
   กว้างกว่านี้ก็ได้ แต่ฝนที่อยู่ไกลเกินหนึ่งชั่วโมงมักสลายหรือเปลี่ยนทางก่อนถึง
   การรายงานมันจึงเป็นการเดามากกว่าการเตือน */
const OUTER_KM = 30;

/* ------------------------------------------------------------
   ภาพย้อนหลังของกรมฯ  ใช้หาทิศทางที่ฝนเคลื่อน
   ------------------------------------------------------------
   หน้าเว็บของกรมฯ มีภาพย้อนหลังหกใบ ชื่อ tkl1 ถึง tkl6
   tkl1 เก่าสุด tkl6 ใหม่สุด ห่างกันใบละ 6 นาที รวม 30 นาที
   ยืนยันจากเวลากำกับในภาพเมื่อ 28 ส.ค. 2569  23:18 23:24 23:30 23:36 23:42 23:48
   ตัวเลขนี้ยังบอกด้วยว่าเรดาร์ออกภาพใหม่ทุก 6 นาที
   การตรวจถี่กว่านั้นจึงได้ภาพซ้ำ ไม่ได้ข้อมูลเพิ่ม

   ภาพย้อนหลังย่อขนาดลงเหลือ 683x536 ไม่เท่าภาพหลักที่ 1020x800
   ค่ามาตราส่วนจึงคนละชุด วัดด้วยการฟิตวงระยะเช่นเดียวกับภาพหลัก
   ได้วงที่ 56 112 168 223 พิกเซล ตรงกับ 50 100 150 200 กิโลเมตร
   จึงเป็น 0.895 กม. ต่อพิกเซล และศูนย์กลางอยู่ที่ 267, 267 */
const LOOP_URL  = 'https://weather.tmd.go.th/tkl/tkl';
const LOOP_CX   = 267;
const LOOP_CY   = 267;
const LOOP_KMPX = 0.8949;
const LOOP_GAP_MIN = 6;

/* ใช้เฉพาะสามใบล่าสุด ไม่ดึงทั้งหกใบ
   สามใบให้การเทียบสองคู่ ซึ่งพอจะรู้ว่าผลนิ่งหรือไม่นิ่ง
   ดึงหกใบก็ได้ผลดีขึ้นเล็กน้อย แต่โหลดภาพจากเครื่องของราชการเป็นสองเท่า
   ภาพใบละ 533 กิโลไบต์ ดึงเฉพาะตอนมีฝนเท่านั้น วันฟ้าใสจึงไม่ดึงเลย */
const LOOP_FRAMES = [4, 5, 6];

/* รัศมีที่ใช้เทียบภาพ  120 กม. ครอบคลุมฝนที่จะถึงเราภายในหกชั่วโมง
   กว้างกว่านี้ทำให้ช้าลงโดยไม่ได้ความแม่นเพิ่ม */
const LOOP_RAD_KM = 120;

/* ค้นหาการเลื่อนไม่เกิน 12 พิกเซล เท่ากับ 10.7 กม. ต่อ 6 นาที หรือ 107 กม./ชม.
   เร็วกว่านี้ไม่ใช่ฝน  ถ้าเจอค่าติดขอบการค้นหา แปลว่าจับผิดก้อน จึงทิ้งผลนั้น */
const LOOP_MAX_SHIFT = 12;

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

  /* ------------------------------------------------------------
     วงนอก  ใช้ตอบว่าฝนที่ยังมาไม่ถึง อยู่ทางไหนและใกล้แค่ไหน
     ------------------------------------------------------------
     เก็บสามอย่าง
       จุดศูนย์กลางของกลุ่มฝน  เอาไว้เทียบสองรอบเพื่อหาทิศที่มันเคลื่อน
       ระยะของฝนที่ใกล้ที่สุด   เอาไว้คำนวณว่าอีกกี่นาทีจะถึง
       จำนวนจุดที่มีฝน         เอาไว้ดูว่ากลุ่มโตขึ้นหรือสลายไป

     ใช้ระยะที่ใกล้ที่สุดคำนวณเวลา ไม่ใช้จุดศูนย์กลาง
     เพราะขอบของก้อนฝนคือสิ่งที่มาถึงคนก่อน ไม่ใช่ใจกลางก้อน */
  const oRad = OUTER_KM / TKL_KMPX;
  let oChecked = 0, oRain = 0, sumX = 0, sumY = 0, nearestPx = Infinity;
  let nearDx = 0, nearDy = 0;

  for (let dy = -Math.ceil(oRad); dy <= Math.ceil(oRad); dy++) {
    for (let dx = -Math.ceil(oRad); dx <= Math.ceil(oRad); dx++) {
      const d2 = dx * dx + dy * dy;
      if (d2 > oRad * oRad) continue;
      const x = Math.round(cx + dx), y = Math.round(cy + dy);
      if (x < 0 || y < 0 || x >= img.width || y >= img.height) continue;
      const o = (y * img.width + x) * ch;
      const v = dbzAt(dat[o], dat[o + 1], dat[o + 2]);
      oChecked++;
      if (v === null || v < TKL_MIN_DBZ) continue;
      oRain++;
      sumX += dx; sumY += dy;
      if (d2 < nearestPx) { nearestPx = d2; nearDx = dx; nearDy = dy; }
    }
  }

  /* แปลงตำแหน่งพิกเซลกลับเป็นละติจูดลองจิจูด
     ที่ละติจูดนี้ หนึ่งองศาเหนือใต้ราว 111.32 กม. ส่วนตะวันออกตกต้องคูณโคไซน์ */
  const kmPerDegLat = 111.32;
  const kmPerDegLng = 111.32 * Math.cos(LAT * Math.PI / 180);
  const cLat = oRain ? LAT - (sumY / oRain) * TKL_KMPX / kmPerDegLat : null;
  const cLng = oRain ? LNG + (sumX / oRain) * TKL_KMPX / kmPerDegLng : null;

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

    outerRadiusKm: OUTER_KM,
    outerChecked: oChecked,
    outerRainPixels: oRain,
    outerPercent: oChecked ? Math.round(oRain * 1000 / oChecked) / 10 : 0,
    /* ระยะถึงฝนที่ใกล้ที่สุด  null เมื่อไม่มีฝนเลยในวงนอก
       ไม่ใช้เลข 0 แทนไม่มีฝน เพราะ 0 แปลว่าฝนอยู่บนหัวพอดี ซึ่งตรงข้ามกันคนละขั้ว */
    nearestKm: oRain ? Math.round(Math.sqrt(nearestPx) * TKL_KMPX * 10) / 10 : null,
    /* ตำแหน่งของฝนที่ใกล้ที่สุด เทียบจากแยกเดชาติวงศ์ หน่วยกิโลเมตร
       บวกคือตะวันออกและเหนือ  ใช้คู่กับทิศที่ฝนเคลื่อน เพื่อคำนวณว่าเข้าหาเราจริงไหม */
    nearestEastKm:  oRain ? Math.round(nearDx * TKL_KMPX * 10) / 10 : null,
    nearestNorthKm: oRain ? Math.round(-nearDy * TKL_KMPX * 10) / 10 : null,
    centroidLat: cLat === null ? null : Math.round(cLat * 100000) / 100000,
    centroidLng: cLng === null ? null : Math.round(cLng * 100000) / 100000,
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


// ------------------------------------------------------------
// ทิศทางที่ฝนเคลื่อน  ด้วยการเลื่อนภาพไปทับกัน
// ------------------------------------------------------------
// วิธีแรกที่ลองคือหาจุดศูนย์กลางของกลุ่มฝนแล้วดูว่าขยับไปไหน
// ทดสอบกับภาพจริงหกใบเมื่อ 28 ส.ค. 2569 แล้วได้ 173 กม./ชม. แกว่ง บวกลบ 144
// ซึ่งเป็นไปไม่ได้ ฝนไม่เคลื่อนที่เร็วกว่าเครื่องบิน
//
// สาเหตุคือในภาพมีกลุ่มฝนกระจายหลายก้อน จุดศูนย์กลางเฉลี่ยจึงกระโดดไปมา
// ตามก้อนที่โผล่และหายไป มันไม่ได้ติดตามก้อนใดเลย
//
// วิธีนี้เลื่อนภาพทั้งภาพไปทับภาพก่อนหน้าทีละพิกเซล แล้วหาว่าเลื่อนเท่าไรทับกันดีที่สุด
// ทนต่อการที่ก้อนหนึ่งสลายและอีกก้อนก่อตัว เพราะดูรูปทรงรวมไม่ใช่ค่าเฉลี่ยตำแหน่ง
// ข้อมูลชุดเดียวกันให้ 12 กม./ชม. แกว่ง บวกลบ 9 ซึ่งเป็นความเร็วฝนที่เป็นจริง

const LOOP_RAD_PX = Math.round(LOOP_RAD_KM / LOOP_KMPX);
const LOOP_SIZE   = LOOP_RAD_PX * 2 + 1;

async function loopMask(n: number): Promise<Uint8Array | null> {
  const res = await fetch(LOOP_URL + n + '.png', { headers: { 'User-Agent': UA }, cache: 'no-store' });
  if (!res.ok) return null;
  const img = decode(new Uint8Array(await res.arrayBuffer()));

  /* ภาพย้อนหลังต้องเป็นขนาดที่วัดมาตราส่วนไว้ ถ้าไม่ใช่ให้เลิกใช้
     คำนวณต่อด้วยมาตราส่วนผิดจะได้ทิศที่ดูสมเหตุสมผลแต่ผิด ซึ่งอันตรายกว่าไม่มีเลย */
  if (img.width !== 683 || img.height !== 536) return null;

  const dat = img.data as Uint8Array, ch = img.channels, W = img.width;
  const m = new Uint8Array(LOOP_SIZE * LOOP_SIZE);
  for (let dy = -LOOP_RAD_PX; dy <= LOOP_RAD_PX; dy++) {
    for (let dx = -LOOP_RAD_PX; dx <= LOOP_RAD_PX; dx++) {
      if (dx * dx + dy * dy > LOOP_RAD_PX * LOOP_RAD_PX) continue;
      const x = LOOP_CX + dx, y = LOOP_CY + dy;
      if (x < 0 || y < 0 || x >= img.width || y >= img.height) continue;
      const o = (y * W + x) * ch;
      const v = dbzAt(dat[o], dat[o + 1], dat[o + 2]);
      if (v === null || v < TKL_MIN_DBZ) continue;
      m[(dy + LOOP_RAD_PX) * LOOP_SIZE + (dx + LOOP_RAD_PX)] = 1;
    }
  }
  return m;
}

function bestShift(a: Uint8Array, b: Uint8Array) {
  let best = { score: -1, dx: 0, dy: 0 };
  const lim = LOOP_MAX_SHIFT;
  for (let dy = -lim; dy <= lim; dy++) {
    for (let dx = -lim; dx <= lim; dx++) {
      let hit = 0;
      for (let y = lim; y < LOOP_SIZE - lim; y += 2) {
        const rowB = (y + dy) * LOOP_SIZE + dx;
        const rowA = y * LOOP_SIZE;
        for (let x = lim; x < LOOP_SIZE - lim; x += 2) {
          if (b[rowB + x] && a[rowA + x]) hit++;
        }
      }
      if (hit > best.score) best = { score: hit, dx, dy };
    }
  }
  return best;
}

async function takhliMotion() {
  const masks: Array<Uint8Array | null> = [];
  for (const n of LOOP_FRAMES) masks.push(await loopMask(n));
  if (masks.some(m => m === null)) return { ok: false, why: 'อ่านภาพย้อนหลังไม่ครบ' };

  const counts = masks.map(m => m!.reduce((s, v) => s + v, 0));

  /* ฝนน้อยเกินไป การเลื่อนภาพทับกันจะเจอค่าสูงสุดหลายจุดพอ ๆ กัน แล้วเลือกมั่ว
     ต่ำกว่าสามสิบจุดถือว่าไม่พอ บอกไปตรง ๆ ดีกว่าคืนทิศที่เดาเอา */
  if (counts.some(c => c < 30)) {
    return { ok: false, why: 'ฝนในภาพน้อยเกินกว่าจะหาทิศได้', pixels: counts };
  }

  const vs: Array<{ ex: number; ny: number }> = [];
  for (let i = 1; i < masks.length; i++) {
    const sh = bestShift(masks[i - 1]!, masks[i]!);

    /* ค่าที่ติดขอบการค้นหา แปลว่าของจริงอาจอยู่ไกลกว่านั้น หรือจับผิดก้อน
       ทิ้งไป ไม่เอามาเฉลี่ย */
    if (Math.abs(sh.dx) >= LOOP_MAX_SHIFT || Math.abs(sh.dy) >= LOOP_MAX_SHIFT) continue;

    vs.push({
      ex: sh.dx * LOOP_KMPX / (LOOP_GAP_MIN / 60),
      ny: -sh.dy * LOOP_KMPX / (LOOP_GAP_MIN / 60)
    });
  }
  if (!vs.length) return { ok: false, why: 'เทียบภาพไม่ได้สักคู่' };

  const ex = vs.reduce((s, v) => s + v.ex, 0) / vs.length;
  const ny = vs.reduce((s, v) => s + v.ny, 0) / vs.length;
  const kmh = Math.hypot(ex, ny);

  /* ความไม่แน่นอน วัดจากการที่แต่ละคู่ให้ผลต่างกันแค่ไหน
     ถ้าสองคู่ชี้คนละทาง ตัวเลขเฉลี่ยไม่มีความหมาย ฝั่งฐานข้อมูลจะได้ไม่เอาไปใช้ */
  const spread = vs.length < 2 ? null
    : Math.round(Math.max(...vs.map(v => Math.hypot(v.ex - ex, v.ny - ny))) * 10) / 10;

  let toDeg = Math.atan2(ex, ny) * 180 / Math.PI;
  if (toDeg < 0) toDeg += 360;

  return {
    ok: true,
    speedKmh: Math.round(kmh * 10) / 10,
    eastKmh:  Math.round(ex * 10) / 10,
    northKmh: Math.round(ny * 10) / 10,
    toDeg: Math.round(toDeg),
    fromDeg: Math.round((toDeg + 180) % 360),
    pairs: vs.length,
    spreadKmh: spread,
    framePixels: counts
  };
}

const handler = async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: CORS });

  const url = new URL(req.url);
  const km  = Number(url.searchParams.get('km') || KM) || KM;
  const want = url.searchParams.get('source') || 'auto';

  const tried: string[] = [];
  const order = want === 'rv' ? ['rv'] : want === 'tmd' ? ['tmd'] : ['tmd', 'rv'];

  for (const s of order) {
    try {
      const out: any = s === 'tmd' ? await readTakhli(km) : await readRainViewer(km);

      /* หาทิศทางเฉพาะตอนมีฝนในวงนอกเท่านั้น
         วันฟ้าใสจึงไม่ดึงภาพย้อนหลังเลย ไม่เพิ่มภาระให้เครื่องของกรมฯ ฟรี ๆ */
      /* motion=1 บังคับให้คำนวณแม้ไม่มีฝนในวง 30 กม.
         มีไว้เพื่อทดสอบว่าตัวคำนวณทำงานถูก โดยไม่ต้องรอให้ฝนตกจริง
         ถ้าไม่มีทางทดสอบ เราจะได้รู้ว่ามันพังก็ต่อเมื่อวันที่ต้องใช้จริง */
      const forceMotion = url.searchParams.get('motion') === '1';
      if (s === 'tmd' && (out.outerRainPixels > 0 || forceMotion)
          && url.searchParams.get('motion') !== '0') {
        try { out.motion = await takhliMotion(); }
        catch (e) { out.motion = { ok: false, why: String(e).slice(0, 120) }; }
      }

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
