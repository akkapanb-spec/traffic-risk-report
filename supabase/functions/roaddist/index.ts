// ============================================================
// วัดระยะทางถนนจริงระหว่างจุดเกิดเหตุ ด้วย Longdo Map
// ============================================================
// เดิมระบบจับกลุ่มจุดเสี่ยงซ้ำด้วยระยะเส้นตรง ซึ่งผิดในสองทาง
//   สองจุดคนละฝั่งแม่น้ำหรือคนละฝั่งทางรถไฟ เส้นตรงใกล้แต่ต้องขับอ้อมไกล
//   สองจุดบนถนนเส้นเดียวกันที่โค้งมาก เส้นตรงไกลแต่ขับถึงกันเร็ว
// ตัวนี้จึงถามระยะถนนจริงมาเก็บไว้ แล้วให้ตัวจับกลุ่มใช้ตัวเลขนั้นแทน
//
// deploy: Supabase Dashboard -> Edge Functions -> roaddist -> Code -> Deploy updates
//         ต้องปิด "Verify JWT with legacy secret" ในแท็บ Settings ทุกครั้งหลัง deploy
// ต้องมี secret ชื่อ LONGDO_API_KEY
//
// ------------------------------------------------------------
// สิ่งที่ตัวนี้ตั้งใจไม่ทำ
// ------------------------------------------------------------
// ไม่ถามคู่ที่เส้นตรงห่างเกิน 300 เมตร เพราะระยะถนนยาวกว่าเส้นตรงเสมอ
//   คู่แบบนั้นเป็นไปไม่ได้ที่จะต่ำกว่าเกณฑ์ 120 เมตร การกรองอยู่ในฝั่งฐานข้อมูลแล้ว
// ไม่ถามซ้ำคู่ที่เคยถามแล้ว ต่อให้ครั้งนั้นตอบไม่ได้ก็ตาม
//   เพราะถ้าถามซ้ำทุกวัน คู่ที่หาเส้นทางไม่ได้จะกินโควตาไปเรื่อย ๆ โดยไม่ได้อะไรเลย
// ไม่คำนวณอะไรเองเมื่อ Longdo ตอบไม่ได้ บันทึกว่าไม่รู้ ไม่เดาด้วยเส้นตรง
//   เพราะตัวเลขที่เดามาจะแยกไม่ออกจากตัวเลขที่วัดจริง แล้ววันหนึ่งจะไม่มีใครรู้ว่าอันไหนเป็นอันไหน
// ============================================================

import { withSupabase } from 'npm:@supabase/server@^1';

const LONGDO = 'https://api.longdo.com/RouteService/json/route/guide';

/* ยิงทีละคำขอ ไม่ยิงพร้อมกัน
   วัดจริงเมื่อ 26 ส.ค. 2569 ยิงพร้อมกันสี่คำขอ ขอไป 200 คู่ ได้มา 72 คู่
   อีก 128 คู่ถูกปฏิเสธด้วยข้อความ Too many requests
   งานนี้ไม่รีบ ทำงานเบื้องหลัง ยิงช้าแล้วได้ครบดีกว่ายิงเร็วแล้วได้ครึ่งเดียว */
const CONCURRENCY = 1;
const GAP_MS = 250;
const PER_RUN = 200;

const sleep = (ms: number) => new Promise(r => setTimeout(r, ms));

/* ข้อผิดพลาดชนิดที่ต้องหยุดทั้งรอบ ไม่ใช่ข้ามไปคู่ถัดไป
   ถ้าโดนปฏิเสธเพราะยิงถี่แล้วยังยิงต่อ จะโดนปฏิเสธทั้งชุดโดยไม่ได้อะไรเลย */
class RateLimited extends Error {}

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Content-Type': 'application/json; charset=utf-8'
};

type Todo = {
  a_id: number; b_id: number;
  alat: number; alng: number;
  blat: number; blng: number;
  straight_m: number;
};

async function roadMetres(t: Todo, key: string): Promise<number | null> {
  const u = LONGDO
    + '?flon=' + t.alng + '&flat=' + t.alat
    + '&tlon=' + t.blng + '&tlat=' + t.blat
    + '&locale=th&key=' + encodeURIComponent(key);

  const res = await fetch(u, { cache: 'no-store' });
  if (res.status === 429) throw new RateLimited('Longdo ปฏิเสธเพราะยิงถี่เกินไป');
  if (!res.ok) throw new Error('Longdo ตอบ ' + res.status);

  /* ต้องอ่านเป็นข้อความก่อน ห้ามเรียก res.json() ตรง ๆ
     เวลาโดนจำกัดความถี่ Longdo ตอบรหัส 200 แต่เนื้อความเป็น javascript ว่า
     throw 'Too many requests'  ซึ่งไม่ใช่ json
     ถ้าแปลงเป็น json ทันทีจะได้ข้อผิดพลาดเรื่องไวยากรณ์ แล้วเข้าใจผิดว่าเป็นคู่เสีย
     ทั้งที่ความจริงคือเรายิงเร็วเกินไปและต้องหยุด */
  const raw = await res.text();
  if (raw.includes('Too many requests') || raw.trimStart().startsWith('throw')) {
    throw new RateLimited('Longdo ปฏิเสธเพราะยิงถี่เกินไป');
  }

  let j: any;
  try { j = JSON.parse(raw); }
  catch { throw new Error('คำตอบไม่ใช่ json: ' + raw.slice(0, 60)); }
  const d = j?.data?.[0]?.distance;

  /* ยอมรับเฉพาะตัวเลขที่เป็นไปได้จริง
     ระยะถนนต้องไม่สั้นกว่าระยะเส้นตรง ถ้าสั้นกว่าแปลว่าอ่านผิดหรือได้ค่าที่ไม่ใช่ระยะ
     ปล่อยผ่านไปจะได้กลุ่มที่กว้างเกินจริง แล้วเตือนผิดจุด */
  if (typeof d !== 'number' || !isFinite(d) || d < 0) return null;
  if (d + 5 < t.straight_m) return null;
  return Math.round(d);
}

const handler = async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: CORS });

  const key = Deno.env.get('LONGDO_API_KEY') || '';
  if (!key) {
    return new Response(JSON.stringify({ ok: false, error: 'ยังไม่ได้ตั้ง LONGDO_API_KEY' }),
      { status: 500, headers: CORS });
  }

  const url  = new URL(req.url);
  const days = Number(url.searchParams.get('days') || 60) || 60;
  const max  = Math.min(Number(url.searchParams.get('limit') || PER_RUN) || PER_RUN, 500);

  const base = Deno.env.get('SUPABASE_URL');
  const srv  = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!base || !srv) {
    return new Response(JSON.stringify({ ok: false, error: 'ไม่พบค่าเชื่อมต่อฐานข้อมูล' }),
      { status: 500, headers: CORS });
  }

  const rpc = async (fn: string, body: unknown) => {
    const r = await fetch(base + '/rest/v1/rpc/' + fn, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': srv,
        'Authorization': 'Bearer ' + srv
      },
      body: JSON.stringify(body)
    });
    if (!r.ok) throw new Error(fn + ' ตอบ ' + r.status + ' ' + (await r.text()).slice(0, 200));
    return r.json();
  };

  try {
    const todo: Todo[] = await rpc('road_dist_todo', { p_days: days, p_limit: max });
    if (!Array.isArray(todo) || todo.length === 0) {
      return new Response(JSON.stringify({ ok: true, todo: 0, asked: 0, saved: 0,
        message: 'ไม่มีคู่ใหม่ให้ถาม' }, null, 2), { headers: CORS });
    }

    const out: Array<{ a: number; b: number; m: number | null; s: number }> = [];
    const errors: string[] = [];
    let i = 0;
    let limited = false;

    async function worker() {
      while (i < todo.length && !limited) {
        const t = todo[i++];
        try {
          const m = await roadMetres(t, key);
          out.push({ a: t.a_id, b: t.b_id, m, s: t.straight_m });
        } catch (e) {
          if (e instanceof RateLimited) {
            /* หยุดทั้งรอบ แล้วเก็บเท่าที่ได้ คู่ที่เหลือยังไม่มีแถวในตาราง
               จึงถูกถามใหม่รอบหน้าเองโดยไม่ต้องจำอะไรไว้ */
            limited = true;
            if (errors.length < 5) errors.push(String(e.message));
            break;
          }
          /* เก็บข้อผิดพลาดไว้รายงาน แต่ไม่บันทึกลงตาราง
             คู่นี้จะถูกถามใหม่รอบหน้า ซึ่งถูกต้อง เพราะยังไม่เคยได้คำตอบจริง */
          if (errors.length < 5) errors.push(String(e).slice(0, 120));
        }
        if (GAP_MS > 0) await sleep(GAP_MS);
      }
    }

    await Promise.all(Array.from({ length: Math.min(CONCURRENCY, todo.length) }, worker));

    let saved = 0;
    if (out.length) {
      const r = await rpc('road_dist_save', { p_rows: out });
      saved = r?.saved ?? 0;
    }

    return new Response(JSON.stringify({
      ok: true,
      todo: todo.length,
      asked: out.length,
      saved,
      failed: todo.length - out.length,
      rateLimited: limited,
      note: limited ? 'หยุดกลางรอบเพราะถูกจำกัดความถี่ คู่ที่เหลือจะถามใหม่รอบหน้า' : '',
      errors
    }, null, 2), { headers: CORS });

  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e).slice(0, 300) }),
      { status: 500, headers: CORS });
  }
};

export default { fetch: withSupabase({ auth: 'none' }, handler) };
