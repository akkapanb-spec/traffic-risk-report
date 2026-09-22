/* ตัววาดภาพการ์ดสำหรับโพสต์เฟซบุ๊ก
   ============================================================
   คืนภาพ PNG หนึ่งใบต่อการเรียกหนึ่งครั้ง  เฟซบุ๊กจะมาดึงภาพจากลิงก์นี้เอง
   จึงต้องเปิดให้เรียกได้โดยไม่ต้องล็อกอิน เหมือนฟังก์ชัน drive

     /fbcard?kind=death&id=123     การ์ดอุบัติเหตุเสียชีวิต หนึ่งราย
     /fbcard?kind=weekly&days=7    การ์ดสรุปรายสัปดาห์

   ภาพพื้นหลังกับพิกัดช่องอยู่ในคลังโค้ดบน GitHub ไม่ได้ฝังมากับฟังก์ชัน
   เพราะภาพทั้งชุด 14 MB ใหญ่เกินกว่าจะรวมมาในฟังก์ชัน และแก้ภาพทีหลังได้โดยไม่ต้อง deploy ใหม่

   deploy: Supabase Dashboard -> Edge Functions -> fbcard -> Code -> Deploy updates
           และต้องปิด Verify JWT with legacy secret ในแท็บ Settings ทุกครั้งหลัง deploy
           ตัวแก้ไขในหน้าเว็บเก็บสำเนาของมันเอง การแก้ไฟล์ในเครื่องแล้วกด Deploy updates
           จะได้เลขรุ่นใหม่แต่โค้ดเดิม ต้องวางโค้ดลงในตัวแก้ไขก่อนทุกครั้ง

   เรื่องที่ต้องระวังสามข้อ
     หนึ่ง  resvg วาดรูปจากลิงก์ภายนอกไม่ได้ ต้องอ่านภาพมาแปลงเป็นข้อมูลฝังในเอกสารก่อน
     สอง   resvg ไม่มีฟอนต์ติดมา ต้องส่งไฟล์ฟอนต์ไทยเข้าไปเอง ไม่งั้นได้ภาพที่ตัวหนังสือหายทั้งใบ
     สาม   resvg วัดความกว้างข้อความให้ไม่ได้ จึงต้องวัดเองจากตารางความกว้างรายตัวอักษร
           ที่ sarabun-widths.json แล้วย่อขนาดตัวอักษรลงถ้าจะล้นช่อง
*/

import { withSupabase } from "npm:@supabase/server@^1";
import { Resvg, initWasm } from "https://esm.sh/@resvg/resvg-wasm@2.6.2";

const REPO = "https://raw.githubusercontent.com/akkapanb-spec/traffic-risk-report/main";
const SB_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SB_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

/* โหลดครั้งเดียวต่ออายุของอินสแตนซ์ แล้วใช้ซ้ำ  การเรียกครั้งแรกจึงช้ากว่าครั้งถัดไป */
let wasmReady: Promise<void> | null = null;
const cache = new Map<string, Uint8Array>();
let fonts: Uint8Array[] | null = null;

async function bytes(url: string): Promise<Uint8Array> {
  const hit = cache.get(url);
  if (hit) return hit;
  const r = await fetch(url);
  if (!r.ok) throw new Error("โหลดไม่ได้ " + url + " " + r.status);
  const b = new Uint8Array(await r.arrayBuffer());
  cache.set(url, b);
  return b;
}

async function json<T>(url: string): Promise<T> {
  return JSON.parse(new TextDecoder().decode(await bytes(url))) as T;
}

function b64(u8: Uint8Array): string {
  let s = "";
  const chunk = 0x8000;
  for (let i = 0; i < u8.length; i += chunk) {
    s += String.fromCharCode.apply(null, Array.from(u8.subarray(i, i + chunk)) as unknown as number[]);
  }
  return btoa(s);
}

async function loadFonts(): Promise<Uint8Array[]> {
  if (fonts) return fonts;
  fonts = await Promise.all([
    bytes(REPO + "/assets/fbcard/fonts/Sarabun-Regular.ttf"),
    bytes(REPO + "/assets/fbcard/fonts/Sarabun-SemiBold.ttf"),
    bytes(REPO + "/assets/fbcard/fonts/Sarabun-Bold.ttf"),
  ]);
  return fonts;
}

/* ความกว้างของข้อความ  อ่านจากตารางที่วัดมาจากไฟล์ฟอนต์จริง ตัวต่อตัว
   เคยใช้วิธีนับจำนวนตัวอักษรคูณค่าคงที่ แล้วบรรทัดสถานที่ล้นกล่องออกไปนอกภาพ
   สระกับวรรณยุกต์ในตารางเป็นศูนย์ เพราะไม่กินความกว้างในบรรทัด */
type WidthTable = Record<string, Record<string, number>>;
let widths: WidthTable | null = null;

async function loadWidths(): Promise<WidthTable> {
  if (!widths) widths = await json<WidthTable>(REPO + "/assets/fbcard/fonts/sarabun-widths.json");
  return widths;
}

function textWidth(s: string, size: number, weight: number): number {
  const t = (widths && (widths[String(weight)] ?? widths["600"])) ?? null;
  if (!t) return s.length * size * 0.52;
  let em = 0;
  for (const ch of s) em += t[String(ch.codePointAt(0))] ?? 500;
  return em * size / 1000;
}

function esc(s: string): string {
  return String(s ?? "")
    .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;").replace(/'/g, "&apos;");
}

function textTag(s: string, x: number, y: number, size: number, opt: {
  fill?: string; weight?: number; anchor?: string; maxWidth?: number;
} = {}): string {
  if (!s) return "";
  let fs = size;
  const weight = opt.weight ?? 600;
  if (opt.maxWidth) {
    const w = textWidth(s, fs, weight);
    if (w > opt.maxWidth) fs = Math.max(size * 0.6, fs * (opt.maxWidth / w));
  }
  return '<text x="' + x + '" y="' + y + '" font-family="Sarabun" font-size="' + fs.toFixed(1) +
    '" font-weight="' + weight + '" fill="' + (opt.fill ?? "#FFFFFF") + '"' +
    (opt.anchor ? ' text-anchor="' + opt.anchor + '"' : "") + ">" + esc(s) + "</text>";
}

async function rpc(fn: string, args: Record<string, unknown>): Promise<unknown> {
  const r = await fetch(SB_URL + "/rest/v1/rpc/" + fn, {
    method: "POST",
    headers: { apikey: SB_KEY, Authorization: "Bearer " + SB_KEY, "Content-Type": "application/json" },
    body: JSON.stringify(args),
  });
  if (!r.ok) throw new Error(fn + " " + r.status + " " + (await r.text()).slice(0, 200));
  return await r.json();
}

async function table(path: string): Promise<unknown[]> {
  const r = await fetch(SB_URL + "/rest/v1/" + path, {
    headers: { apikey: SB_KEY, Authorization: "Bearer " + SB_KEY },
  });
  if (!r.ok) throw new Error(path + " " + r.status);
  return await r.json();
}

/* ---------- การ์ดอุบัติเหตุเสียชีวิต ---------- */

type Layout = {
  source: [number, number];
  templates: Record<string, [number, number, number, number]>;
  boxRight: Record<string, number>;
  /* ช่องระบายทับมีทั้งสี่เหลี่ยมของแต่ละภาพ และคีย์ fill ที่เป็นสี */
  cover: Record<string, any>;
};

async function deathCard(id: number): Promise<Uint8Array> {
  await loadWidths();
  const rows = await table("deaths?id=eq." + id + "&select=*") as Record<string, any>[];
  if (!rows.length) throw new Error("ไม่พบผู้เสียชีวิตรหัส " + id);
  const d = rows[0];

  const pairs = await json<{
    fromForm: Record<string, string>;
    noCounterpart: string[];
    types: { code: string; label: string }[];
  }>(
    REPO + "/assets/fbcard/death/pairs.json");
  const lay = await json<Layout>(REPO + "/assets/fbcard/death/layout.json");

  const order = ["moto", "car", "pickup", "truck6", "truck10", "trailer", "walk", "other"];
  const codeOf = (v: string): string => {
    const t = (v ?? "").trim();
    if (!t) return "other";
    if (pairs.fromForm[t]) return pairs.fromForm[t];
    if (t.indexOf("เดินเท้า") >= 0) return "walk";
    if (t.indexOf("จักรยานยนต์") >= 0) return "moto";
    if (t.indexOf("กระบะ") >= 0) return "pickup";
    if (t.indexOf("พ่วง") >= 0 || t.indexOf("เทรล") >= 0 || t.indexOf("เทรน") >= 0) return "trailer";
    if (t.indexOf("10 ล้อ") >= 0) return "truck10";
    if (t.indexOf("บรรทุก") >= 0) return "truck6";
    if (t.indexOf("เก๋ง") >= 0) return "car";
    return "other";
  };

  /* ผู้เสียชีวิตเป็นคนเดินเท้า ดูจากบทบาทหรือช่องใบอนุญาต ไม่ได้ดูจากประเภทรถ
     เพราะแถวคนเดินเท้าไม่ได้กรอกประเภทรถไว้ */
  const role = String(d.status ?? "");
  const lic = String(d.license ?? "");
  const ped = role.indexOf("เดินเท้า") >= 0 || lic.indexOf("เดินเท้า") >= 0;

  const cpRaw = String(d.counterpart_vehicle ?? "").trim();
  const noCp = !cpRaw || pairs.noCounterpart.indexOf(cpRaw) >= 0;

  const mine = ped ? "walk" : codeOf(String(d.vehicle_type ?? ""));
  /* ยังไม่มีแบบการ์ดสำหรับเหตุที่ไม่มีคู่กรณี เช่น ชนเสาไฟหรือตกถนน
     จึงใช้แบบรถลักษณะอื่นไปก่อน แล้วเขียนในกล่องตามจริงว่าไม่มีคู่กรณี
     ภาพจะมีรูปรถคันที่สองซึ่งไม่ตรงกับเหตุ แต่ข้อความในกล่องบอกความจริงไว้
     เมื่อได้ภาพชุดไม่มีคู่กรณีมาแล้วให้เปลี่ยนตรงนี้ */
  const other = noCp ? "other" : codeOf(cpRaw);
  const pairKey = [mine, other].sort((a, b) => order.indexOf(a) - order.indexOf(b)).join("-");
  const geom = lay.templates[pairKey] ?? lay.templates["other-other"];
  const [firstY, pitch, valueX, fontSize] = geom;
  /* ขอบขวาของกล่องวัดมาทีละภาพ ไม่ได้คิดจากความกว้างของภาพ
     เพราะบางแบบกล่องแคบกว่ามาก มีแผงรูปรถอยู่ทางขวา */
  const boxRight = Number(lay.boxRight?.[pairKey] ?? 883);

  const bg = await bytes(REPO + "/assets/fbcard/death/" + pairKey + ".jpg");
  const [W, H] = lay.source;

  /* เวลาเป็นพุทธศักราชโดยอัตโนมัติ เพราะ th-TH ใช้ปฏิทินพุทธเป็นค่าตั้งต้น */
  const when = d.incident_datetime
    ? new Date(String(d.incident_datetime)).toLocaleString("th-TH", {
        timeZone: "Asia/Bangkok", day: "numeric", month: "short", year: "numeric",
        hour: "2-digit", minute: "2-digit",
      }) + " น."
    : "";
  const place = [d.road_name, d.subdistrict ? "ต." + d.subdistrict : ""]
    .filter(Boolean).join("  ");
  const who = [d.gender, d.age ? "อายุ " + d.age + " ปี" : "", role]
    .filter(Boolean).join("  ");
  /* ทะเบียนผู้เสียชีวิตแยกสองช่อง อวัยวะที่บาดเจ็บกับอาการ
     col_h กับ col_g ไม่ได้ตั้งชื่อคอลัมน์ไว้ตอนนำเข้าจากระบบเดิม */
  const hurt = [d.col_h, d.col_g].map((v) => String(v ?? "").trim())
    .filter(Boolean).join("  ");

  const values = [
    when,
    place,
    noCp ? "ไม่มีคู่กรณี" : cpRaw,
    String(d.cause ?? ""),
    who,
    hurt,
    ped ? "ไม่มี" : String(d.safety_equipment ?? ""),
    lic,
  ];

  const cv = lay.cover[pairKey];
  let svg = '<svg xmlns="http://www.w3.org/2000/svg" width="' + W + '" height="' + H + '" viewBox="0 0 ' + W + ' ' + H + '">' +
    '<image x="0" y="0" width="' + W + '" height="' + H + '" href="data:image/jpeg;base64,' + b64(bg) + '"/>';
  if (Array.isArray(cv)) {
    svg += '<rect x="' + cv[0] + '" y="' + cv[1] + '" width="' + cv[2] +
      '" height="' + cv[3] + '" fill="' + (lay.cover.fill ?? "#08101B") + '"/>';
  }
  values.forEach((v, i) => {
    svg += textTag(v || "ไม่ระบุ", valueX, firstY + i * pitch + fontSize * 0.36, fontSize, {
      weight: 600, maxWidth: boxRight - valueX - 24,
    });
  });
  svg += "</svg>";
  return await render(svg, W);
}

/* ---------- การ์ดสรุปรายสัปดาห์ ---------- */

type Weekly = {
  size: [number, number];
  slots: {
    dateRange: { x: number; baseline: number; size: number; maxWidth: number; color: string };
    counts: Record<string, any>;
    roads: { plates: number[][]; barArea: number[][]; bar: { maxWidth: number; color: string; countColor: string; countGap: number } };
    cause: { box: number[] };
  };
};

async function weeklyCard(days: number): Promise<Uint8Array> {
  await loadWidths();
  const lay = await json<Weekly>(REPO + "/assets/fbcard/weekly/layout.json");
  const bg = await bytes(REPO + "/assets/fbcard/weekly/blank.jpg");
  const data = await rpc("fb_weekly_data", { p_days: days }) as {
    range: string; accidents: number; deaths: number; injuries: number; serious: number;
    roads: { name: string; n: number }[]; cause: string;
  };
  const [W, H] = lay.size;
  const s = lay.slots;
  const mid = (b: number[]) => [b[0] + b[2] / 2, b[1] + b[3] / 2];

  let svg = '<svg xmlns="http://www.w3.org/2000/svg" width="' + W + '" height="' + H + '" viewBox="0 0 ' + W + ' ' + H + '">' +
    '<image x="0" y="0" width="' + W + '" height="' + H + '" href="data:image/jpeg;base64,' + b64(bg) + '"/>';

  svg += textTag(data.range, s.dateRange.x, s.dateRange.baseline, s.dateRange.size,
    { weight: 600, fill: s.dateRange.color, maxWidth: s.dateRange.maxWidth });

  const num = (key: string, v: number) => {
    const c = s.counts[key];
    const [cx, cy] = mid(c.box);
    return textTag(String(v), cx, cy + c.box[3] * 0.34, c.box[3] * 0.95,
      { weight: 700, fill: c.color, anchor: "middle", maxWidth: c.box[2] });
  };
  svg += num("accidents", data.accidents) + num("deaths", data.deaths) + num("injuries", data.injuries);
  svg += textTag(String(data.serious), s.counts.serious.x, s.counts.serious.baseline,
    s.counts.serious.size, { weight: 700, fill: s.counts.serious.color });

  const top = Math.max(1, data.roads.length ? data.roads[0].n : 1);
  for (let i = 0; i < 3; i++) {
    const plate = s.roads.plates[i], area = s.roads.barArea[i];
    const r = data.roads[i];
    const [px, py] = mid(plate);
    if (!r) {
      svg += textTag("–", px, py + plate[3] * 0.32, plate[3] * 0.6, { weight: 700, anchor: "middle" });
      continue;
    }
    svg += textTag(r.name, px, py + plate[3] * 0.3, plate[3] * 0.62,
      { weight: 700, anchor: "middle", maxWidth: plate[2] - 24 });
    const bw = Math.max(40, Math.round(s.roads.bar.maxWidth * (r.n / top)));
    svg += '<rect x="' + area[0] + '" y="' + area[1] + '" width="' + bw + '" height="' + area[3] +
      '" rx="8" fill="' + s.roads.bar.color + '"/>';
    svg += textTag(r.n + " ครั้ง", area[0] + bw + s.roads.bar.countGap, area[1] + area[3] * 0.78,
      area[3] * 0.72, { weight: 700, fill: s.roads.bar.countColor });
  }

  svg += textTag(data.cause || "–", s.cause.box[0], s.cause.box[1] + s.cause.box[3] * 0.72,
    s.cause.box[3] * 0.62, { weight: 700, fill: "#FFFFFF", maxWidth: s.cause.box[2] });
  svg += "</svg>";
  return await render(svg, W);
}

async function render(svg: string, width: number): Promise<Uint8Array> {
  if (!wasmReady) {
    wasmReady = (async () => {
      await initWasm(await (await fetch("https://esm.sh/@resvg/resvg-wasm@2.6.2/index_bg.wasm")).arrayBuffer());
    })();
  }
  await wasmReady;
  const r = new Resvg(svg, {
    fitTo: { mode: "width", value: width },
    font: { fontBuffers: await loadFonts(), defaultFontFamily: "Sarabun", loadSystemFonts: false },
  });
  return r.render().asPng();
}

/* เฟซบุ๊กมาดึงภาพเอง ไม่มีโทเคนติดมาด้วย จึงต้องเปิดให้เรียกได้โดยไม่ต้องล็อกอิน
   ตัวจัดการแบบ Deno.serve เปล่า ๆ จะถูกปฏิเสธตั้งแต่ยังไม่ได้ทำงาน
   ต้องห่อด้วย withSupabase auth none เหมือนฟังก์ชัน drive
   และต้องปิด Verify JWT with legacy secret ในแท็บ Settings ทุกครั้งหลัง deploy */

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type",
};

const handler = async (req: Request): Promise<Response> => {
  const u = new URL(req.url);
  const kind = u.searchParams.get("kind") ?? "";

  /* ไม่ได้บอกอะไร แค่บอกว่าฟังก์ชันตื่นอยู่ ใช้ตรวจว่า deploy ติดไหม */
  if (kind === "") {
    return new Response(
      JSON.stringify({ พร้อมวาดภาพ: true, ใช้ได้: ["death", "weekly"] }, null, 2),
      { headers: { ...CORS, "Content-Type": "application/json; charset=utf-8" } });
  }

  try {
    let png: Uint8Array;
    if (kind === "death") {
      const id = Number(u.searchParams.get("id") ?? 0);
      if (!id) throw new Error("ต้องมี id");
      png = await deathCard(id);
    } else if (kind === "weekly") {
      png = await weeklyCard(Number(u.searchParams.get("days") ?? 7));
    } else {
      return new Response("ใช้ได้เฉพาะ kind=death หรือ kind=weekly", { status: 400, headers: CORS });
    }
    return new Response(png, {
      headers: {
        ...CORS,
        "content-type": "image/png",
        /* เฟซบุ๊กดึงภาพครั้งเดียวแล้วเก็บสำเนาของตัวเอง
           เก็บแคชสั้น ๆ พอกันการดึงซ้ำถี่ ๆ ตอนกำลังตรวจงาน */
        "cache-control": "public, max-age=600",
      },
    });
  } catch (e) {
    return new Response("วาดภาพไม่สำเร็จ  " + (e instanceof Error ? e.message : String(e)),
      { status: 500, headers: CORS });
  }
};

export default { fetch: withSupabase({ auth: "none" }, handler) };
