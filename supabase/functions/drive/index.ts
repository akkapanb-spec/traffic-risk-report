// ============================================================
// ตัวกลางคุยกับ Google Drive — หน้ารวมคลิป videos.html
// ============================================================
// มีไว้อย่างเดียว คือไม่ให้กุญแจ Google API โผล่อยู่ในหน้าเว็บ
//
// ของเดิมฝังกุญแจไว้ในไฟล์ videos.html ตรง ๆ
// ซึ่งอยู่ในที่เก็บโค้ดสาธารณะและอยู่ในหน้าเว็บที่ใครก็กด View Source ดูได้
// ใครหยิบไปใช้ก็กินโควตาของเราได้ทันที และเปลี่ยนกุญแจทีต้องแก้โค้ดแล้ว deploy ใหม่
//
// ย้ายมาไว้ที่นี่แล้ว กุญแจอยู่ใน Secrets ของ Edge Functions
// เปลี่ยนกุญแจเมื่อไหร่แก้ที่เดียว ไม่ต้องแตะโค้ดและไม่ต้อง deploy หน้าเว็บใหม่
//
// deploy: Supabase Dashboard -> Edge Functions -> drive -> Code -> Deploy updates
//         และต้องปิด "Verify JWT with legacy secret" ในแท็บ Settings ทุกครั้งหลัง deploy
//
// ต้องตั้ง secret 1 ตัวใน Edge Functions -> Secrets
//   GOOGLE_API_KEY   กุญแจใหม่ที่เพิ่งสร้าง ไม่ใช่ตัวเดิมที่หลุดไปแล้ว
//
// สองเส้นทางที่รับ
//   ?list=1        คืนรายชื่อคลิปในโฟลเดอร์เป็น JSON
//   ?id=FILE_ID    ส่งตัวไฟล์วีดิโอต่อให้เบราว์เซอร์
// ============================================================

import { withSupabase } from 'npm:@supabase/server@^1';

const API_KEY = Deno.env.get('GOOGLE_API_KEY') ?? '';

/* รหัสโฟลเดอร์ไม่ใช่ความลับ อยู่ในหน้าเว็บอยู่แล้วและเป็นโฟลเดอร์สาธารณะ
   ตั้งเป็น secret ทับได้ถ้าวันหน้าย้ายโฟลเดอร์ โดยไม่ต้องแก้โค้ด */
const FOLDER_ID = Deno.env.get('DRIVE_FOLDER_ID') ?? '1EyT0dgnBzMWOgqEfiURrgVrKfCPq6GNd';

/* เปิดให้หน้าเว็บของเราเรียกได้ ตัวไฟล์ในโฟลเดอร์เป็นสาธารณะอยู่แล้ว
   ตัวกลางนี้จึงไม่ได้เปิดเผยอะไรที่คนทั่วไปเข้าไม่ถึง
   สิ่งที่มันปกป้องคือกุญแจ ไม่ใช่ตัวคลิป */
const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'range, content-type',
  'Access-Control-Expose-Headers': 'content-length, content-range, accept-ranges'
};

const handler = async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: CORS });

  if (!API_KEY) {
    return new Response(
      JSON.stringify({ error: 'ยังไม่ได้ตั้ง GOOGLE_API_KEY ใน Edge Functions Secrets' }),
      { status: 500, headers: { ...CORS, 'Content-Type': 'application/json; charset=utf-8' } }
    );
  }

  const url = new URL(req.url);

  // ---------- รายชื่อคลิป ----------
  if (url.searchParams.get('list') === '1') {
    const params = new URLSearchParams({
      q: "'" + FOLDER_ID + "' in parents and mimeType contains 'video/' and trashed=false",
      key: API_KEY,
      fields: 'files(id,name,createdTime,modifiedTime,thumbnailLink)',
      orderBy: 'name_natural',
      pageSize: '200',
      supportsAllDrives: 'true',
      includeItemsFromAllDrives: 'true'
    });

    const r = await fetch('https://www.googleapis.com/drive/v3/files?' + params.toString());
    const body = await r.text();

    /* ส่งรหัสสถานะจริงกลับไปด้วย ไม่กลบเป็น 200 เสมอ
       หน้าเว็บจะได้แยกออกว่ากุญแจผิด กับ โฟลเดอร์ว่าง ซึ่งแก้คนละวิธีกัน */
    return new Response(body, {
      status: r.status,
      headers: { ...CORS, 'Content-Type': 'application/json; charset=utf-8' }
    });
  }

  // ---------- ตัวไฟล์วีดิโอ ----------
  const id = url.searchParams.get('id');
  if (id) {
    /* ส่งหัวข้อ Range ต่อไปให้กูเกิลด้วย ไม่งั้นผู้ชมลากแถบเวลาไม่ได้
       เบราว์เซอร์ขอเป็นช่วง ๆ เสมอเวลาเล่นวีดิโอ ถ้าตัดทิ้งจะโหลดทั้งไฟล์ทุกครั้ง */
    const range = req.headers.get('range');
    const up = await fetch(
      'https://www.googleapis.com/drive/v3/files/' + encodeURIComponent(id) +
      '?alt=media&key=' + encodeURIComponent(API_KEY),
      { headers: range ? { Range: range } : {} }
    );

    /* ส่งสายข้อมูลต่อโดยไม่อ่านเก็บไว้ในหน่วยความจำก่อน
       ไฟล์วีดิโออาจใหญ่หลายสิบเมกะไบต์ ถ้าอ่านทั้งก้อนก่อนส่งจะกินหน่วยความจำจนล้ม */
    const h = new Headers(CORS);
    for (const k of ['content-type', 'content-length', 'content-range', 'accept-ranges']) {
      const v = up.headers.get(k);
      if (v) h.set(k, v);
    }
    h.set('Cache-Control', 'public, max-age=3600');

    return new Response(up.body, { status: up.status, headers: h });
  }

  // ---------- ตรวจสุขภาพ ----------
  // บอกแค่ว่าตั้งกุญแจไว้หรือยัง ไม่คืนค่าของกุญแจ
  return new Response(
    JSON.stringify({ ตั้งกุญแจแล้ว: !!API_KEY, โฟลเดอร์: FOLDER_ID }, null, 2),
    { headers: { ...CORS, 'Content-Type': 'application/json; charset=utf-8' } }
  );
};

export default { fetch: withSupabase({ auth: 'none' }, handler) };
