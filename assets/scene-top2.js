'use strict';
/* ============================================================
   ฉากชุดที่สอง  สำหรับคำถามที่ไม่ใช่สถานการณ์บนถนนโดยตรง
   ============================================================
   ไฟล์นี้ต่อจาก assets/scene-top.js และใช้ตัวช่วยวาดทั้งหมดจากไฟล์นั้น
   จึงต้องโหลด scene-top.js ก่อนเสมอ ถ้าโหลดสลับกันจะโยนข้อผิดพลาดทันที

   ============================================================
   คำถามที่ถามข้อมูลในเว็บแอป ให้แสดงหน้าเว็บแอป
   ============================================================
   คำถามกลุ่มสถิติถามตัวเลขที่อยู่ในเว็บแอปของ สภ.เมืองนครสวรรค์ เอง
   ภาพประกอบจึงควรเป็นหน้าจอของเว็บแอปนั้น ไม่ใช่ภาพถนนที่ไม่เกี่ยวอะไรเลย
   ผู้เล่นจะได้รู้ด้วยว่าตัวเลขพวกนี้เปิดดูเองได้ที่ไหน ซึ่งเป็นเป้าหมายของเกมอยู่แล้ว

   ============================================================
   กติกาข้อใหญ่ที่สุด  ภาพห้ามเฉลยคำตอบ
   ============================================================
   หน้าจอที่วาดจึงต้องปิดการ์ดใบที่เป็นคำตอบไว้เสมอ
   ปิดด้วยแถบทึบมีเครื่องหมายคำถาม ไม่ใช่ทำให้จาง เพราะของที่จางยังอ่านออกถ้าเพ่ง
   ส่วนอื่นของหน้าจอแสดงได้ตามปกติ เพื่อให้ยังดูออกว่าเป็นหน้าไหนของแอป

   ตัวเลขที่โผล่ในการ์ดใบอื่น ต้องไม่ใช่ตัวเลขจริงที่ใช้ตอบข้อไหนได้
   จึงวาดเป็นแท่งกับแถบเปล่า ไม่ใส่ตัวเลขลงไปเลยแม้แต่ใบเดียว

   ใครจะแก้ไฟล์นี้ ให้ลองดูภาพแล้วตอบคำถามข้อนั้นดู
   ถ้าตอบได้จากภาพ แปลว่าวาดผิดวัตถุประสงค์ ต้องปิดเพิ่ม
   ============================================================ */

/* ------------------------------------------------------------
   ตัวเครื่องกับหน้าจอเว็บแอป
   ------------------------------------------------------------
   เว็บแอปตัวจริงเปิดบนมือถือเป็นหลัก จึงวาดเป็นมือถือ
   มีเงาทอดไปทางขวาล่างเหมือนของทุกชิ้นในภาษาภาพชุดนี้ */
var TD_APP = { x: 112, y: 8, w: 176, h: 244 };

function tdPhone(p) {
  var a = TD_APP;
  return '<g>' +
    '<rect x="' + (a.x + 6) + '" y="' + (a.y + 9) + '" width="' + a.w + '" height="' + a.h + '" rx="20" fill="rgba(0,0,0,.34)"/>' +
    '<rect x="' + a.x + '" y="' + a.y + '" width="' + a.w + '" height="' + a.h + '" rx="20" fill="#11161d"/>' +
    '<rect x="' + a.x + '" y="' + a.y + '" width="' + a.w + '" height="' + (a.h * 0.22) + '" rx="20" fill="rgba(255,255,255,.06)"/>' +
    '<rect x="' + (a.x + 7) + '" y="' + (a.y + 7) + '" width="' + (a.w - 14) + '" height="' + (a.h - 14) + '" rx="13" fill="#eef2f7"/>' +
    '</g>';
}

/* แถบหัวเรื่องสีของหน่วยงาน กับแถวแท็บใต้หัวเรื่อง
   วาดเป็นแถบเปล่า ไม่ใส่ตัวหนังสือ เพราะตัวหนังสือเล็กขนาดนี้อ่านไม่ออกอยู่ดี
   และถ้าใส่ชื่อหัวข้อจริงลงไป บางข้อจะกลายเป็นใบ้คำตอบ */
function tdAppChrome(tab) {
  var a = TD_APP, ix = a.x + 7, iw = a.w - 14, out = '';
  out += '<path d="M' + ix + ' ' + (a.y + 20) + ' a13 13 0 0 1 13 -13 h' + (iw - 26) +
    ' a13 13 0 0 1 13 13 v24 h' + (-iw) + ' Z" fill="#1d3a6b"/>';
  out += '<circle cx="' + (ix + 16) + '" cy="' + (a.y + 26) + '" r="7.5" fill="#dfe7f0"/>';
  out += '<rect x="' + (ix + 29) + '" y="' + (a.y + 20) + '" width="66" height="5" rx="2.5" fill="rgba(255,255,255,.9)"/>';
  out += '<rect x="' + (ix + 29) + '" y="' + (a.y + 29) + '" width="44" height="4" rx="2" fill="rgba(255,255,255,.55)"/>';
  for (var i = 0; i < 3; i++) {
    out += '<rect x="' + (ix + 8 + i * 48) + '" y="' + (a.y + 52) + '" width="42" height="12" rx="6" fill="' +
      (i === tab ? '#1d4ed8' : '#d3dde9') + '"/>';
  }
  return out;
}

/* กรอบการ์ดหนึ่งใบในหน้าจอ  ช่องที่ n นับจากศูนย์ */
function tdAppCardBox(n) {
  var a = TD_APP;
  return { x: a.x + 15, y: a.y + 74 + n * 58, w: a.w - 30, h: 50 };
}

/* เนื้อในการ์ด  แต่ละแบบต่างกันพอให้สิบข้อไม่กลายเป็นภาพเดียวกัน
   bars แท่ง  donut วงกลม  list รายการ  map แผนที่ */
function tdAppCard(kind, n, seed) {
  var b = tdAppCardBox(n), out = '', i;
  out += '<rect x="' + b.x + '" y="' + b.y + '" width="' + b.w + '" height="' + b.h + '" rx="8" fill="#ffffff"/>';
  out += '<rect x="' + b.x + '" y="' + b.y + '" width="' + b.w + '" height="' + b.h + '" rx="8" fill="none" stroke="#dbe4ef" stroke-width="1.4"/>';
  out += '<rect x="' + (b.x + 8) + '" y="' + (b.y + 7) + '" width="' + (b.w * 0.5) + '" height="4.5" rx="2.2" fill="#9fb0c2"/>';
  if (kind === 'bars') {
    for (i = 0; i < 5; i++) {
      var hgt = 8 + ((seed + i * 7) % 5) * 4.5;
      out += '<rect x="' + (b.x + 10 + i * 21) + '" y="' + (b.y + b.h - 8 - hgt) + '" width="13" height="' + hgt +
        '" rx="2.5" fill="#4f7fd0"/>';
    }
  } else if (kind === 'donut') {
    out += '<circle cx="' + (b.x + 26) + '" cy="' + (b.y + 30) + '" r="13" fill="none" stroke="#dbe4ef" stroke-width="7"/>';
    out += '<path d="M' + (b.x + 26) + ' ' + (b.y + 17) + ' a13 13 0 0 1 11 20" fill="none" stroke="#4f7fd0" stroke-width="7" stroke-linecap="round"/>';
    for (i = 0; i < 3; i++) {
      out += '<rect x="' + (b.x + 50) + '" y="' + (b.y + 20 + i * 9) + '" width="' + (54 - i * 13) + '" height="4.5" rx="2.2" fill="#c3d0e0"/>';
    }
  } else if (kind === 'list') {
    for (i = 0; i < 3; i++) {
      out += '<rect x="' + (b.x + 9) + '" y="' + (b.y + 19 + i * 10) + '" width="' + (86 - i * 18) + '" height="5" rx="2.5" fill="#c3d0e0"/>';
      out += '<rect x="' + (b.x + b.w - 26) + '" y="' + (b.y + 19 + i * 10) + '" width="17" height="5" rx="2.5" fill="#4f7fd0"/>';
    }
  } else if (kind === 'map') {
    out += '<rect x="' + (b.x + 8) + '" y="' + (b.y + 16) + '" width="' + (b.w - 16) + '" height="' + (b.h - 24) + '" rx="5" fill="#2c3a46"/>';
    out += '<g stroke="#4d6070" stroke-width="4" stroke-linecap="round">' +
      '<line x1="' + (b.x + 8) + '" y1="' + (b.y + 32) + '" x2="' + (b.x + b.w - 8) + '" y2="' + (b.y + 32) + '"/>' +
      '<line x1="' + (b.x + 52) + '" y1="' + (b.y + 16) + '" x2="' + (b.x + 52) + '" y2="' + (b.y + b.h - 8) + '"/></g>';
    for (i = 0; i < 3; i++) {
      out += '<circle cx="' + (b.x + 30 + i * 36) + '" cy="' + (b.y + 26 + (i % 2) * 12) + '" r="4.2" fill="#d0342c"/>';
    }
  }
  return out;
}

/* ปิดการ์ดใบที่เป็นคำตอบ
   ทึบจริง ไม่ใช่ทำให้จาง เพราะของที่จางยังอ่านออกถ้าซูมเข้าไปดู
   แถบทแยงบอกว่าตั้งใจปิด ไม่ใช่หน้าจอโหลดไม่ขึ้น */
function tdAppMask(n) {
  var b = tdAppCardBox(n), out = '', i;
  out += '<clipPath id="tdMaskClip' + n + '"><rect x="' + b.x + '" y="' + b.y + '" width="' + b.w +
    '" height="' + b.h + '" rx="8"/></clipPath>';
  out += '<rect x="' + b.x + '" y="' + b.y + '" width="' + b.w + '" height="' + b.h + '" rx="8" fill="#33415a"/>';
  out += '<g clip-path="url(#tdMaskClip' + n + ')" stroke="#48597a" stroke-width="6" opacity=".9">';
  for (i = -3; i < 12; i++) {
    out += '<line x1="' + (b.x + i * 14) + '" y1="' + b.y + '" x2="' + (b.x + i * 14 + b.h) + '" y2="' + (b.y + b.h) + '"/>';
  }
  out += '</g>';
  out += '<rect x="' + b.x + '" y="' + b.y + '" width="' + b.w + '" height="' + b.h +
    '" rx="8" fill="none" stroke="#ffd166" stroke-width="2.4"/>';
  out += '<g transform="translate(' + (b.x + b.w / 2) + ',' + (b.y + b.h / 2) + ')">' +
    '<circle r="15" fill="#ffd166"/>' +
    '<text y="7" text-anchor="middle" font-family="system-ui,sans-serif" font-size="21" font-weight="700" fill="#1b2430">?</text>' +
    '<animate attributeName="opacity" values="1;.55;1" dur="2s" repeatCount="indefinite"/></g>';
  return out;
}

/* ประกอบหน้าจอทั้งหน้า  mask คือหมายเลขการ์ดที่ต้องปิด
   kinds คือชนิดของการ์ดทั้งสามใบ เรียงจากบนลงล่าง */
function tdAppScreen(p, tab, kinds, mask, seed) {
  var out = tdPhone() + tdAppChrome(tab), i;
  for (i = 0; i < 3; i++) {
    out += (i === mask) ? tdAppMask(i) : tdAppCard(kinds[i], i, seed + i * 3);
  }
  return out;
}

/* ป้ายชี้ว่าภาพนี้คือหน้าจอของเว็บแอป ไม่ใช่ภาพถ่ายสถานที่
   วางไว้นอกตัวเครื่อง จึงไม่บังเนื้อหาในจอ */
function tdAppHint(p) {
  /* ป้ายบอกว่าภาพนี้คือหน้าจอเว็บแอปของ สภ.เมืองนครสวรรค์ ไม่ใช่ภาพถ่ายสถานที่
     ต้องมีตัวหนังสือจริง ไม่ใช่แถบเปล่า เพราะแถบเปล่าไม่ได้บอกอะไรกับใครเลย
     วางไว้นอกตัวเครื่อง จึงไม่บังเนื้อหาในจอ */
  return '<g>' +
    '<rect x="10" y="104" width="92" height="52" rx="10" fill="rgba(0,0,0,.3)" transform="translate(4,5)"/>' +
    '<rect x="10" y="104" width="92" height="52" rx="10" fill="#1d3a6b"/>' +
    '<rect x="10" y="104" width="92" height="16" rx="10" fill="rgba(255,255,255,.1)"/>' +
    '<text x="56" y="126" text-anchor="middle" font-family="system-ui,sans-serif" font-size="13" ' +
    'font-weight="700" fill="#ffffff">เว็บแอป</text>' +
    '<text x="56" y="144" text-anchor="middle" font-family="system-ui,sans-serif" font-size="11" ' +
    'fill="rgba(255,255,255,.8)">จุดเสี่ยง</text>' +
    '<path d="M104 130 L124 130 M117 124 l7 6 -7 6" fill="none" stroke="#ffd166" stroke-width="3" ' +
    'stroke-linecap="round" stroke-linejoin="round"/></g>';
}

/* ------------------------------------------------------------
   ตัวช่วยสำหรับฉากที่เหตุการณ์เกิดในรถ
   ------------------------------------------------------------ */
function tdPanel(p, x, y, w, h) {
  return '<g>' +
    '<rect x="' + (x + 5) + '" y="' + (y + 7) + '" width="' + w + '" height="' + h + '" rx="14" fill="rgba(0,0,0,.3)"/>' +
    '<rect x="' + x + '" y="' + y + '" width="' + w + '" height="' + h + '" rx="14" fill="' + p.road + '"/>' +
    '<rect x="' + x + '" y="' + y + '" width="' + w + '" height="' + (h * 0.3) + '" rx="14" fill="rgba(255,255,255,.07)"/>' +
    '<rect x="' + x + '" y="' + y + '" width="' + w + '" height="' + h + '" rx="14" fill="none" ' +
    'stroke="' + p.kerb + '" stroke-width="2.5" opacity=".55"/></g>';
}

/* หัวคนมองจากด้านบน  helm ว่างคือไม่ได้สวมหมวก */
function tdHead(x, y, s, helm) {
  s = s || 1;
  return '<g transform="translate(' + x + ',' + y + ') scale(' + s + ')">' +
    '<ellipse cx="3" cy="4" rx="13" ry="7" fill="rgba(0,0,0,.3)"/>' +
    (helm
      ? '<circle r="13" fill="' + helm + '"/><path d="M-13 3a13 13 0 0 0 26 0z" fill="' + tdShade(helm, .72) + '"/>' +
        '<rect x="5" y="-5" width="7" height="10" rx="3" fill="rgba(255,255,255,.8)"/>'
      : '<circle r="12" fill="#d9a06a"/><path d="M-12 -4a12 12 0 0 1 24 0z" fill="#2f2a26"/>') +
    '</g>';
}

function tdCard(x, y, w, h, col, a) {
  return '<g transform="translate(' + x + ',' + y + ') rotate(' + (a || 0) + ')">' +
    '<rect x="' + (-w / 2 + 3) + '" y="' + (-h / 2 + 4) + '" width="' + w + '" height="' + h + '" rx="4" fill="rgba(0,0,0,.3)"/>' +
    '<rect x="' + (-w / 2) + '" y="' + (-h / 2) + '" width="' + w + '" height="' + h + '" rx="4" fill="' + col + '"/>' +
    '<rect x="' + (-w / 2 + 5) + '" y="' + (-h / 2 + 5) + '" width="' + (h - 10) + '" height="' + (h - 10) + '" rx="3" fill="rgba(0,0,0,.22)"/>' +
    '<rect x="' + (-w / 2 + h - 2) + '" y="' + (-h / 2 + 7) + '" width="' + (w - h - 6) + '" height="3.4" rx="1.7" fill="rgba(0,0,0,.22)"/>' +
    '<rect x="' + (-w / 2 + h - 2) + '" y="' + (-h / 2 + 15) + '" width="' + (w - h - 14) + '" height="3.4" rx="1.7" fill="rgba(0,0,0,.22)"/>' +
    '</g>';
}

/* ห้องโดยสารมองจากด้านบน  เห็นที่นั่งครบ จึงชี้ได้ว่าคำถามพูดถึงคนที่นั่งตรงไหน
   รถหันหน้าไปทางขวาเหมือนรถทุกคันในไฟล์ชุดนี้ พวงมาลัยจึงอยู่ด้านขวาบน */
function tdCabin(p, x, y, w, h) {
  return '<g transform="translate(' + x + ',' + y + ')">' +
    '<rect x="' + (-w / 2 + 5) + '" y="' + (-h / 2 + 7) + '" width="' + w + '" height="' + h + '" rx="22" fill="rgba(0,0,0,.32)"/>' +
    '<rect x="' + (-w / 2) + '" y="' + (-h / 2) + '" width="' + w + '" height="' + h + '" rx="22" fill="#8fa0b5"/>' +
    '<rect x="' + (-w / 2 + 6) + '" y="' + (-h / 2 + 6) + '" width="' + (w - 12) + '" height="' + (h - 12) + '" rx="17" fill="#39424f"/>' +
    '<path d="M' + (w / 2 - 30) + ' ' + (-h / 2 + 12) + ' L' + (w / 2 - 10) + ' ' + (-h / 2 + 26) +
    ' L' + (w / 2 - 10) + ' ' + (h / 2 - 26) + ' L' + (w / 2 - 30) + ' ' + (h / 2 - 12) + ' Z" fill="rgba(226,240,255,.55)"/>' +
    '</g>';
}
function tdSeat(x, y, w, h) {
  return '<rect x="' + (x - w / 2) + '" y="' + (y - h / 2) + '" width="' + w + '" height="' + h +
    '" rx="7" fill="#59646f"/>' +
    '<rect x="' + (x - w / 2 + 3) + '" y="' + (y - h / 2 + 3) + '" width="' + (w - 6) + '" height="' + (h - 6) +
    '" rx="5" fill="#6d7885"/>';
}

/* ============================================================
   ฉากทั้งหมดของไฟล์นี้
   ============================================================ */
var TD_SCENES2 = {

  /* สิบข้อแรกคือคำถามที่ถามตัวเลขในเว็บแอป จึงแสดงหน้าจอเว็บแอป
     ต่างกันที่แท็บที่เปิดอยู่ ชนิดการ์ด และตำแหน่งการ์ดที่ถูกปิด
     สิบข้อจึงไม่ใช่ภาพเดียวกัน แม้จะเป็นหน้าจอแอปเดียวกัน */

  /* ผู้เสียชีวิตส่วนใหญ่ใช้ยานพาหนะประเภทใด  ปิดการ์ดแยกตามประเภทยานพาหนะ */
  stat_vehicle:   function (p) { return tdAppScreen(p, 1, ['list', 'donut', 'bars'], 1, 2) + tdAppHint(p); },

  /* สาเหตุที่ทำให้มีผู้เสียชีวิตมากที่สุด  ปิดการ์ดสาเหตุซึ่งเป็นรายการเรียงลำดับ */
  stat_cause:     function (p) { return tdAppScreen(p, 1, ['bars', 'list', 'donut'], 1, 5) + tdAppHint(p); },

  /* ช่วงเวลาที่เหตุหนึ่งครั้งจบด้วยการเสียชีวิตสูงสุด  ปิดกราฟแท่งรายชั่วโมงใบล่าง */
  stat_fatalhour: function (p) { return tdAppScreen(p, 1, ['donut', 'list', 'bars'], 2, 3) + tdAppHint(p); },

  /* ช่วงเวลาที่เกิดเหตุมากที่สุดนับเป็นจำนวนครั้ง  ปิดกราฟแท่งใบบน
     คนละใบกับข้อบน เพราะเป็นคนละตัวเลขและคนละการ์ดในแอปจริง */
  stat_crashhour: function (p) { return tdAppScreen(p, 1, ['bars', 'donut', 'list'], 0, 7) + tdAppHint(p); },

  /* สัดส่วนผู้เสียชีวิตที่ไม่ได้สวมหมวกนิรภัย  ปิดวงสัดส่วน */
  stat_helmet:    function (p) { return tdAppScreen(p, 1, ['list', 'bars', 'donut'], 2, 1) + tdAppHint(p); },

  /* สัดส่วนผู้ขับขี่ที่ไม่มีใบอนุญาต  ปิดวงสัดส่วนใบบน */
  stat_licence:   function (p) { return tdAppScreen(p, 1, ['donut', 'bars', 'list'], 0, 4) + tdAppHint(p); },

  /* กลุ่มอายุที่เสียชีวิตมากที่สุด  ปิดกราฟแท่งแยกตามช่วงอายุ */
  stat_age:       function (p) { return tdAppScreen(p, 1, ['list', 'bars', 'donut'], 1, 6) + tdAppHint(p); },

  /* ความเสี่ยงของผู้ซ้อนท้ายและผู้โดยสาร  ปิดการ์ดเปรียบเทียบใบล่าง */
  stat_passenger: function (p) { return tdAppScreen(p, 1, ['bars', 'list', 'donut'], 2, 8) + tdAppHint(p); },

  /* เว็บแอปใช้ข้อมูลใดชี้จุดเสี่ยง  เปิดแท็บแผนที่ ปิดการ์ดที่บอกที่มาของข้อมูล
     การ์ดแผนที่ยังเปิดอยู่ เพราะแผนที่คือหน้าตาของเครื่องมือ ไม่ใช่คำตอบ */
  stat_data:      function (p) { return tdAppScreen(p, 2, ['map', 'list', 'bars'], 1, 0) + tdAppHint(p); },

  /* ลักษณะทางที่พบมากที่สุด  ปิดการ์ดแยกตามลักษณะทาง */
  stat_roadtype:  function (p) { return tdAppScreen(p, 1, ['donut', 'list', 'bars'], 2, 9) + tdAppHint(p); },

  /* ============================================================
     ฉากที่เหตุการณ์เกิดในรถหรือก่อนออกรถ
     ============================================================ */

  /* คำถาม  เป็นหวัด กินยาแก้แพ้ไปเมื่อครึ่งชั่วโมงก่อน และต้องขับรถไปทำธุระ
     ยังไม่ได้ออกรถ การตัดสินใจอยู่ที่บ้าน ภาพจึงเป็นรถจอดนิ่งกับแผงยา ไม่มีถนน */
  pill: function (p) {
    var pills = '', i;
    for (i = 0; i < 8; i++) {
      var px = -34 + (i % 4) * 23, py = -9 + Math.floor(i / 4) * 20;
      pills += '<circle cx="' + px + '" cy="' + py + '" r="8" fill="#e7eef6"/>' +
        '<circle cx="' + px + '" cy="' + py + '" r="5.4" fill="#c9d3e0"/>';
    }
    return tdPanel(p, 26, 40, 348, 180) +
      tdCar(122, 116, 0, TD_BLUE, 1.45, false) +
      '<g transform="translate(286,116)">' +
      '<rect x="-50" y="-27" width="100" height="54" rx="8" fill="rgba(0,0,0,.3)" transform="translate(4,6)"/>' +
      '<rect x="-50" y="-27" width="100" height="54" rx="8" fill="#7f8b9b"/>' +
      '<rect x="-50" y="-27" width="100" height="17" rx="8" fill="#9aa6b6"/>' + pills + '</g>' +
      tdFocus(286, 116, 44);
  },

  /* คำถาม  ผู้ใหญ่ที่นั่งเบาะหลังบอกว่าไม่ต้องคาดเข็มขัด เพราะนั่งหลังปลอดภัยอยู่แล้ว
     มองจากบนเห็นที่นั่งครบสี่ตำแหน่ง จึงชี้ได้ว่าคำถามพูดถึงคนไหน
     สายเข็มขัดวาดเป็นเส้นทแยงบนตัวคน คนที่ไม่คาดจึงไม่มีเส้นนั้น */
  seatbelt: function (p) {
    /* ที่นั่งเรียงขวางลำตัวรถ รถหันหน้าไปทางขวา แถวหน้าจึงอยู่ทางขวาของภาพ
       คนขับอยู่แถวหน้าฝั่งล่าง เพราะพวงมาลัยขวาและขวาของรถคือด้านล่างของภาพ
       คนที่คำถามพูดถึงคือคนเบาะหลัง จึงวงไว้ที่แถวหลังฝั่งล่าง คือหลังคนขับพอดี
       สายเข็มขัดวาดเป็นเส้นทแยงบนตัวคน คนที่ไม่คาดจึงไม่มีเส้นนั้นให้เห็น */
    var fx = 252, bx = 142, uy = 96, ly = 166;
    var belt = function (x, y) {
      return '<line x1="' + (x - 11) + '" y1="' + (y - 11) + '" x2="' + (x + 11) + '" y2="' + (y + 11) +
        '" stroke="#2f3b4a" stroke-width="4" stroke-linecap="round"/>';
    };
    return tdCabin(p, 200, 130, 300, 176) +
      tdSeat(bx, uy, 52, 58) + tdSeat(bx, ly, 52, 58) +
      tdSeat(fx, uy, 52, 58) + tdSeat(fx, ly, 52, 58) +
      /* พวงมาลัยอยู่หน้าที่นั่งคนขับ คือขยับไปทางกระจกหน้าอีกนิด */
      '<circle cx="' + (fx + 36) + '" cy="' + ly + '" r="16" fill="none" stroke="#2f3b4a" stroke-width="5"/>' +
      tdHead(fx, ly, .95, '') + belt(fx, ly) +
      tdHead(fx, uy, .95, '') + belt(fx, uy) +
      tdHead(bx, uy, .95, '') + belt(bx, uy) +
      tdHead(bx, ly, .95, '') +
      tdFocus(bx, ly, 27);
  },

  /* คำถาม  มีสายเข้าระหว่างขับรถ เป็นเรื่องงานที่รอไม่ได้
     ฉากนี้อยู่บนถนนจริง จึงวาดถนนตามปกติ
     เส้นทางที่ส่ายออกนอกแนวคือสิ่งที่เกิดขึ้นจริงเมื่อสายตาไปอยู่ที่จอ */
  phone: function (p) {
    var cy = 120, hh = 46, eb = cy - 23, wb = cy + 23;
    return tdRoadH(p, cy, hh) + tdDashH(p, cy, -4, 404) +
      tdLaneArrow(40, eb, 'e', p.line) + tdLaneArrow(360, wb, 'w', p.line) +
      tdTree(30, 28, 12) + tdTree(340, 234, 12) +
      tdPath('tdpA', 'M24 ' + eb + ' C120 ' + eb + ' 150 ' + (eb + 6) + ' 210 ' + (cy - 2) +
        ' C264 ' + (cy + 4) + ' 300 ' + (eb + 4) + ' 388 ' + eb, TD_BLUE, 386, .8) +
      tdMove(tdCar(0, 0, 0, TD_BLUE, 1, false), 'tdpA', 8, 0) +
      tdConflict(226, cy) +
      '<g transform="translate(60,44)">' +
      '<rect x="-16" y="-27" width="32" height="54" rx="6" fill="rgba(0,0,0,.32)" transform="translate(4,5)"/>' +
      '<rect x="-16" y="-27" width="32" height="54" rx="6" fill="#1d2630"/>' +
      '<rect x="-13" y="-22" width="26" height="44" rx="3" fill="#4ed07a"/>' +
      '<g stroke="#4ed07a" stroke-width="2.6" fill="none" opacity=".9">' +
      '<path d="M22 -12 A16 16 0 0 1 22 12"><animate attributeName="opacity" values=".9;.2;.9" dur="1s" repeatCount="indefinite"/></path>' +
      '<path d="M29 -20 A25 25 0 0 1 29 20"><animate attributeName="opacity" values=".9;.2;.9" dur="1s" begin=".2s" repeatCount="indefinite"/></path>' +
      '</g></g>';
  },

  /* คำถาม  ขับรถกระบะ มีคนอยากนั่งเบียดแถวหน้ารวมคนขับเป็นสี่คน
     มองจากบนจึงนับหัวได้ทันทีว่าแถวหน้ามีกี่คน ซึ่งเป็นใจความทั้งหมดของคำถาม
     มุมคนขับนับไม่ได้ เพราะเห็นห้องโดยสารแค่บางส่วน */
  frontrow: function (p) {
    /* คำถามถามว่าแถวหน้านั่งกี่คน ภาพจึงต้องนับหัวได้ในแถวเดียว
       แถวหน้าของรถเรียงขวางลำตัว เมื่อรถหันหน้าไปทางขวาของภาพ แถวจึงเป็นแนวตั้ง
       คนขับอยู่ล่างสุดของแถว เพราะพวงมาลัยขวา แล้วอีกสามคนเบียดต่อขึ้นไป
       รวมเป็นสี่คนในแถวเดียวตามที่คำถามบอก นับจากภาพได้ตรง ๆ โดยไม่ต้องเดา */
    var fx = 248, y0 = 70, dy = 38;
    return tdCabin(p, 200, 130, 300, 196) +
      tdSeat(fx, 130, 62, 168) + tdSeat(140, 130, 58, 168) +
      '<circle cx="' + (fx + 34) + '" cy="' + (y0 + dy * 3) + '" r="16" fill="none" stroke="#2f3b4a" stroke-width="5"/>' +
      tdHead(fx, y0, .92, '') + tdHead(fx, y0 + dy, .92, '') +
      tdHead(fx, y0 + dy * 2, .92, '') + tdHead(fx, y0 + dy * 3, .92, '') +
      tdFocus(fx, y0 + dy * 0.5, 34) + tdFocus(fx, y0 + dy * 1.5, 34);
  },

  /* คำถาม  กำลังจะออกรถ นึกขึ้นได้ว่าไม่ได้พกอะไรติดตัวเลยนอกจากโทรศัพท์
     วางสิ่งที่ต้องมีติดตัวไว้ข้างรถ คือใบอนุญาตขับรถและสำเนาคู่มือจดทะเบียน
     โทรศัพท์วางไว้ด้วย เพราะเป็นสิ่งเดียวที่คำถามบอกว่ามีอยู่แล้ว */
  papers: function (p) {
    return tdPanel(p, 26, 40, 348, 180) +
      tdCar(104, 130, -90, TD_BLUE, 1.35, false) +
      tdCard(236, 96, 104, 62, '#dfe7f0', -5) +
      tdCard(252, 168, 104, 62, '#cfdae8', 4) +
      '<g transform="translate(332,120) rotate(8)">' +
      '<rect x="-15" y="-26" width="30" height="52" rx="6" fill="rgba(0,0,0,.3)" transform="translate(4,5)"/>' +
      '<rect x="-15" y="-26" width="30" height="52" rx="6" fill="#1d2630"/>' +
      '<rect x="-12" y="-21" width="24" height="42" rx="3" fill="#5b7fa8"/></g>';
  }
};

/* รวมเข้ากับรายการฉากหลัก  ต้องไม่มีชื่อซ้ำกับของเดิม
   ถ้าซ้ำจะทับกันเงียบ ๆ แล้วคำถามข้อหนึ่งจะไปได้ภาพของอีกข้อหนึ่ง
   ซึ่งคือปัญหาเดิมที่เพิ่งแก้ไป จึงหยุดทันทีถ้าพบชื่อซ้ำ */
(function () {
  /* หาตัวรายการฉากหลัก  ในเบราว์เซอร์ไฟล์สคริปต์ใช้ขอบเขตร่วมกัน จึงเห็น TD_SCENES ตรง ๆ
     แต่เวลารันด้วยเครื่องมือทดสอบ แต่ละไฟล์มีขอบเขตของตัวเอง ต้องหยิบจาก window แทน
     รองรับทั้งสองทาง จะได้ทดสอบไฟล์นี้นอกเบราว์เซอร์ได้โดยไม่ต้องแก้โค้ดที่ส่งขึ้นจริง */
  var target = (typeof TD_SCENES !== 'undefined') ? TD_SCENES
             : (typeof window !== 'undefined' ? window.TD_SCENES : null);
  if (!target) {
    throw new Error('ต้องโหลด assets/scene-top.js ก่อน assets/scene-top2.js');
  }
  Object.keys(TD_SCENES2).forEach(function (k) {
    if (target[k]) { throw new Error('ชื่อฉากซ้ำกับของเดิม: ' + k); }
    target[k] = TD_SCENES2[k];
  });
})();
