'use strict';
/* ============================================================
   ฉากมุมสูงสำหรับเกมทดสอบการตัดสินใจ  วาดด้วย SVG ล้วน
   ============================================================
   ทำไมเป็นมุมสูง ไม่ใช่มุมคนขี่เหมือนภาพนิ่งชุดเดิม
     มุมคนขี่ตอบว่า "ตอนนั้นเห็นอะไร"  มุมสูงตอบว่า "กติกาคืออะไร"
     คำถามส่วนใหญ่ในเกมนี้ถามว่าใครต้องให้ทางใคร ซึ่งต้องเห็นรูปทรงของแยกทั้งอัน
     ข้อสอบใบขับขี่ทั่วโลกจึงใช้มุมสูง ไม่ได้ใช้ภาพจากกล้องติดหมวก

   ============================================================
   กฎข้อเดียวที่ผิดไม่ได้เลย  ประเทศไทยขับชิดซ้าย
   ============================================================
   มองจากมุมสูง ทิศเหนืออยู่ด้านบนของภาพ
     รถที่วิ่งจากซ้ายไปขวา  ต้องอยู่ครึ่งล่างของถนน
     รถที่วิ่งจากขวาไปซ้าย  ต้องอยู่ครึ่งบนของถนน
     รถที่วิ่งจากล่างขึ้นบน  ต้องอยู่ครึ่งซ้ายของถนน
     รถที่วิ่งจากบนลงล่าง   ต้องอยู่ครึ่งขวาของถนน
   เลี้ยวซ้ายคือเลี้ยวสั้น เข้าเลนที่อยู่ใกล้ตัวที่สุด ไม่ต้องตัดกระแสรถ
   เลี้ยวขวาคือเลี้ยวยาว ต้องข้ามเลนสวนก่อน จึงเป็นท่าที่เกิดเหตุบ่อยกว่า

   สื่อของตำรวจที่วาดรถขับผิดเลน จะถูกจับผิดและเสียมากกว่าได้
   ทุกฉากในไฟล์นี้จึงมีลูกศรเล็ก ๆ บอกทิศทางของแต่ละเลนกำกับไว้
   ใครแก้ไฟล์นี้ในอนาคต ตรวจลูกศรนั้นก่อนเสมอ

   ============================================================
   เคลื่อนไหวด้วย SMIL ไม่ใช่ไฟล์วิดีโอ
   ============================================================
   ได้ไฟล์เล็กกว่าคลิปหลายร้อยเท่า ไม่ต้องรอโหลด เล่นวนได้ไม่มีรอยต่อ
   และแก้รูปทรงถนนได้ทีหลังโดยไม่ต้องสั่งสร้างคลิปใหม่ทั้งฉาก
   คนที่ตั้งเครื่องให้ลดการเคลื่อนไหว จะได้ภาพนิ่งที่จังหวะอันตรายแทน
   ============================================================ */

var TD_W = 400, TD_H = 260;

var TD_COL = {
  day:   { grass:'#4b7a3f', grass2:'#3f6a35', road:'#3a3f47', kerb:'#b9bec6', line:'#e8edf3', sky:'#dfe8f2' },
  night: { grass:'#23331f', grass2:'#1b2819', road:'#23272d', kerb:'#5a6068', line:'#9fb0c2', sky:'#101826' },
  rain:  { grass:'#3f6742', grass2:'#365a3a', road:'#333a44', kerb:'#9aa2ac', line:'#cfd8e4', sky:'#8794a3' }
};

/* ------------------------------------------------------------
   รถมองจากด้านบน  หันหน้าไปทางขวาของภาพเมื่อ a เป็น 0 องศา
   ------------------------------------------------------------
   วาดครั้งเดียวแล้วหมุนเอา จะได้ไม่ต้องวาดรถแยกทุกทิศ
   ไฟหน้าอยู่ด้านหัว ไฟท้ายสีแดงอยู่ด้านท้าย ใช้ดูทิศทางได้แม้รถหยุดนิ่ง */
function tdCar(x, y, a, col, s) {
  s = s || 1;
  var w = 38 * s, h = 19 * s;
  return '<g transform="translate(' + x + ',' + y + ') rotate(' + a + ') scale(' + s + ')">' +
    '<rect x="-19" y="-9.5" width="38" height="19" rx="5" fill="rgba(0,0,0,.28)" transform="translate(1.5,2.5)"/>' +
    '<rect x="-19" y="-9.5" width="38" height="19" rx="5" fill="' + col + '"/>' +
    '<rect x="-9" y="-7.5" width="15" height="15" rx="3.5" fill="rgba(255,255,255,.82)"/>' +
    '<rect x="7" y="-6.5" width="6" height="13" rx="2.5" fill="rgba(255,255,255,.5)"/>' +
    '<rect x="16" y="-8" width="3" height="4" rx="1.2" fill="#fff6cf"/>' +
    '<rect x="16" y="4" width="3" height="4" rx="1.2" fill="#fff6cf"/>' +
    '<rect x="-19" y="-8" width="3" height="4" rx="1.2" fill="#ff5a5a"/>' +
    '<rect x="-19" y="4" width="3" height="4" rx="1.2" fill="#ff5a5a"/>' +
    '</g>';
}

/* จักรยานยนต์  เล็กกว่ารถและมีคนขี่ ดูออกทันทีว่าเป็นเรา */
function tdMoto(x, y, a, s) {
  s = s || 1;
  return '<g transform="translate(' + x + ',' + y + ') rotate(' + a + ') scale(' + s + ')">' +
    '<ellipse cx="1" cy="2.5" rx="12" ry="6" fill="rgba(0,0,0,.28)"/>' +
    '<rect x="-11" y="-3.5" width="22" height="7" rx="3" fill="#1f2a3d"/>' +
    '<circle cx="-2" cy="0" r="5.4" fill="#f0b429"/>' +
    '<circle cx="-2" cy="0" r="3.2" fill="#2b3a55"/>' +
    '<rect x="4" y="-6" width="2.6" height="12" rx="1.3" fill="#4a5568"/>' +
    '<rect x="10" y="-2" width="3" height="4" rx="1.2" fill="#fff6cf"/>' +
    '</g>';
}

/* ------------------------------------------------------------
   ถนนแนวนอนและแนวตั้ง  พร้อมลูกศรกำกับทิศทางของแต่ละเลน
   ------------------------------------------------------------
   ลูกศรกำกับเลนไม่ได้มีไว้สวยงาม มีไว้ให้คนตรวจงานเห็นทันทีว่าเลนไหนไปทางไหน
   ถ้าวันหนึ่งมีคนแก้แล้วรถวิ่งผิดเลน ลูกศรจะขัดกับตัวรถให้เห็นเอง */
function tdLaneArrow(x, y, dir, c) {
  var a = { e: 0, w: 180, n: -90, s: 90 }[dir];
  return '<g transform="translate(' + x + ',' + y + ') rotate(' + a + ')" opacity=".55">' +
    '<path d="M-7 0H5M1 -4l4 4-4 4" fill="none" stroke="' + c + '" stroke-width="1.8" ' +
    'stroke-linecap="round" stroke-linejoin="round"/></g>';
}

function tdRoadH(p, cy, half) {
  return '<rect x="-4" y="' + (cy - half - 4) + '" width="408" height="4" fill="' + p.kerb + '"/>' +
    '<rect x="-4" y="' + (cy + half) + '" width="408" height="4" fill="' + p.kerb + '"/>' +
    '<rect x="-4" y="' + (cy - half) + '" width="408" height="' + (half * 2) + '" fill="' + p.road + '"/>';
}
function tdRoadV(p, cx, half) {
  return '<rect x="' + (cx - half - 4) + '" y="-4" width="4" height="268" fill="' + p.kerb + '"/>' +
    '<rect x="' + (cx + half) + '" y="-4" width="4" height="268" fill="' + p.kerb + '"/>' +
    '<rect x="' + (cx - half) + '" y="-4" width="' + (half * 2) + '" height="268" fill="' + p.road + '"/>';
}
function tdDashH(p, cy, x1, x2) {
  return '<line x1="' + x1 + '" y1="' + cy + '" x2="' + x2 + '" y2="' + cy + '" stroke="' + p.line +
    '" stroke-width="2" stroke-dasharray="14 12" opacity=".85"/>';
}
function tdDashV(p, cx, y1, y2) {
  return '<line x1="' + cx + '" y1="' + y1 + '" x2="' + cx + '" y2="' + y2 + '" stroke="' + p.line +
    '" stroke-width="2" stroke-dasharray="14 12" opacity=".85"/>';
}
/* เส้นให้ทาง  เส้นขาวทึบขวางปากทางรอง บอกว่าต้องหยุดดูก่อนออก */
function tdGiveWay(p, cx, y, half) {
  return '<rect x="' + (cx - half) + '" y="' + y + '" width="' + (half * 2) + '" height="4" fill="' + p.line + '" opacity=".9"/>';
}

/* ------------------------------------------------------------
   ลูกศรเส้นทางที่รถตั้งใจจะไป  ค่อย ๆ ลากออกมาแล้ววนใหม่
   ------------------------------------------------------------
   เป็นหัวใจของฉากแบบนี้ ผู้เล่นต้องเห็นว่าสองคันกำลังจะไปทับทางกันตรงไหน */
var TD_LOOP = 4.4;   // หนึ่งรอบของลูกศร  ลากออก 1.1  ค้าง 2.3  จาง 0.5  เว้น 0.5
function tdPath(id, d, col, dash, delay) {
  /* ลูกศรบอกเจตนา ไม่ใช่เครื่องหมายบนผิวถนน จึงต้องบางกว่าเลนและต้องหายไปเป็นจังหวะ
     ถ้าค้างอยู่ตลอดเวลา สายตาจะอ่านเป็นสีที่ทาไว้บนถนนจริง ซึ่งสื่อผิดทันที
     วนเป็นรอบยังทำให้เห็นลำดับด้วยว่าใครมาก่อนใคร เพราะสองเส้นเริ่มไม่พร้อมกัน */
  var t = TD_LOOP;
  return '<path id="' + id + '" d="' + d + '" fill="none" stroke="' + col + '" stroke-width="5" ' +
    'stroke-linecap="round" stroke-linejoin="round" marker-end="url(#tdArrow' + col.replace('#', '') + ')" ' +
    'opacity="0" stroke-dasharray="' + dash + '" stroke-dashoffset="' + dash + '">' +
    '<animate attributeName="stroke-dashoffset" values="' + dash + ';0;0;0" keyTimes="0;0.25;0.86;1" ' +
    'dur="' + t + 's" begin="' + delay + 's" repeatCount="indefinite"/>' +
    '<animate attributeName="opacity" values="0;.95;.95;0;0" keyTimes="0;0.08;0.78;0.9;1" ' +
    'dur="' + t + 's" begin="' + delay + 's" repeatCount="indefinite"/>' +
    '</path>';
}

/* จุดที่สองเส้นทางไปทับกัน  วงกลมจาง ๆ ให้สายตาไปหยุดตรงนั้น
   เป็นหัวใจของคำถามทุกข้อในแบบนี้ คือจุดที่ต้องตัดสินใจว่าใครไปก่อน */
function tdConflict(x, y) {
  return '<g transform="translate(' + x + ',' + y + ')">' +
    '<circle r="17" fill="none" stroke="#ffd166" stroke-width="2.5" opacity=".9">' +
    '<animate attributeName="r" values="13;20;13" dur="1.8s" repeatCount="indefinite"/>' +
    '<animate attributeName="opacity" values=".9;.25;.9" dur="1.8s" repeatCount="indefinite"/>' +
    '</circle></g>';
}

function tdMarker(col) {
  var id = 'tdArrow' + col.replace('#', '');
  return '<marker id="' + id + '" viewBox="0 0 10 10" refX="7" refY="5" markerWidth="4.5" markerHeight="4.5" orient="auto">' +
    '<path d="M0 0.5 L9 5 L0 9.5 z" fill="' + col + '"/></marker>';
}

/* วัตถุวิ่งตามเส้นทางที่กำหนด หันหัวตามแนวเส้นเอง */
function tdMove(inner, pathId, dur, begin) {
  return '<g>' + inner +
    '<animateMotion dur="' + dur + 's" begin="' + begin + 's" repeatCount="indefinite" rotate="auto">' +
    '<mpath href="#' + pathId + '"/></animateMotion></g>';
}

var TD_BLUE = '#2f7fe0', TD_RED = '#d9342b';

/* ============================================================
   ฉากทั้งแปด
   ============================================================ */
var TD_SCENES = {

  /* สี่แยกไม่มีสัญญาณไฟ  ใช้กับคำถาม 34 ข้อ มากที่สุดในเกม
     เราขี่มาจากทางรองด้านล่าง จะออกถนนใหญ่
     รถเก๋งวิ่งบนถนนใหญ่จากซ้ายไปขวา จึงอยู่เลนล่าง ซึ่งเป็นเลนที่เราจะเข้าพอดี */
  junction: function (p) {
    var cy = 104, cx = 196, hh = 42, vh = 30;
    return tdRoadH(p, cy, hh) + tdRoadV(p, cx, vh) +
      '<rect x="' + (cx - vh) + '" y="' + (cy - hh) + '" width="' + (vh * 2) + '" height="' + (hh * 2) + '" fill="' + p.road + '"/>' +
      tdDashH(p, cy, -4, cx - vh) + tdDashH(p, cy, cx + vh, 404) +
      tdGiveWay(p, cx, cy + hh + 8, vh - 4) +
      tdLaneArrow(60, cy + 21, 'e', p.line) + tdLaneArrow(340, cy + 21, 'e', p.line) +
      tdLaneArrow(60, cy - 21, 'w', p.line) + tdLaneArrow(340, cy - 21, 'w', p.line) +
      tdLaneArrow(cx - 15, 210, 'n', p.line) +
      /* เราเลี้ยวขวาออกจากทางรอง ซึ่งต้องตัดผ่านเลนที่รถกำลังวิ่งมาก่อน
         เลือกท่านี้เพราะเป็นท่าที่เกิดเหตุบ่อยกว่าเลี้ยวซ้ายมาก
         และทำให้เส้นทางสองเส้นตัดกันที่จุดเดียว เห็นได้ทันทีว่าอันตรายตรงไหน
         ถ้าวาดเลี้ยวซ้าย เส้นทางสองเส้นจะทับกันยาวตลอดเลน อ่านไม่ออกว่าใครตัดหน้าใคร */
      tdPath('tdpB', 'M58 ' + (cy + 21) + ' L286 ' + (cy + 21), TD_RED, 232, .4) +
      tdPath('tdpA', 'M' + (cx - 15) + ' 228 L' + (cx - 15) + ' ' + (cy + 2) + ' Q' + (cx - 15) + ' ' + (cy - 21) + ' ' + (cx - 42) + ' ' + (cy - 21) + ' L70 ' + (cy - 21), TD_BLUE, 250, 1.9) +
      tdConflict(cx - 15, cy + 21) +
      tdCar(34, cy + 21, 0, TD_RED, 1) +
      tdMoto(cx - 15, 232, -90, 1);
  },

  /* ไฟเหลืองใกล้แยก  เหมือนแยกแต่มีสัญญาณไฟและเราอยู่บนถนนใหญ่ */
  amber: function (p) {
    var cy = 104, cx = 196, hh = 42, vh = 30;
    return tdRoadH(p, cy, hh) + tdRoadV(p, cx, vh) +
      '<rect x="' + (cx - vh) + '" y="' + (cy - hh) + '" width="' + (vh * 2) + '" height="' + (hh * 2) + '" fill="' + p.road + '"/>' +
      tdDashH(p, cy, -4, cx - vh) + tdDashH(p, cy, cx + vh, 404) +
      '<rect x="' + (cx - vh - 12) + '" y="' + (cy + 21 - 14) + '" width="4" height="28" fill="' + p.line + '" opacity=".9"/>' +
      tdLaneArrow(70, cy + 21, 'e', p.line) + tdLaneArrow(330, cy - 21, 'w', p.line) +
      '<g transform="translate(' + (cx - vh - 26) + ',' + (cy + 34) + ')">' +
      '<rect x="-9" y="-30" width="18" height="44" rx="4" fill="#11151c"/>' +
      '<circle cx="0" cy="-20" r="5" fill="#3a2020"/>' +
      '<circle cx="0" cy="-7" r="5" fill="#f6c445"><animate attributeName="opacity" values="1;.25;1" dur="1s" repeatCount="indefinite"/></circle>' +
      '<circle cx="0" cy="6" r="5" fill="#1e3324"/></g>' +
      tdPath('tdpA', 'M40 ' + (cy + 21) + ' L392 ' + (cy + 21), TD_BLUE, 352, .6) +
      tdMove(tdMoto(0, 0, 0, 1), 'tdpA', 6, 0);
  },

  /* จุดกลับรถ  ถนนมีเกาะกลาง เรากลับรถจากเลนล่างไปเลนบน
     เลนล่างวิ่งไปขวา เลนบนวิ่งไปซ้าย การกลับรถจึงเป็นการวนขึ้นไปฝั่งตรงข้าม */
  uturn: function (p) {
    var cy = 104, hh = 46;
    return tdRoadH(p, cy, hh) +
      '<rect x="-4" y="' + (cy - 7) + '" width="170" height="14" rx="3" fill="' + p.kerb + '" opacity=".9"/>' +
      '<rect x="236" y="' + (cy - 7) + '" width="172" height="14" rx="3" fill="' + p.kerb + '" opacity=".9"/>' +
      tdLaneArrow(70, cy + 26, 'e', p.line) + tdLaneArrow(330, cy + 26, 'e', p.line) +
      tdLaneArrow(70, cy - 26, 'w', p.line) + tdLaneArrow(330, cy - 26, 'w', p.line) +
      tdPath('tdpA', 'M120 ' + (cy + 26) + ' L186 ' + (cy + 26) + ' Q216 ' + (cy + 26) + ' 216 ' + cy + ' Q216 ' + (cy - 26) + ' 186 ' + (cy - 26) + ' L70 ' + (cy - 26), TD_BLUE, 300, 1.5) +
      tdPath('tdpB', 'M392 ' + (cy - 26) + ' L8 ' + (cy - 26), TD_RED, 384, .5) +
      tdMove(tdCar(0, 0, 0, TD_RED, 1), 'tdpB', 6.5, 0) +
      tdMoto(120, cy + 26, 0, 1);
  },

  /* จุดบอดรถบรรทุก  เราขี่ขนาบซ้ายของรถบรรทุกที่กำลังจะเลี้ยวซ้าย
     ชิดซ้ายแปลว่ารถเลี้ยวซ้ายจะกวาดทับที่ที่เราอยู่พอดี นี่คือจุดตายจริง */
  truck: function (p) {
    var cy = 104, hh = 46;
    return tdRoadH(p, cy, hh) + tdRoadV(p, 300, 30) +
      '<rect x="270" y="' + (cy - hh) + '" width="60" height="' + (hh * 2) + '" fill="' + p.road + '"/>' +
      tdDashH(p, cy, -4, 270) + tdDashH(p, cy, 330, 404) +
      tdLaneArrow(60, cy + 26, 'e', p.line) + tdLaneArrow(60, cy - 26, 'w', p.line) +
      '<g transform="translate(170,' + (cy + 20) + ')">' +
      '<rect x="-46" y="-13" width="74" height="26" rx="3" fill="rgba(0,0,0,.3)" transform="translate(2,3)"/>' +
      '<rect x="-46" y="-13" width="58" height="26" rx="2" fill="#cfd6e0"/>' +
      '<rect x="12" y="-12" width="16" height="24" rx="3" fill="#6b7280"/>' +
      '<rect x="26" y="-9" width="3" height="4" rx="1" fill="#fff6cf"/>' +
      '<rect x="26" y="5" width="3" height="4" rx="1" fill="#fff6cf"/>' +
      '<circle cx="28" cy="-15" r="3.4" fill="#f6a723"><animate attributeName="opacity" values="1;.15;1" dur=".7s" repeatCount="indefinite"/></circle>' +
      '</g>' +
      tdPath('tdpA', 'M198 ' + (cy + 20) + ' L272 ' + (cy + 20) + ' Q300 ' + (cy + 20) + ' 300 ' + (cy + 48) + ' L300 236', TD_RED, 240, 1.4) +
      tdMoto(150, cy + 40, 0, 1) +
      '<g opacity=".22"><path d="M196 ' + (cy + 6) + ' L262 ' + (cy + 46) + ' L196 ' + (cy + 46) + ' Z" fill="#ff3b30"/></g>';
  },

  /* ฝนเพิ่งเริ่มตก  ตามหลังรถคันหน้าใกล้เกินไปบนถนนเปียก */
  rain: function (p) {
    var cy = 104, hh = 44, drops = '';
    for (var i = 0; i < 26; i++) {
      var x = 12 + (i * 15) % 380, y = (i * 37) % 250;
      drops += '<line x1="' + x + '" y1="' + y + '" x2="' + (x - 4) + '" y2="' + (y + 11) + '" stroke="#cfe0f2" stroke-width="1.2" opacity=".55">' +
        '<animate attributeName="y1" values="' + (y - 40) + ';' + (y + 260) + '" dur="' + (0.8 + (i % 5) * 0.12) + 's" repeatCount="indefinite"/>' +
        '<animate attributeName="y2" values="' + (y - 29) + ';' + (y + 271) + '" dur="' + (0.8 + (i % 5) * 0.12) + 's" repeatCount="indefinite"/></line>';
    }
    return tdRoadH(p, cy, hh) + tdDashH(p, cy, -4, 404) +
      '<rect x="-4" y="' + (cy - hh) + '" width="408" height="' + (hh * 2) + '" fill="#9fc4e8" opacity=".12"/>' +
      tdLaneArrow(60, cy + 24, 'e', p.line) + tdLaneArrow(340, cy - 24, 'w', p.line) +
      tdPath('tdpA', 'M40 ' + (cy + 24) + ' L392 ' + (cy + 24), TD_BLUE, 352, .8) +
      tdMove(tdCar(0, 0, 0, TD_RED, 1), 'tdpA', 5.5, 0) +
      tdMove(tdMoto(0, 0, 0, 1), 'tdpA', 5.5, .55) +
      drops;
  },

  /* ปากซอย ระยะทางสั้น  ออกจากซอยด้านล่างสู่ถนนใหญ่ หมวกยังแขวนอยู่ */
  helmet: function (p) {
    var cy = 92, cx = 180, hh = 40, vh = 24;
    return tdRoadH(p, cy, hh) + tdRoadV(p, cx, vh) +
      '<rect x="' + (cx - vh) + '" y="' + (cy - hh) + '" width="' + (vh * 2) + '" height="' + (hh * 2) + '" fill="' + p.road + '"/>' +
      tdDashH(p, cy, -4, cx - vh) + tdDashH(p, cy, cx + vh, 404) +
      tdGiveWay(p, cx, cy + hh + 8, vh - 3) +
      tdLaneArrow(70, cy + 20, 'e', p.line) + tdLaneArrow(330, cy - 20, 'w', p.line) +
      '<g transform="translate(' + (cx + 52) + ',176)"><rect x="-26" y="-16" width="52" height="32" rx="4" fill="#8d6b4a"/>' +
      '<rect x="-26" y="-16" width="52" height="9" rx="3" fill="#c0562f"/></g>' +
      '<g transform="translate(' + (cx - 34) + ',200)"><circle cx="0" cy="0" r="9" fill="#f0b429"/>' +
      '<path d="M-9 2a9 9 0 0 1 18 0z" fill="#d99a1f"/>' +
      '<animateTransform attributeName="transform" type="rotate" values="-6 0 0;6 0 0;-6 0 0" dur="2.4s" repeatCount="indefinite" additive="sum"/></g>' +
      tdPath('tdpA', 'M' + (cx - 12) + ' 232 L' + (cx - 12) + ' ' + (cy + 28) + ' Q' + (cx - 12) + ' ' + (cy + 20) + ' ' + cx + ' ' + (cy + 20) + ' L392 ' + (cy + 20), TD_BLUE, 260, 1.5) +
      tdPath('tdpB', 'M392 ' + (cy - 20) + ' L8 ' + (cy - 20), TD_RED, 384, .5) +
      tdMove(tdCar(0, 0, 0, TD_RED, 1), 'tdpB', 7, 0) +
      tdMoto(cx - 12, 236, -90, 1);
  },

  /* ทางตรงกลางคืน ง่วง  รถส่ายออกนอกเลนช้า ๆ */
  drowsy: function (p) {
    var cy = 104, hh = 44;
    return tdRoadH(p, cy, hh) + tdDashH(p, cy, -4, 404) +
      tdLaneArrow(60, cy + 24, 'e', p.line) + tdLaneArrow(340, cy - 24, 'w', p.line) +
      tdPath('tdpA', 'M20 ' + (cy + 24) + ' C120 ' + (cy + 24) + ' 150 ' + (cy + 4) + ' 210 ' + (cy + 6) +
        ' C270 ' + (cy + 8) + ' 300 ' + (cy + 30) + ' 392 ' + (cy + 22), TD_BLUE, 400, .8) +
      tdMove(tdCar(0, 0, 0, TD_BLUE, 1), 'tdpA', 8, 0) +
      '<g opacity=".9"><circle cx="330" cy="' + (cy - 24) + '" r="4" fill="#ff5a5a"><animate attributeName="opacity" values="1;.2;1" dur="1.2s" repeatCount="indefinite"/></circle></g>';
  },

  /* ดื่มแล้วจะขับ  รถจอดริมทางตอนกลางคืน ยังไม่ออก */
  drink: function (p) {
    var cy = 116, hh = 42;
    return tdRoadH(p, cy, hh) + tdDashH(p, cy, -4, 404) +
      tdLaneArrow(70, cy + 22, 'e', p.line) + tdLaneArrow(330, cy - 22, 'w', p.line) +
      '<g transform="translate(96,44)"><rect x="-58" y="-26" width="116" height="52" rx="6" fill="#2a2f3a"/>' +
      '<rect x="-58" y="-26" width="116" height="14" rx="5" fill="#b8452f"/>' +
      '<circle cx="-30" cy="6" r="7" fill="#f5c451" opacity=".85"><animate attributeName="opacity" values=".85;.5;.85" dur="2.6s" repeatCount="indefinite"/></circle>' +
      '<circle cx="0" cy="6" r="7" fill="#f5c451" opacity=".7"/>' +
      '<circle cx="30" cy="6" r="7" fill="#f5c451" opacity=".85"/></g>' +
      tdCar(120, cy + 60, 0, TD_BLUE, 1) +
      tdPath('tdpA', 'M140 ' + (cy + 60) + ' L206 ' + (cy + 60) + ' Q244 ' + (cy + 60) + ' 244 ' + (cy + 22) + ' L392 ' + (cy + 22), TD_BLUE, 300, 1.4) +
      tdPath('tdpRoad', 'M392 ' + (cy - 22) + ' L8 ' + (cy - 22), TD_RED, 384, .4) +
      tdMove(tdCar(0, 0, 0, TD_RED, 1), 'tdpRoad', 6, 0);
  }
};


/* ============================================================
   ผูกฉากกับหัวข้อคำถาม ไม่ใช่ผูกกับชื่อชุดภาพ
   ============================================================
   ชื่อชุดภาพ junction ถูกใช้เป็นฉากสำรองของคำถาม 34 ข้อ ซึ่งมี 29 หัวข้อต่างกัน
   ส่วนใหญ่ไม่เกี่ยวกับทางแยกเลย เช่น สถิติในพื้นที่ 6 ข้อ ในรถ ก่อนออกเดินทาง บีบแตร

   ภาพวาดชุดเดิมเป็นบรรยากาศถนนกว้าง ๆ จึงใช้แทนกันได้โดยไม่ขัดตา
   แต่แผนผังมุมสูงเจาะจงมาก วาดทางแยกให้คำถามเรื่องสถิติคือบอกข้อมูลผิด
   จึงแสดงมุมสูงเฉพาะหัวข้อที่เป็นสถานการณ์บนถนนจริง ๆ เท่านั้น
   หัวข้อที่ไม่อยู่ในรายการนี้ จะใช้ภาพชุดเดิมต่อไปเหมือนไม่มีอะไรเปลี่ยน */
var TD_BY_TAG = {
  'ทางแยกไม่มีสัญญาณไฟ': 'junction',
  'ทางเอกตัดกัน':        'junction',
  'เส้นให้ทาง':          'junction',
  'ใกล้ปากแยก':          'junction',
  'ผ่านแยกตรงไป':        'junction',
  'ทางแยกรถติด':         'junction',
  'ก่อนเลี้ยว':          'junction',
  'ทางแยกมีสัญญาณไฟ':    'amber',
  'จุดกลับรถ':           'uturn',
  'ทางร่วม':             'truck',
  'ถนนหลายช่องทาง':      'truck',
  'ฝนเพิ่งเริ่มตก':      'rain',
  'ฝนตกหนัก':            'rain',
  'ถนนน้ำท่วมขัง':       'rain',
  'ระยะทางสั้น':         'helmet',
  'หน้าบ้าน':            'helmet',
  'ก่อนออกรถ':           'helmet',
  'ทางตรง กลางคืน':      'drowsy',
  'พลบค่ำ':              'drowsy',
  'ริมถนนกลางคืน':       'drowsy',
  'จอดข้างทางกลางคืน':   'drowsy',
  'หน้าร้านอาหาร':       'drink'
};
/* ============================================================
   ประกอบเป็น SVG พร้อมใช้
   ============================================================ */
function topSVG(art, mood, tag) {
  var key2 = TD_BY_TAG[tag];
  if (!key2) return '';        // หัวข้อที่ไม่ได้อยู่ในรายการ ใช้ภาพชุดเดิม
  var fn = TD_SCENES[key2];
  if (!fn) return '';
  art = key2;
  var key = (mood === 'night' || art === 'drowsy' || art === 'drink') ? 'night'
          : (mood === 'rain' || art === 'rain') ? 'rain' : 'day';
  var p = TD_COL[key];

  /* คนที่ตั้งเครื่องให้ลดการเคลื่อนไหว จะได้ภาพนิ่ง
     ยังเห็นเส้นทางและตำแหน่งรถครบ เพราะลูกศรถูกวาดค้างไว้ตั้งแต่ต้น */
  var still = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  var svg = '<svg class="scene-top" viewBox="0 0 ' + TD_W + ' ' + TD_H + '" preserveAspectRatio="xMidYMid slice" ' +
    'xmlns="http://www.w3.org/2000/svg" aria-hidden="true">' +
    '<defs>' + tdMarker(TD_BLUE) + tdMarker(TD_RED) +
    '<linearGradient id="tdG" x1="0" y1="0" x2="0" y2="1">' +
    '<stop offset="0" stop-color="' + p.grass + '"/><stop offset="1" stop-color="' + p.grass2 + '"/>' +
    '</linearGradient></defs>' +
    '<rect width="' + TD_W + '" height="' + TD_H + '" fill="url(#tdG)"/>' +
    fn(p) + '</svg>';

  if (still) {
    // ตัดตัวสั่งเคลื่อนไหวออก แล้วให้ลูกศรที่ถูกวาดค้างไว้แสดงเต็มเส้น
    svg = svg.replace(/<animate[^>]*\/>/g, '').replace(/<animateMotion[\s\S]*?<\/animateMotion>/g, '')
             .replace(/<animateTransform[^>]*\/>/g, '')
             .replace(/stroke-dashoffset="\d+(\.\d+)?"/g, 'stroke-dashoffset="0"');
  }
  return svg;
}

if (typeof window !== 'undefined') { window.topSVG = topSVG; }
