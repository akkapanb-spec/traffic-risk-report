// ============================================================
// LINE webhook — ระบบแจ้งข้อมูลจุดเสี่ยงอุบัติเหตุ สภ.เมืองนครสวรรค์
// ============================================================
// หน้าที่เดียว: รับข้อความที่คนพิมพ์เข้ามา ส่งไปถามฐานข้อมูล แล้วตอบกลับ
//
// ตั้งใจให้ไฟล์นี้ไม่รู้เรื่องข้อมูลเลยสักอย่าง — ไม่มีคำสั่ง ไม่มีรูปแบบข้อความ
// ไม่มีตารางไหนถูกอ้างถึง ทั้งหมดอยู่ใน line_reply() ในฐานข้อมูล
// เพราะแก้ SQL ทำได้ทันทีจาก SQL Editor ส่วนแก้ไฟล์นี้ต้อง deploy ใหม่ทุกครั้ง
// เพิ่มคำสั่งใหม่ เปลี่ยนข้อความ จึงไม่ต้องแตะไฟล์นี้อีกเลย
//
// deploy: Supabase Dashboard → Edge Functions → line-webhook → Code → Deploy updates
//         และต้องปิด "Verify JWT with legacy secret" ในแท็บ Settings ทุกครั้งหลัง deploy
//
// ต้องตั้ง secret 2 ตัวใน Edge Functions → Secrets
//   LINE_CHANNEL_SECRET        ใช้ตรวจว่าคำขอมาจาก LINE จริง
//   LINE_CHANNEL_ACCESS_TOKEN  ใช้ตอนตอบกลับ
//
// token ตัวเดียวกันนี้ต้องใส่ในฐานข้อมูลด้วย (line_set_token) เพราะคนละฝั่งกัน
// ฝั่งนี้ตอบกลับข้อความที่คนพิมพ์ ส่วนฝั่งฐานข้อมูลส่งแจ้งเตือนตามเวลา
// ============================================================

/* ตัวรัน Edge Function รุ่นใหม่ตรวจ credential ให้เองก่อนเข้าโค้ดเรา
   ปิดสวิตช์ Verify JWT ในแดชบอร์ดอย่างเดียวไม่พอ ยังโดนปฏิเสธที่ประตูหน้าด้วย
   INVALID_CREDENTIALS ต่อให้แนบ anon key มาก็ตาม

   auth: 'none' คือตัวสั่งให้ข้ามการตรวจนั้น จำเป็นสำหรับ webhook ของบุคคลที่สาม
   เพราะ LINE ไม่ได้แนบ credential ของ Supabase มาด้วย และบังคับให้แนบไม่ได้

   ความปลอดภัยไม่ได้หายไป — ย้ายมาอยู่ที่ verifySignature() ข้างล่างแทน
   ซึ่งตรวจ HMAC ของ LINE ทุกคำขอก่อนทำอะไรทั้งสิ้น */
import { withSupabase } from 'npm:@supabase/server@^1';

const CHANNEL_SECRET = Deno.env.get('LINE_CHANNEL_SECRET') ?? '';
const ACCESS_TOKEN   = Deno.env.get('LINE_CHANNEL_ACCESS_TOKEN') ?? '';
const SUPABASE_URL   = Deno.env.get('SUPABASE_URL') ?? '';

/* Supabase เปลี่ยนชื่อคีย์ระหว่างทาง โปรเจกต์ที่สร้างคนละช่วงเวลาจึงมีชื่อไม่เหมือนกัน
   ถ้าอ่านตัวเดียวแล้วไม่เจอ ฟังก์ชันจะเรียกฐานข้อมูลไม่ได้ และบอทจะเงียบสนิท
   โดยไม่มีอะไรฟ้อง — ไล่หาสาเหตุยากมาก จึงลองทุกชื่อที่เป็นไปได้ */
const DB_KEY =
  Deno.env.get('SUPABASE_ANON_KEY') ??
  Deno.env.get('SUPABASE_PUBLISHABLE_KEY') ??
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ??
  Deno.env.get('SUPABASE_SECRET_KEY') ?? '';

/* ตรวจลายเซ็นก่อนเสมอ
   URL ของ Edge Function เป็นสาธารณะ ใครเดาถูกก็ยิงเข้ามาได้
   ถ้าไม่ตรวจ คนอื่นจะปลอมเป็น LINE ส่ง event เข้ามาให้บอทตอบอะไรก็ได้
   LINE เซ็นด้วย HMAC-SHA256 ของ body ทั้งก้อน ด้วย channel secret */
async function verifySignature(body: string, signature: string): Promise<boolean> {
  if (!signature) return false;
  const key = await crypto.subtle.importKey(
    'raw', new TextEncoder().encode(CHANNEL_SECRET),
    { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']
  );
  const mac = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(body));
  const expected = btoa(String.fromCharCode(...new Uint8Array(mac)));
  // เทียบแบบเวลาคงที่ ไม่ให้เดาทีละตัวอักษรจากเวลาที่ตอบกลับ
  if (expected.length !== signature.length) return false;
  let diff = 0;
  for (let i = 0; i < expected.length; i++) diff |= expected.charCodeAt(i) ^ signature.charCodeAt(i);
  return diff === 0;
}

async function reply(replyToken: string, text: string) {
  const res = await fetch('https://api.line.me/v2/bot/message/reply', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${ACCESS_TOKEN}` },
    body: JSON.stringify({ replyToken, messages: [{ type: 'text', text: text.slice(0, 4900) }] })
  });
  if (!res.ok) console.error('LINE reply error', res.status, await res.text());
}

// ถามฐานข้อมูลว่าข้อความนี้ควรตอบอะไร — null แปลว่าไม่ต้องตอบ
async function askDatabase(text: string): Promise<{ action: string; text: string | null } | null> {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/line_reply`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', apikey: DB_KEY, Authorization: `Bearer ${DB_KEY}` },
    body: JSON.stringify({ p_text: text })
  });
  if (!res.ok) { console.error('line_reply error', res.status, await res.text()); return null; }
  return await res.json();
}

const handler = async (req: Request): Promise<Response> => {
  /* ตรวจสุขภาพตัวเอง — เปิด <url>?selftest=1 ในเบราว์เซอร์
     ตอนตั้งค่าครั้งแรกมีของต้องตั้งหลายที่ ทั้งสอง console ของ LINE และ Supabase
     พลาดที่เดียวบอทก็เงียบสนิทเหมือนกันหมด แยกไม่ออกว่าพลาดตรงไหน
     ตัวนี้บอกทีเดียวว่าอะไรพร้อมอะไรยัง
     คืนแค่ "ตั้งแล้วหรือยัง" กับผลเรียกใช้ ไม่คืนค่าของ secret สักตัว */
  if (req.method === 'GET' && new URL(req.url).searchParams.get('selftest') === '1') {
    const rpc = await askDatabase('#help');
    let lineToken = 'ไม่ได้ตรวจ (ยังไม่ได้ตั้ง token)';
    if (ACCESS_TOKEN) {
      try {
        const r = await fetch('https://api.line.me/v2/bot/info', {
          headers: { Authorization: `Bearer ${ACCESS_TOKEN}` }
        });
        lineToken = r.ok ? 'ใช้ได้ (' + r.status + ')' : 'ใช้ไม่ได้ (' + r.status + ') ' + (await r.text()).slice(0, 120);
      } catch (e) { lineToken = 'เรียก LINE ไม่ได้: ' + String(e); }
    }
    return new Response(JSON.stringify({
      ตั้ง_LINE_CHANNEL_SECRET: !!CHANNEL_SECRET,
      ตั้ง_LINE_CHANNEL_ACCESS_TOKEN: !!ACCESS_TOKEN,
      ตั้ง_SUPABASE_URL: !!SUPABASE_URL,
      ตั้ง_คีย์ฐานข้อมูล: !!DB_KEY,
      token_ใช้กับ_LINE_ได้จริง: lineToken,
      เรียกฐานข้อมูลได้: !!rpc,
      ตัวอย่างคำตอบจากฐานข้อมูล: rpc ? String(rpc.text ?? '').slice(0, 60) : null
    }, null, 2), { headers: { 'Content-Type': 'application/json; charset=utf-8' } });
  }

  if (req.method !== 'POST') return new Response('ok');   // LINE กดปุ่ม Verify ด้วย POST เปล่า

  /* แยกสาเหตุให้ชัด — สองอย่างนี้แก้คนละวิธีกันสิ้นเชิง
     แต่เดิมตอบ "bad signature" เหมือนกันทั้งคู่ ทำให้ตอนตั้งค่าครั้งแรก
     แยกไม่ออกว่าลืมใส่ secret หรือใส่ผิดค่า เสียเวลาไล่หาอยู่นาน */
  if (!CHANNEL_SECRET) {
    console.error('LINE_CHANNEL_SECRET is not set');
    return new Response('LINE_CHANNEL_SECRET not set — ไปตั้งที่ Edge Functions → Secrets', { status: 500 });
  }
  if (!ACCESS_TOKEN) {
    console.error('LINE_CHANNEL_ACCESS_TOKEN is not set');
    return new Response('LINE_CHANNEL_ACCESS_TOKEN not set — ไปตั้งที่ Edge Functions → Secrets', { status: 500 });
  }

  const raw = await req.text();
  if (!(await verifySignature(raw, req.headers.get('x-line-signature') ?? ''))) {
    return new Response('bad signature — secret ไม่ตรงกับ Channel นี้ หรือคำขอไม่ได้มาจาก LINE', { status: 401 });
  }

  let events: any[] = [];
  try { events = JSON.parse(raw).events ?? []; } catch { return new Response('ok'); }

  for (const ev of events) {
    try {
      const src = ev.source ?? {};
      const targetId = src.groupId ?? src.roomId ?? src.userId ?? '';

      /* บอทเพิ่งถูกเชิญเข้ากลุ่ม — บอก id ทันทีโดยไม่ต้องให้ใครพิมพ์อะไร
         เพราะ id นี้คือสิ่งเดียวที่ต้องเอาไปใส่ในตาราง line_targets
         และหาจากที่อื่นไม่ได้เลย */
      if (ev.type === 'join' || ev.type === 'follow') {
        await reply(ev.replyToken,
          'สวัสดีครับ 👋 บอทแจ้งข้อมูลจุดเสี่ยงอุบัติเหตุ สภ.เมืองนครสวรรค์\n\n' +
          'ID สำหรับตั้งค่าการแจ้งเตือน:\n' + targetId + '\n\n' +
          'พิมพ์ "เมนู" เพื่อดูคำสั่งที่ใช้ได้');
        continue;
      }

      if (ev.type !== 'message' || ev.message?.type !== 'text') continue;

      const answer = await askDatabase(ev.message.text);
      if (!answer) continue;                      // ไม่เข้าคีย์เวิร์ด — เงียบไว้

      // id เป็นคำสั่งเดียวที่ฐานข้อมูลตอบเองไม่ได้ เพราะ id มากับตัว event
      if (answer.action === 'id') {
        await reply(ev.replyToken, 'ID ของห้องนี้:\n' + targetId);
        continue;
      }
      if (answer.text) await reply(ev.replyToken, answer.text);
    } catch (e) {
      // พังทีละ event ต้องไม่ทำให้ทั้งชุดพัง และต้องตอบ 200 เสมอ
      // ไม่งั้น LINE จะส่งซ้ำ แล้วคนในกลุ่มจะได้ข้อความเดิมหลายรอบ
      console.error('event error', e);
    }
  }

  return new Response('ok');
};

export default { fetch: withSupabase({ auth: 'none' }, handler) };
