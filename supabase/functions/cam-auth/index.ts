// ============================================================
// ตัวตรวจสิทธิ์ดูกล้อง — MediaMTX ถามที่นี่ทุกครั้งก่อนปล่อยภาพ
// ============================================================
// หน้าที่เดียว: รับคำถามจาก MediaMTX ว่า "คนนี้ดูได้ไหม" แล้วตอบ 200 หรือ 401
//
// ทำไมต้องมี
//   พอเอากล้องออกนอกวงแลนผ่าน tunnel การกั้นด้วยเลข IP ใช้ไม่ได้อีกต่อไป
//   เพราะทุกคำขอจะวิ่งมาจากที่อยู่ของ tunnel เหมือนกันหมด
//   ถ้าไม่มีตัวนี้ ใครรู้ลิงก์ก็ดูกล้องวงจรปิดของหน่วยได้ทั้งโลก
//
//   ตัวนี้ผูกสิทธิ์ดูกล้องเข้ากับการล็อกอินของระบบเจ้าหน้าที่ที่มีอยู่แล้ว
//   ใครไม่ได้ล็อกอิน หรือ session หมดอายุ ก็ดูไม่ได้ แม้จะรู้ลิงก์
//
// deploy: Supabase Dashboard → Edge Functions → Deploy a new function
//         ชื่อ  cam-auth
//         หลัง deploy ต้องปิด "Verify JWT with legacy secret" ในแท็บ Settings ทุกครั้ง
//         (MediaMTX ไม่ได้ส่ง header ของ Supabase มาด้วย)
//
// ไม่ต้องตั้ง secret อะไรเลย ใช้ค่าที่ Supabase ใส่ให้เองทั้งหมด
// ============================================================

import { withSupabase } from 'npm:@supabase/server@^1';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';

/* Supabase เปลี่ยนชื่อคีย์ระหว่างทาง โปรเจกต์ที่สร้างคนละช่วงมีชื่อไม่เหมือนกัน
   อ่านตัวเดียวแล้วไม่เจอจะกลายเป็นปฏิเสธทุกคน โดยไม่มีอะไรบอกว่าเพราะอะไร */
const DB_KEY =
  Deno.env.get('SUPABASE_ANON_KEY') ??
  Deno.env.get('SUPABASE_PUBLISHABLE_KEY') ??
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

// ปฏิเสธไว้ก่อนเสมอเมื่อมีอะไรผิดปกติ — ระบบกล้องต้องพังไปทางที่ปลอดภัย
const deny  = (why: string) => new Response(why, { status: 401 });
const allow = () => new Response('ok', { status: 200 });

/* หา token จากที่ที่ MediaMTX ส่งมาได้ ไล่ตามลำดับที่น่าจะเจอ
   รูปแบบ payload ต่างกันเล็กน้อยตามรุ่นและตามโปรโตคอล
   จึงมองหลายที่ ดีกว่าผูกกับรุ่นใดรุ่นหนึ่งแล้วพังตอนอัปเกรด */
function pickToken(body: Record<string, unknown>): string {
  const q = String(body.query ?? '');
  if (q) {
    const v = new URLSearchParams(q.startsWith('?') ? q.slice(1) : q).get('token');
    if (v) return v;
  }
  return String(body.token ?? body.password ?? '');
}

const handler = async (req: Request): Promise<Response> => {
  // เปิดด้วยเบราว์เซอร์เพื่อดูว่าตัวนี้ยังมีชีวิตอยู่ไหม
  if (req.method === 'GET') {
    return new Response('cam-auth พร้อมทำงาน · ต้องเรียกด้วย POST จาก MediaMTX เท่านั้น');
  }
  if (req.method !== 'POST') return deny('method ไม่ถูกต้อง');

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return deny('อ่าน body ไม่ได้'); }

  /* ปล่อยเฉพาะการ "ดู" เท่านั้น
     MediaMTX ใช้ช่องทางเดียวกันถามทั้งการดูและการส่งสัญญาณเข้ามา
     ถ้าไม่กั้น คนนอกจะยิงภาพปลอมเข้ามาแทนที่ภาพกล้องจริงได้ */
  const action = String(body.action ?? '');
  if (action && action !== 'read') return deny('อนุญาตเฉพาะการดู');

  const token = pickToken(body);
  if (!token) return deny('ไม่มี token');

  try {
    const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/officer_session_user`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', apikey: DB_KEY, Authorization: `Bearer ${DB_KEY}` },
      body: JSON.stringify({ p_token: token })
    });
    if (!res.ok) { console.error('ตรวจ session ไม่ได้', res.status); return deny('ตรวจสิทธิ์ไม่สำเร็จ'); }

    // คืน null เมื่อ token ใช้ไม่ได้หรือหมดอายุ — เป็นสัญญาว่าที่ฟังก์ชันนี้ใช้ทั้งระบบ
    const user = await res.json();
    if (!user) return deny('session หมดอายุ กรุณาเข้าสู่ระบบใหม่');

    return allow();
  } catch (e) {
    // ต่อฐานข้อมูลไม่ได้ก็ต้องปฏิเสธ ไม่ใช่ปล่อยผ่าน
    console.error('cam-auth error', e);
    return deny('ระบบตรวจสิทธิ์ขัดข้อง');
  }
};

export default { fetch: withSupabase({ auth: 'none' }, handler) };
