// ============================================================
// อ่านเรดาร์ฝนตรงพื้นที่เรา — จาก RainViewer
// ============================================================
// ฐานข้อมูลอ่านค่าสีจากภาพ PNG เองไม่ได้ จึงต้องมีตัวกลางตัวนี้
// หน้าที่เดียว คือตอบว่า "ตอนนี้มีฝนในรัศมีรอบแยกเดชาติวงศ์หรือไม่" เป็นตัวเลข
// การตัดสินใจว่าจะส่งข้อความหรือไม่ อยู่ฝั่งฐานข้อมูล ไม่ใช่ที่นี่
//
// deploy: Supabase Dashboard -> Edge Functions -> rain -> Code -> Deploy updates
//         และต้องปิด "Verify JWT with legacy secret" ในแท็บ Settings ทุกครั้งหลัง deploy
// ไม่ต้องตั้ง secret ใด ๆ RainViewer เปิดให้ใช้ฟรีโดยไม่ต้องมีกุญแจ
//
// ข้อเท็จจริงที่วัดมาแล้วเมื่อ 25 ส.ค. 2569 และเป็นเหตุผลของตัวเลขในไฟล์นี้
//   1 RainViewer แบบฟรีมีภาพเรดาร์จริงถึงระดับซูม 7 เท่านั้น
//     ซูม 8 ขึ้นไปคืนภาพสำรองสีเทาเหมือนกันทุกใบ ทุกพิกัด ทุกชุดสี
//     ถ้าเผลอไปอ่านที่ซูม 8 จะได้ผลว่าฝนตกตลอดเวลาทั้งที่ฟ้าใส
//   2 ที่ซูม 7 หนึ่งพิกเซลกว้างราว 1,177 เมตร รัศมี 8 กม. จึงเป็นวงราว 7 พิกเซล
//   3 พารามิเตอร์ชุดสีถูกละเลย ขอชุดไหนก็ได้ภาพเดียวกัน จึงต้องอ่านสีชุดมาตรฐาน
//   4 ในภาพมีสีเทาอมเขียวจำนวนมากซึ่งไม่ใช่ฝน เป็นสัญญาณรบกวนจากภูมิประเทศ
//     ถ้านับทุกพิกเซลที่ไม่โปร่งใสว่าเป็นฝน ระบบจะเตือนแทบทุกวันทั้งที่ไม่มีฝน
// ============================================================

import { withSupabase } from 'npm:@supabase/server@^1';
import { decode } from 'npm:fast-png@6.2.0';

const ZOOM = 7;                       // ระดับสูงสุดที่มีข้อมูลจริง ห้ามเพิ่ม
const LAT  = 15.693907;               // แยกเดชาติวงศ์ จากพิกัดที่เจ้าหน้าที่บันทึกไว้เอง
const LNG  = 100.122704;
const KM   = 8;                       // รัศมีที่เฝ้า ให้เวลาล่วงหน้าราว 15 นาที

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Content-Type': 'application/json; charset=utf-8'
};

/* แปลงพิกัดเป็นตำแหน่งพิกเซลบนแผนที่โลกที่ระดับซูมหนึ่ง */
function worldPx(lat: number, lng: number, z: number) {
  const n = 256 * Math.pow(2, z);
  const x = (lng + 180) / 360 * n;
  const s = Math.sin(lat * Math.PI / 180);
  const y = (0.5 - Math.log((1 + s) / (1 - s)) / (4 * Math.PI)) * n;
  return { x, y };
}

/* จำแนกสีว่าเป็นฝนหรือไม่
   วัดจากภาพจริงแล้วพบสามกลุ่ม
     เทาอมเขียว เช่น 112,106,93   ไม่ใช่ฝน เป็นสัญญาณรบกวน
     น้ำตาลอ่อน เช่น 221,208,152  ขอบนอกของกลุ่มฝน แผ่กว้างกว่าฝนจริงมาก ไม่นับ
     ฟ้าถึงน้ำเงิน เช่น 0,127,180  ฝนเบาถึงปานกลาง  นับ
     เหลืองส้มแดง เช่น 255,238,0   ฝนหนัก  นับ
   น้ำตาลอ่อนมีค่าน้ำเงินราว 152 ซึ่งสูงกว่าเกณฑ์ 100 จึงถูกตัดออกโดยอัตโนมัติ */
function classify(r: number, g: number, b: number, a: number): 'none' | 'wet' | 'heavy' {
  if (a === 0) return 'none';
  if (r > 180 && b < 100) return 'heavy';   // เหลือง ส้ม แดง
  if (b - r > 40) return 'wet';             // ฟ้า น้ำเงิน
  return 'none';
}

const handler = async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: CORS });

  const url = new URL(req.url);
  const km = Number(url.searchParams.get('km') || KM) || KM;

  try {
    const meta = await (await fetch('https://api.rainviewer.com/public/weather-maps.json',
      { cache: 'no-store' })).json();
    const past = meta?.radar?.past ?? [];
    if (!past.length) {
      return new Response(JSON.stringify({ ok: false, error: 'RainViewer ไม่มีเฟรมให้' }),
        { status: 502, headers: CORS });
    }
    const frame = past[past.length - 1];

    const c   = worldPx(LAT, LNG, ZOOM);
    const mpp = 156543.03392 * Math.cos(LAT * Math.PI / 180) / Math.pow(2, ZOOM);
    const rad = km * 1000 / mpp;

    /* โหลดเฉพาะไทล์ที่วงกลมพาดผ่านจริง ปกติหนึ่งถึงสี่ใบ
       เก็บไว้ในแมปกันโหลดซ้ำเมื่อหลายพิกเซลอยู่ไทล์เดียวกัน */
    const tiles = new Map<string, { data: Uint8Array | Uint16Array; ch: number }>();
    async function tile(tx: number, ty: number) {
      const key = tx + '/' + ty;
      const hit = tiles.get(key);
      if (hit) return hit;
      const u = meta.host + frame.path + '/256/' + ZOOM + '/' + tx + '/' + ty + '/2/1_1.png';
      const buf = new Uint8Array(await (await fetch(u)).arrayBuffer());
      const img = decode(buf);
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
        const ix = px - tx * 256, iy = py - ty * 256;
        const o  = (iy * 256 + ix) * t.ch;

        /* ภาพของ RainViewer เป็น PNG แบบมีช่องโปร่งใส
           ถ้าเจอภาพที่ไม่มีช่องโปร่งใส ให้ถือว่าทึบทั้งภาพ */
        const r = t.data[o], g = t.data[o + 1], b = t.data[o + 2];
        const a = t.ch >= 4 ? t.data[o + 3] : 255;

        const k = classify(r, g, b, a);
        checked++;
        if (k === 'wet' || k === 'heavy') wet++;
        if (k === 'heavy') heavy++;
        if (dx === 0 && dy === 0 && k !== 'none') atPoint = true;
      }
    }

    const pct = checked ? Math.round(wet * 1000 / checked) / 10 : 0;

    return new Response(JSON.stringify({
      ok: true,
      frameTime: frame.time,
      frameThai: new Date(frame.time * 1000).toLocaleString('sv-SE', { timeZone: 'Asia/Bangkok' }),
      zoom: ZOOM,
      metrePerPixel: Math.round(mpp),
      radiusKm: km,
      tilesUsed: tiles.size,
      pixelsChecked: checked,
      rainPixels: wet,
      heavyPixels: heavy,
      rainPercent: pct,
      atPoint
    }, null, 2), { headers: CORS });

  } catch (e) {
    /* พังแล้วต้องบอกว่าพัง ห้ามตอบว่าไม่มีฝน
       ถ้าตอบว่าไม่มีฝนตอนที่อ่านไม่ได้ ระบบจะเงียบสนิทในวันที่ควรเตือนที่สุด */
    return new Response(JSON.stringify({ ok: false, error: String(e).slice(0, 300) }),
      { status: 500, headers: CORS });
  }
};

export default { fetch: withSupabase({ auth: 'none' }, handler) };
