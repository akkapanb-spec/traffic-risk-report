'use strict';
/* ============================================================
   ฉากมุมสูงสามมิติสำหรับเกมทดสอบการตัดสินใจ  วาดด้วย SVG ล้วน
   ============================================================
   ทำไมเป็นมุมสูง ไม่ใช่มุมคนขี่เหมือนภาพถ่ายชุดเดิม
     มุมคนขี่ตอบว่า ตอนนั้นเห็นอะไร  มุมสูงตอบว่า กติกาคืออะไร
     คำถามชุดนี้ถามว่าใครต้องให้ทางใคร ซึ่งต้องเห็นรูปทรงของทางทั้งอัน
     ข้อสอบใบขับขี่ทั่วโลกจึงใช้มุมสูง ไม่ได้ใช้ภาพจากกล้องติดหมวก

   ============================================================
   กฎข้อเดียวที่ผิดไม่ได้เลย  ประเทศไทยขับชิดซ้าย
   ============================================================
   วิธีคิดที่ถูก  ยืนหันหน้าไปตามทิศที่รถวิ่ง แล้วถามว่ามือซ้ายชี้ไปทางไหนของภาพ
   ภาพนี้เหนืออยู่ด้านบนเสมอ

     วิ่งไปทางขวาของภาพ   หันหน้าออก มือซ้ายชี้เหนือ  จึงอยู่ครึ่งบนของถนน
     วิ่งไปทางซ้ายของภาพ  หันหน้าตก มือซ้ายชี้ใต้    จึงอยู่ครึ่งล่างของถนน
     วิ่งจากล่างขึ้นบน    หันหน้าเหนือ มือซ้ายชี้ตก  จึงอยู่ครึ่งซ้ายของถนน
     วิ่งจากบนลงล่าง      หันหน้าใต้ มือซ้ายชี้ออก   จึงอยู่ครึ่งขวาของถนน

   ตรวจซ้ำได้อีกทางหนึ่ง  รถที่สวนมาต้องผ่านทางขวามือของเราเสมอ
   ถ้าวาดแล้วรถสวนไปอยู่ทางซ้ายมือ แปลว่าวาดเป็นถนนฝรั่งไปแล้ว

   ไฟล์รุ่นแรกเขียนกฎสองบรรทัดแรกไว้กลับด้าน คือให้รถที่วิ่งไปทางขวาอยู่ครึ่งล่าง
   ทุกฉากจึงวาดตามนั้นหมด และรถสีแดงไปอยู่ในเลนสวนของตัวเอง
   ที่ผิดคือตัวกฎ ไม่ใช่ตัวฉาก จึงผิดพร้อมกันทั้งไฟล์โดยไม่มีฉากไหนขัดให้เห็น
   ใครแก้ไฟล์นี้ต่อ ให้พิสูจน์ด้วยมือซ้ายก่อนเสมอ อย่าลอกจากฉากที่มีอยู่

   ทุกฉากมีลูกศรจาง ๆ กำกับทิศทางของทุกเลนไว้ ถ้ารถกับลูกศรสวนกันเมื่อไร แปลว่าผิด

   ============================================================
   หนึ่งฉากต่อหนึ่งคำถาม
   ============================================================
   รุ่นก่อนเดาฉากจากป้ายหัวข้อ ผลคือครึ่งหนึ่งได้ภาพที่ไม่ใช่เรื่องในคำถาม
   เช่น ป้ายว่า ใกล้ปากแยก แต่คำถามถามเรื่องแซงรถช้า กลับได้ภาพเลี้ยวออกจากซอย
   ป้ายหัวข้อเป็นแค่คำสั้น ๆ ไม่ได้บอกสถานการณ์ในคำถาม

   ตอนนี้คำถามเป็นคนเลือกฉากเอง ผ่านช่อง top ในคลังคำถาม
   คำถามที่ไม่มี top ก็ใช้ภาพวาดชุดเดิมต่อไป
   เพิ่มฉากใหม่เมื่อไร ให้คัดลอกคำถามจริงมาไว้เหนือฉากนั้นด้วย
   จะได้ตรวจได้ทันทีว่าที่วาดคือเรื่องเดียวกับที่ถามหรือเปล่า

   ============================================================
   เคลื่อนไหวด้วย SMIL ไม่ใช่ไฟล์วิดีโอ
   ============================================================
   ได้ไฟล์เล็กกว่าคลิปหลายร้อยเท่า ไม่ต้องรอโหลด เล่นวนได้ไม่มีรอยต่อ
   และแก้รูปทรงถนนได้ทีหลังโดยไม่ต้องสั่งสร้างคลิปใหม่ทั้งฉาก
   คนที่ตั้งเครื่องให้ลดการเคลื่อนไหว จะได้ภาพนิ่งที่จังหวะอันตรายแทน

   ความเป็นสามมิติมาจากการวางแสงไว้ทางซ้ายบนทางเดียวทั้งไฟล์
   เงาจึงทอดไปทางขวาล่างเสมอ ตัวถังรถมีขอบล่างเข้มและหลังคาสว่าง
   อาคารมีผนังด้านที่หันเข้าหาเราให้เห็น ไม่ใช่สี่เหลี่ยมแบน
   ============================================================ */

var TD_W = 400, TD_H = 260;

var TD_COL = {
  day:   { grass:'#54803f', grass2:'#3f6a35', road:'#41464e', kerb:'#c3c8d0', line:'#eef2f7' },
  night: { grass:'#22321f', grass2:'#182417', road:'#23272e', kerb:'#59606a', line:'#9db0c4' },
  rain:  { grass:'#40663f', grass2:'#345636', road:'#343b45', kerb:'#9ba3ad', line:'#d3dce6' }
};

var TD_BLUE = '#2f7fe0', TD_RED = '#d9342b';

/* คูณความสว่างของสี ใช้ทำด้านมืดกับด้านสว่างของวัตถุเดียวกัน
   รับเฉพาะสีที่เขียนเป็นเลขฐานสิบหกหกหลัก เพราะในไฟล์นี้เขียนแบบนั้นทั้งหมด */
function tdShade(c, f) {
  var n = parseInt(c.slice(1), 16);
  var r = Math.max(0, Math.min(255, Math.round(((n >> 16) & 255) * f)));
  var g = Math.max(0, Math.min(255, Math.round(((n >> 8) & 255) * f)));
  var b = Math.max(0, Math.min(255, Math.round((n & 255) * f)));
  return 'rgb(' + r + ',' + g + ',' + b + ')';
}

/* ------------------------------------------------------------
   รถเก๋งมองจากด้านบน  หันหน้าไปทางขวาของภาพเมื่อ a เป็นศูนย์องศา
   ------------------------------------------------------------
   วาดครั้งเดียวแล้วหมุนเอา จะได้ไม่ต้องวาดรถแยกทุกทิศ
   ไฟหน้าอยู่ด้านหัว ไฟท้ายแดงอยู่ด้านท้าย ใช้ดูทิศทางได้แม้รถจอดนิ่ง
   brake ให้ไฟท้ายสว่างค้าง ใช้บอกว่ารถกำลังชะลอ ซึ่งไม่ได้แปลว่ารถจะหยุด */
function tdCar(x, y, a, col, s, brake) {
  s = s || 1;
  var dark = tdShade(col, 0.62), lite = tdShade(col, 1.18);
  var tail = brake ? '#ff2d2d' : '#c23a3a';
  return '<g transform="translate(' + x + ',' + y + ') rotate(' + a + ') scale(' + s + ')">' +
    '<rect x="-20" y="-10" width="40" height="20" rx="6" fill="rgba(0,0,0,.32)" transform="translate(3,4)"/>' +
    '<rect x="-20" y="-10" width="40" height="20" rx="6" fill="' + dark + '"/>' +
    '<rect x="-19" y="-9.6" width="38" height="17.4" rx="5" fill="' + col + '"/>' +
    '<rect x="-18" y="-9" width="36" height="6" rx="4" fill="' + lite + '" opacity=".75"/>' +
    '<path d="M2 -7.4 L8.6 -4.6 L8.6 4.6 L2 7.4 Z" fill="rgba(226,240,255,.85)"/>' +
    '<path d="M-12 -6.6 L-7 -4.2 L-7 4.2 L-12 6.6 Z" fill="rgba(226,240,255,.6)"/>' +
    '<rect x="-6.4" y="-6.8" width="8.6" height="13.6" rx="2.4" fill="' + dark + '" opacity=".85"/>' +
    '<rect x="17" y="-8.2" width="3.4" height="4" rx="1.4" fill="#fff3c4"/>' +
    '<rect x="17" y="4.2" width="3.4" height="4" rx="1.4" fill="#fff3c4"/>' +
    '<rect x="-20.4" y="-8.2" width="3.4" height="4" rx="1.4" fill="' + tail + '"/>' +
    '<rect x="-20.4" y="4.2" width="3.4" height="4" rx="1.4" fill="' + tail + '"/>' +
    '</g>';
}

/* จักรยานยนต์  เล็กกว่ารถและเห็นหัวคนขี่ ดูออกทันทีว่าเป็นเรา
   helm คือสีหมวก ถ้าส่งค่าว่างมาแปลว่าหัวเปล่า ไม่ได้สวมหมวก */
function tdMoto(x, y, a, s, col, helm) {
  s = s || 1;
  col = col || TD_BLUE;
  if (helm === undefined) helm = '#f0b429';
  var head = helm ? '<circle cx="-1" cy="0" r="5.6" fill="' + helm + '"/>' +
      '<path d="M-6.6 1.4a5.6 5.6 0 0 0 11.2 0z" fill="' + tdShade(helm, .72) + '"/>' +
      '<rect x="2.4" y="-2" width="3" height="4" rx="1.2" fill="rgba(255,255,255,.75)"/>'
    : '<circle cx="-1" cy="0" r="5" fill="#d9a06a"/>' +
      '<path d="M-6 -1.6a5 5 0 0 1 10 0z" fill="#2f2a26"/>';
  return '<g transform="translate(' + x + ',' + y + ') rotate(' + a + ') scale(' + s + ')">' +
    '<ellipse cx="2" cy="3.5" rx="13" ry="6" fill="rgba(0,0,0,.3)"/>' +
    '<rect x="-12" y="-3.8" width="24" height="7.6" rx="3.6" fill="#161d2a"/>' +
    '<rect x="-12" y="-3.8" width="24" height="2.6" rx="1.3" fill="#38445c"/>' +
    '<rect x="-7" y="-5.4" width="7" height="10.8" rx="2.4" fill="' + col + '"/>' +
    head +
    '<rect x="4.6" y="-6.4" width="2.6" height="12.8" rx="1.3" fill="#4a5568"/>' +
    '<rect x="10.6" y="-2" width="3" height="4" rx="1.2" fill="#fff3c4"/>' +
    '<rect x="-13" y="-1.8" width="2.4" height="3.6" rx="1.1" fill="#c23a3a"/>' +
    '</g>';
}

/* จักรยานยนต์ซ้อนสอง  ใช้กับคำถามเรื่องคนซ้อนท้ายไม่สวมหมวกโดยเฉพาะ
   หัวคนขี่กับหัวคนซ้อนต้องกำหนดสีแยกกันได้ จึงไม่ใช้ tdMoto ตัวเดิม */
function tdMotoPair(x, y, a, s, helmRider, helmPillion) {
  s = s || 1;
  function head(hx, h) {
    return h ? '<circle cx="' + hx + '" cy="0" r="5.4" fill="' + h + '"/>' +
        '<path d="M' + (hx - 5.4) + ' 1.3a5.4 5.4 0 0 0 10.8 0z" fill="' + tdShade(h, .72) + '"/>'
      : '<circle cx="' + hx + '" cy="0" r="5" fill="#d9a06a"/>' +
        '<path d="M' + (hx - 5) + ' -1.6a5 5 0 0 1 10 0z" fill="#2f2a26"/>';
  }
  return '<g transform="translate(' + x + ',' + y + ') rotate(' + a + ') scale(' + s + ')">' +
    '<ellipse cx="2" cy="3.5" rx="16" ry="6.4" fill="rgba(0,0,0,.3)"/>' +
    '<rect x="-15" y="-3.8" width="27" height="7.6" rx="3.6" fill="#161d2a"/>' +
    '<rect x="-15" y="-3.8" width="27" height="2.6" rx="1.3" fill="#38445c"/>' +
    head(-9.5, helmPillion) + head(0.5, helmRider) +
    '<rect x="4.6" y="-6.4" width="2.6" height="12.8" rx="1.3" fill="#4a5568"/>' +
    '<rect x="10.6" y="-2" width="3" height="4" rx="1.2" fill="#fff3c4"/>' +
    '</g>';
}

/* รถบรรทุกพ่วง  หัวลากอยู่ด้านหัว ไฟเลี้ยวกะพริบอยู่มุมที่กำลังจะกวาดไป */
function tdTruck(x, y, a, s, signal) {
  s = s || 1;
  var sig = signal
    ? '<circle cx="30" cy="-14" r="3.6" fill="#f6a723">' +
      '<animate attributeName="opacity" values="1;.1;1" dur=".7s" repeatCount="indefinite"/></circle>' +
      '<circle cx="-44" cy="-14" r="3.6" fill="#f6a723">' +
      '<animate attributeName="opacity" values="1;.1;1" dur=".7s" repeatCount="indefinite"/></circle>' : '';
  return '<g transform="translate(' + x + ',' + y + ') rotate(' + a + ') scale(' + s + ')">' +
    '<rect x="-50" y="-14" width="82" height="28" rx="3" fill="rgba(0,0,0,.34)" transform="translate(4,5)"/>' +
    '<rect x="-50" y="-14" width="64" height="28" rx="2" fill="#8d97a6"/>' +
    '<rect x="-50" y="-14" width="64" height="10" rx="2" fill="#dde3ec"/>' +
    '<rect x="-50" y="8" width="64" height="6" fill="rgba(0,0,0,.22)"/>' +
    '<rect x="14" y="-13" width="18" height="26" rx="3" fill="#5c6472"/>' +
    '<rect x="14" y="-13" width="18" height="9" rx="3" fill="#7c8593"/>' +
    '<path d="M26 -9.5 L31 -6.5 L31 6.5 L26 9.5 Z" fill="rgba(226,240,255,.8)"/>' +
    '<rect x="30" y="-10" width="3.4" height="4" rx="1.4" fill="#fff3c4"/>' +
    '<rect x="30" y="6" width="3.4" height="4" rx="1.4" fill="#fff3c4"/>' + sig +
    '</g>';
}

/* ------------------------------------------------------------
   พื้นถนน  ขอบทางมีด้านบนสว่างและมีเงาตกลงบนผิวถนน จึงดูนูนขึ้นมา
   ------------------------------------------------------------ */
function tdRoadH(p, cy, half) {
  var y1 = cy - half, y2 = cy + half;
  return '<rect x="-4" y="' + y1 + '" width="408" height="' + (half * 2) + '" fill="' + p.road + '"/>' +
    '<rect x="-4" y="' + y1 + '" width="408" height="6" fill="rgba(0,0,0,.28)"/>' +
    '<rect x="-4" y="' + (y2 - 4) + '" width="408" height="4" fill="rgba(0,0,0,.14)"/>' +
    '<rect x="-4" y="' + (y1 - 7) + '" width="408" height="7" fill="' + p.kerb + '"/>' +
    '<rect x="-4" y="' + (y1 - 7) + '" width="408" height="2.4" fill="rgba(255,255,255,.35)"/>' +
    '<rect x="-4" y="' + y2 + '" width="408" height="7" fill="' + p.kerb + '"/>' +
    '<rect x="-4" y="' + y2 + '" width="408" height="2.4" fill="rgba(255,255,255,.35)"/>';
}
function tdRoadV(p, cx, half, y1, y2) {
  y1 = (y1 === undefined) ? -4 : y1;
  y2 = (y2 === undefined) ? 264 : y2;
  var h = y2 - y1, x1 = cx - half, x2 = cx + half;
  return '<rect x="' + x1 + '" y="' + y1 + '" width="' + (half * 2) + '" height="' + h + '" fill="' + p.road + '"/>' +
    '<rect x="' + x1 + '" y="' + y1 + '" width="6" height="' + h + '" fill="rgba(0,0,0,.28)"/>' +
    '<rect x="' + (x2 - 4) + '" y="' + y1 + '" width="4" height="' + h + '" fill="rgba(0,0,0,.14)"/>' +
    '<rect x="' + (x1 - 7) + '" y="' + y1 + '" width="7" height="' + h + '" fill="' + p.kerb + '"/>' +
    '<rect x="' + (x1 - 7) + '" y="' + y1 + '" width="2.4" height="' + h + '" fill="rgba(255,255,255,.35)"/>' +
    '<rect x="' + x2 + '" y="' + y1 + '" width="7" height="' + h + '" fill="' + p.kerb + '"/>' +
    '<rect x="' + x2 + '" y="' + y1 + '" width="2.4" height="' + h + '" fill="rgba(255,255,255,.35)"/>';
}

/* ลบขอบทางที่พาดผ่านปากทางแยก ไม่งั้นจะกลายเป็นถนนตันสองสาย */
function tdCross(p, cx, cy, vh, hh) {
  return '<rect x="' + (cx - vh) + '" y="' + (cy - hh - 8) + '" width="' + (vh * 2) + '" height="' + (hh * 2 + 16) + '" fill="' + p.road + '"/>' +
    '<rect x="' + (cx - vh - 8) + '" y="' + (cy - hh) + '" width="' + (vh * 2 + 16) + '" height="' + (hh * 2) + '" fill="' + p.road + '"/>';
}
/* ปากทางแยกตัวที  ถนนรองมาชนถนนใหญ่แล้วจบ ไม่ได้ทะลุอีกฝั่ง */
function tdMouth(p, cx, vh, y, h) {
  return '<rect x="' + (cx - vh) + '" y="' + y + '" width="' + (vh * 2) + '" height="' + h + '" fill="' + p.road + '"/>';
}

function tdDashH(p, cy, x1, x2) {
  return '<line x1="' + x1 + '" y1="' + cy + '" x2="' + x2 + '" y2="' + cy + '" stroke="' + p.line +
    '" stroke-width="2.4" stroke-dasharray="14 12" opacity=".85"/>';
}
function tdDashV(p, cx, y1, y2) {
  return '<line x1="' + cx + '" y1="' + y1 + '" x2="' + cx + '" y2="' + y2 + '" stroke="' + p.line +
    '" stroke-width="2.4" stroke-dasharray="14 12" opacity=".85"/>';
}
function tdSolidH(p, cy, x1, x2, w) {
  return '<line x1="' + x1 + '" y1="' + cy + '" x2="' + x2 + '" y2="' + cy + '" stroke="' + p.line +
    '" stroke-width="' + (w || 2.6) + '" opacity=".92"/>';
}
/* เส้นให้ทาง  เส้นขาวขวางปากทางรอง บอกว่าต้องหยุดดูก่อนออก */
function tdGiveWay(p, x1, x2, y) {
  return '<rect x="' + x1 + '" y="' + y + '" width="' + (x2 - x1) + '" height="4.5" fill="' + p.line + '" opacity=".92"/>';
}
/* ทางม้าลาย  แถบขาวขวางถนนตามแนวที่คนเดินข้าม */
function tdZebra(p, x, y1, y2, n) {
  var out = '', i;
  for (i = 0; i < n; i++) {
    out += '<rect x="' + (x + i * 11) + '" y="' + y1 + '" width="6.5" height="' + (y2 - y1) +
      '" fill="' + p.line + '" opacity=".95"/>';
  }
  return out;
}
/* เส้นทแยงเหลืองกลางแยก  ห้ามหยุดคาไว้ในกรอบนี้ */
function tdYellowBox(x1, y1, x2, y2) {
  var out = '<rect x="' + x1 + '" y="' + y1 + '" width="' + (x2 - x1) + '" height="' + (y2 - y1) +
    '" fill="none" stroke="#e8c33a" stroke-width="2.4" opacity=".9"/>', i;
  for (i = -6; i < 10; i++) {
    out += '<line x1="' + (x1 + i * 16) + '" y1="' + y1 + '" x2="' + (x1 + i * 16 + (y2 - y1)) + '" y2="' + y2 +
      '" stroke="#e8c33a" stroke-width="1.8" opacity=".55" clip-path="url(#tdBoxClip)"/>';
  }
  return '<g><clipPath id="tdBoxClip"><rect x="' + x1 + '" y="' + y1 + '" width="' + (x2 - x1) +
    '" height="' + (y2 - y1) + '"/></clipPath>' + out + '</g>';
}

/* ลูกศรกำกับทิศทางของเลน  ไม่ได้มีไว้สวยงาม มีไว้ให้คนตรวจงานเห็นทันทีว่าเลนไหนไปทางไหน
   ถ้าวันหนึ่งมีคนแก้แล้ววาดรถผิดเลน ลูกศรนี้จะขัดกับตัวรถให้เห็นเอง */
function tdLaneArrow(x, y, dir, c) {
  var a = { e: 0, w: 180, n: -90, s: 90 }[dir];
  return '<g transform="translate(' + x + ',' + y + ') rotate(' + a + ')" opacity=".5">' +
    '<path d="M-8 0H6M2 -4.4l4 4.4-4 4.4" fill="none" stroke="' + c + '" stroke-width="1.9" ' +
    'stroke-linecap="round" stroke-linejoin="round"/></g>';
}

/* ลูกศรที่ทาไว้บนผิวถนน  บอกว่าช่องนั้นไปทางไหนได้บ้าง
   ============================================================
   วาดสำหรับรถที่วิ่งไปทางขวาของภาพ ซึ่งเป็นทิศของรถทุกคันในไฟล์ชุดนี้
     straight  ตรงไป      หัวลูกศรชี้ไปทางขวา
     left      เลี้ยวซ้าย  ก้านไปทางขวาแล้วเบนขึ้นบน หัวชี้ขึ้น
     right     เลี้ยวขวา   ก้านไปทางขวาแล้วเบนลงล่าง หัวชี้ลง

   ขึ้นบนคือเลี้ยวซ้ายเพราะรถวิ่งไปทางขวา มือซ้ายของคนขับจึงชี้ขึ้นบนของภาพ
   อย่าวาดลูกศรพวกนี้ด้วยมือทีละเส้นอีก เคยวาดแล้วหันผิดไปเก้าสิบองศาทั้งสองที่
   เพราะเผลอคิดว่ารถวิ่งขึ้นบน ซึ่งเป็นทิศที่ไม่มีรถคันไหนในไฟล์นี้วิ่งเลย */
function tdRoadArrow(x, y, kind, col) {
  var d = kind === 'left'
    ? 'M-17 9 L-2 9 Q8 9 8 -1 L8 -9 M2 -3 l6 -6 6 6'
    : kind === 'right'
      ? 'M-17 -9 L-2 -9 Q8 -9 8 1 L8 9 M2 3 l6 6 6 -6'
      : 'M-17 0 L8 0 M2 -6 l6 6 -6 6';
  return '<g transform="translate(' + x + ',' + y + ')" opacity=".95">' +
    '<path d="' + d + '" fill="none" stroke="' + col + '" stroke-width="3.6" ' +
    'stroke-linecap="round" stroke-linejoin="round"/></g>';
}

/* อาคารมองจากมุมสูง  มีผนังด้านที่หันเข้าหาเราให้เห็น จึงอ่านเป็นก้อนไม่ใช่แผ่น */
function tdBuilding(x, y, w, h, roof, wall) {
  var d = 9;
  return '<g transform="translate(' + x + ',' + y + ')">' +
    '<rect x="' + (-w / 2 + 5) + '" y="' + (-h / 2 + 6) + '" width="' + w + '" height="' + (h + d) + '" rx="3" fill="rgba(0,0,0,.32)"/>' +
    '<rect x="' + (-w / 2) + '" y="' + (h / 2 - 2) + '" width="' + w + '" height="' + d + '" rx="2" fill="' + tdShade(wall, .6) + '"/>' +
    '<rect x="' + (-w / 2) + '" y="' + (-h / 2) + '" width="' + w + '" height="' + h + '" rx="3" fill="' + roof + '"/>' +
    '<rect x="' + (-w / 2) + '" y="' + (-h / 2) + '" width="' + w + '" height="' + (h * 0.34) + '" rx="3" fill="rgba(255,255,255,.14)"/>' +
    '</g>';
}

/* ต้นไม้ริมทาง  เงาช่วยบอกว่าของสูงกว่าพื้น ซึ่งเป็นตัวทำให้ภาพดูเป็นสามมิติ */
function tdTree(x, y, r) {
  return '<g transform="translate(' + x + ',' + y + ')">' +
    '<ellipse cx="' + (r * 0.5) + '" cy="' + (r * 0.55) + '" rx="' + r + '" ry="' + (r * 0.8) + '" fill="rgba(0,0,0,.3)"/>' +
    '<circle r="' + r + '" fill="#2f5d2b"/>' +
    '<circle cx="' + (-r * 0.3) + '" cy="' + (-r * 0.3) + '" r="' + (r * 0.62) + '" fill="#3d7735"/>' +
    '</g>';
}

/* คนเดินเท้า  วงรีไหล่กับวงกลมหัว พอให้รู้ว่าเป็นคน ไม่ใช่สิ่งของ */
function tdPerson(x, y, col) {
  return '<g transform="translate(' + x + ',' + y + ')">' +
    '<ellipse cx="2" cy="3" rx="7" ry="4.4" fill="rgba(0,0,0,.3)"/>' +
    '<ellipse rx="6.4" ry="4.6" fill="' + col + '"/>' +
    '<circle r="3.4" fill="#e0a878"/></g>';
}

/* เสาสัญญาณไฟ  on คือดวงที่ติด รับค่า red amber green */
function tdSignal(x, y, on) {
  var c = function (k, lit, dim) { return on === k ? lit : dim; };
  return '<g transform="translate(' + x + ',' + y + ')">' +
    '<ellipse cx="5" cy="7" rx="15" ry="7" fill="rgba(0,0,0,.32)"/>' +
    '<rect x="-11" y="-34" width="22" height="42" rx="5" fill="#171c25"/>' +
    '<rect x="-11" y="-34" width="22" height="12" rx="5" fill="#2a323f"/>' +
    '<circle cx="0" cy="-25" r="5.4" fill="' + c('red', '#ff4d4d', '#3a2020') + '"/>' +
    '<circle cx="0" cy="-11" r="5.4" fill="' + c('amber', '#f6c445', '#3a3320') + '">' +
    (on === 'amber' ? '<animate attributeName="opacity" values="1;.28;1" dur="1s" repeatCount="indefinite"/>' : '') +
    '</circle>' +
    '<circle cx="0" cy="3" r="5.4" fill="' + c('green', '#4ed07a', '#1e3324') + '"/></g>';
}

/* ป้ายบังคับทรงกลมขอบแดง เช่น ป้ายจำกัดความเร็ว */
/* ไม่มีฉากไหนเรียกตัวนี้แล้ว ตั้งใจเก็บไว้พร้อมเหตุผล
   เดิมใช้วาดป้ายจราจรลงในฉาก แล้วพบว่าป้ายคือการเฉลยคำตอบ
   เพราะคำถามเกือบทุกข้อในเกมนี้ถามว่ากติกาคืออะไร ไม่ได้ถามว่าป้ายเขียนว่าอะไร
   พอมีป้ายอยู่ในภาพ ผู้เล่นก็อ่านคำตอบจากป้ายโดยไม่ต้องรู้กติกาเลย
   ถ้าจะเอากลับมาใช้ ต้องเป็นข้อที่ถามความหมายของป้ายนั้นโดยตรงเท่านั้น */
function tdSignRound(x, y, txt) {
  return '<g transform="translate(' + x + ',' + y + ')">' +
    '<ellipse cx="4" cy="6" rx="14" ry="7" fill="rgba(0,0,0,.32)"/>' +
    '<circle r="14" fill="#f4f6f8"/><circle r="14" fill="none" stroke="#cf2b26" stroke-width="4"/>' +
    '<text y="4.6" text-anchor="middle" font-family="system-ui,sans-serif" font-size="12" ' +
    'font-weight="700" fill="#1b2430">' + txt + '</text></g>';
}

/* ลำแสงไฟหน้า  ใช้กับคำถามเรื่องไฟสูงไฟต่ำ ไฟสูงยาวและกว้างกว่ามาก */
function tdBeam(x, y, dir, len, spread, op) {
  var s = dir === 'w' ? -1 : 1;
  return '<path d="M' + x + ' ' + (y - 6) + ' L' + (x + s * len) + ' ' + (y - spread) +
    ' L' + (x + s * len) + ' ' + (y + spread) + ' L' + x + ' ' + (y + 6) + ' Z" ' +
    'fill="#fff3c4" opacity="' + op + '"/>';
}

/* ------------------------------------------------------------
   ลูกศรเส้นทางที่รถตั้งใจจะไป  ค่อย ๆ ลากออกมาแล้ววนใหม่
   ------------------------------------------------------------
   ลูกศรบอกเจตนา ไม่ใช่เครื่องหมายบนผิวถนน จึงต้องบางกว่าเลนและต้องหายไปเป็นจังหวะ
   ถ้าค้างอยู่ตลอดเวลา สายตาจะอ่านเป็นสีที่ทาไว้บนถนนจริง ซึ่งสื่อผิดทันที
   วนเป็นรอบยังทำให้เห็นลำดับด้วยว่าใครมาก่อนใคร เพราะสองเส้นเริ่มไม่พร้อมกัน */
var TD_LOOP = 4.4;
function tdPath(id, d, col, dash, delay) {
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

/* จุดที่สองเส้นทางไปทับกัน  วงแหวนเต้นให้สายตาไปหยุดตรงนั้น
   เป็นหัวใจของฉากแบบนี้ คือจุดที่ต้องตัดสินใจว่าใครไปก่อน */
function tdConflict(x, y) {
  return '<g transform="translate(' + x + ',' + y + ')">' +
    '<circle r="17" fill="none" stroke="#ffd166" stroke-width="2.5" opacity=".9">' +
    '<animate attributeName="r" values="13;21;13" dur="1.8s" repeatCount="indefinite"/>' +
    '<animate attributeName="opacity" values=".9;.2;.9" dur="1.8s" repeatCount="indefinite"/>' +
    '</circle></g>';
}
/* วงแหวนแดง ใช้ชี้ตัวคนหรือของที่คำถามพูดถึงโดยตรง ไม่ใช่จุดที่รถจะชนกัน */
function tdFocus(x, y, r) {
  r = r || 15;
  return '<g transform="translate(' + x + ',' + y + ')">' +
    '<circle r="' + r + '" fill="none" stroke="#ff4d4d" stroke-width="2.6" opacity=".95">' +
    '<animate attributeName="r" values="' + (r - 4) + ';' + (r + 4) + ';' + (r - 4) + '" dur="1.7s" repeatCount="indefinite"/>' +
    '<animate attributeName="opacity" values=".95;.22;.95" dur="1.7s" repeatCount="indefinite"/>' +
    '</circle></g>';
}

function tdMarker(col) {
  return '<marker id="tdArrow' + col.replace('#', '') + '" viewBox="0 0 10 10" refX="7" refY="5" ' +
    'markerWidth="4.5" markerHeight="4.5" orient="auto">' +
    '<path d="M0 0.5 L9 5 L0 9.5 z" fill="' + col + '"/></marker>';
}

/* วัตถุวิ่งตามเส้นทางที่กำหนด หันหัวตามแนวเส้นเอง */
function tdMove(inner, pathId, dur, begin) {
  return '<g>' + inner +
    '<animateMotion dur="' + dur + 's" begin="' + begin + 's" repeatCount="indefinite" rotate="auto">' +
    '<mpath href="#' + pathId + '"/></animateMotion></g>';
}

/* วิ่งตามเส้นทางแค่บางส่วนแล้วค้างไว้ ก่อนวนใหม่
   part คือสัดส่วนของเส้นทางที่ยอมให้วิ่ง ศูนย์ถึงหนึ่ง
   ใช้กับรถที่กำลังเข้าใกล้จุดตัดสินใจ ซึ่งคือรถเกือบทุกคันในเกมนี้
   ต่างจาก tdMove ที่วิ่งจนจบเส้นทางแล้ววนทันที ซึ่งเหมาะกับรถที่แค่ผ่านมาเฉย ๆ

   ตัวที่ส่งเข้ามาต้องวาดไว้ที่จุดกำเนิด เพราะ animateMotion เป็นคนกำหนดตำแหน่งเอง
   ถ้าวาดไว้ที่พิกัดจริงแล้วส่งเข้ามา รถจะไปโผล่ไกลจากถนนเป็นเท่าตัว */
function tdDrive(inner, pathId, part, dur, begin) {
  part = (part == null) ? 0.55 : part;
  dur = dur || TD_LOOP;
  return '<g>' + inner +
    '<animateMotion dur="' + dur + 's" begin="' + (begin || 0) + 's" repeatCount="indefinite" ' +
    'rotate="auto" calcMode="linear" keyPoints="0;' + part + ';' + part + '" keyTimes="0;0.62;1">' +
    '<mpath href="#' + pathId + '"/></animateMotion></g>';
}

/* ริ้วลมท้ายรถ  บอกว่ารถคันนี้กำลังเคลื่อนที่ แม้ในเฟรมที่มันดูเหมือนอยู่กับที่
   วาดไว้ด้านท้ายของตัวรถ จึงต้องอยู่ในกลุ่มเดียวกับรถเพื่อให้หมุนตามทิศไปด้วย */
function tdStreak(back, n) {
  var out = '<g stroke="#ffffff" stroke-width="2" stroke-linecap="round" opacity=".45">', i;
  for (i = 0; i < (n || 3); i++) {
    var y = -7 + i * 7, len = 10 + (i % 2) * 7;
    out += '<line x1="' + (back - len) + '" y1="' + y + '" x2="' + back + '" y2="' + y + '">' +
      '<animate attributeName="opacity" values=".05;.55;.05" dur="' + (0.5 + i * 0.12) + 's" ' +
      'repeatCount="indefinite"/></line>';
  }
  return out + '</g>';
}

/* เม็ดฝน  n คือความหนาแน่น sp คือความเร็ว ใช้แยกฝนเพิ่งตกกับฝนตกหนัก */
function tdRainDrops(n, sp, op) {
  var out = '';
  for (var i = 0; i < n; i++) {
    var x = 8 + (i * 17) % 392, y = (i * 41) % 252, d = sp + (i % 5) * 0.08;
    out += '<line x1="' + x + '" y1="' + y + '" x2="' + (x - 5) + '" y2="' + (y + 13) + '" stroke="#d8e8f8" ' +
      'stroke-width="1.3" opacity="' + op + '">' +
      '<animate attributeName="y1" values="' + (y - 40) + ';' + (y + 262) + '" dur="' + d + 's" repeatCount="indefinite"/>' +
      '<animate attributeName="y2" values="' + (y - 27) + ';' + (y + 275) + '" dur="' + d + 's" repeatCount="indefinite"/></line>';
  }
  return out;
}

/* ============================================================
   ฉากแต่ละฉาก  หนึ่งฉากผูกกับคำถามเดียว
   ============================================================
   บรรทัดที่ขึ้นต้นว่า คำถาม คือข้อความจริงจากคลังคำถาม คัดลอกมาทั้งประโยค
   ห้ามนำฉากไปใช้กับคำถามอื่นแม้ป้ายหัวข้อจะคล้ายกัน */
var TD_SCENES = {

  /* คำถาม  กำลังเข้าใกล้สี่แยกที่ไม่มีสัญญาณไฟ มีรถกระบะเคลื่อนเข้าแยกมาจากทางขวา
             ชะลอเหมือนจะหยุด และเราถึงแยกก่อนเขาเล็กน้อย คุณจะทำอย่างไร

     เราวิ่งไปทางขวาของภาพ จึงอยู่ครึ่งบนของถนนใหญ่
     กระบะมาจากทางขวาของเรา เมื่อเราหันหน้าไปทางขวาของภาพ ขวามือคือด้านล่างของภาพ
     กระบะจึงขึ้นมาจากด้านล่าง วิ่งขึ้นเหนือ และชิดซ้ายคือครึ่งซ้ายของถนนรอง
     เส้นทางสองเส้นตัดกันหนึ่งจุด ตรงที่เขากำลังจะโผล่เข้ามาในเลนของเราพอดี */
  junction: function (p) {
    var cy = 112, cx = 212, hh = 44, vh = 30, eb = cy - 22, wb = cy + 22, nb = cx - 15;
    return tdRoadH(p, cy, hh) + tdRoadV(p, cx, vh) + tdCross(p, cx, cy, vh, hh) +
      tdDashH(p, cy, -4, cx - vh) + tdDashH(p, cy, cx + vh, 404) +
      tdDashV(p, cx, cy + hh, 264) + tdDashV(p, cx, -4, cy - hh) +
      tdGiveWay(p, cx - vh + 3, cx, cy + hh + 10) +
      tdLaneArrow(64, eb, 'e', p.line) + tdLaneArrow(348, eb, 'e', p.line) +
      tdLaneArrow(64, wb, 'w', p.line) + tdLaneArrow(348, wb, 'w', p.line) +
      tdLaneArrow(nb, 230, 'n', p.line) + tdLaneArrow(cx + 15, 230, 's', p.line) +
      tdTree(46, 28, 13) + tdTree(360, 224, 12) +
      tdPath('tdpA', 'M26 ' + eb + ' L336 ' + eb, TD_BLUE, 312, .4) +
      tdPath('tdpB', 'M' + nb + ' 240 L' + nb + ' ' + (cy + hh + 22), TD_RED, 82, 1.9) +
      tdConflict(nb, eb) +
      tdDrive(tdCar(0, 0, 0, TD_RED, 1, true), 'tdpB', .5, TD_LOOP, 0) +
      tdDrive(tdMoto(0, 0, 0, 1, TD_BLUE) + tdStreak(-15, 3), 'tdpA', .58, TD_LOOP, 0);
  },

  /* คำถาม  กำลังเข้าใกล้ทางแยก สัญญาณไฟเปลี่ยนเป็นสีเหลือง และคุณยังห่างจากเส้นหยุดพอสมควร

     เราวิ่งไปทางขวาของภาพ จึงอยู่ครึ่งบนของถนน และยังอยู่ไกลจากเส้นหยุด
     ระยะห่างเป็นใจความของคำถาม เส้นทางจึงลากไปจบที่เส้นหยุด ไม่ใช่เลยแยกไป */
  amber: function (p) {
    var cy = 118, cx = 226, hh = 44, vh = 32, eb = cy - 22, wb = cy + 22, stop = cx - vh - 14;
    return tdRoadH(p, cy, hh) + tdRoadV(p, cx, vh) + tdCross(p, cx, cy, vh, hh) +
      tdDashH(p, cy, -4, cx - vh) + tdDashH(p, cy, cx + vh, 404) +
      tdLaneArrow(60, eb, 'e', p.line) + tdLaneArrow(348, eb, 'e', p.line) +
      tdLaneArrow(60, wb, 'w', p.line) + tdLaneArrow(348, wb, 'w', p.line) +
      '<rect x="' + stop + '" y="' + (cy - hh) + '" width="5" height="' + hh + '" fill="' + p.line + '" opacity=".92"/>' +
      tdSignal(stop - 10, cy - hh - 16, 'amber') +
      tdTree(56, 30, 13) + tdTree(340, 226, 12) +
      tdPath('tdpA', 'M40 ' + eb + ' L' + (stop - 10) + ' ' + eb, TD_BLUE, 190, .6) +
      tdConflict(stop - 2, eb) +
      tdDrive(tdCar(0, 0, 0, TD_BLUE, 1, false) + tdStreak(-22, 3), 'tdpA', .72, TD_LOOP, 0);
  },

  /* คำถาม  จะกลับรถบนถนนสายหลัก มีรถจักรยานยนต์วิ่งมาไกล ๆ ดูเหมือนยังพอมีเวลา

     เราวิ่งไปทางขวาของภาพ อยู่ครึ่งบน จะกลับรถลงไปเข้าเลนครึ่งล่างซึ่งวิ่งไปทางซ้าย
     จักรยานยนต์ที่วิ่งมาคือรถในเลนสวน จึงมาจากขวามือของภาพ วิ่งไปทางซ้าย
     ตรวจด้วยกฎมือซ้ายได้ว่าเขาผ่านทางขวามือของเราจริง */
  uturn: function (p) {
    var cy = 118, hh = 52, eb = cy - 26, wb = cy + 26, g1 = 186, g2 = 252;
    return tdRoadH(p, cy, hh) +
      '<rect x="-4" y="' + (cy - 8) + '" width="' + (g1 + 4) + '" height="16" rx="4" fill="' + p.kerb + '"/>' +
      '<rect x="-4" y="' + (cy - 8) + '" width="' + (g1 + 4) + '" height="5" rx="3" fill="rgba(255,255,255,.34)"/>' +
      '<rect x="' + g2 + '" y="' + (cy - 8) + '" width="' + (404 - g2) + '" height="16" rx="4" fill="' + p.kerb + '"/>' +
      '<rect x="' + g2 + '" y="' + (cy - 8) + '" width="' + (404 - g2) + '" height="5" rx="3" fill="rgba(255,255,255,.34)"/>' +
      tdLaneArrow(64, eb, 'e', p.line) + tdLaneArrow(330, eb, 'e', p.line) +
      tdLaneArrow(64, wb, 'w', p.line) + tdLaneArrow(330, wb, 'w', p.line) +
      tdTree(36, 26, 13) + tdTree(300, 232, 12) + tdTree(90, 236, 11) +
      tdPath('tdpA', 'M132 ' + eb + ' L196 ' + eb + ' Q226 ' + eb + ' 226 ' + cy +
        ' Q226 ' + wb + ' 196 ' + wb + ' L64 ' + wb, TD_BLUE, 290, 1.7) +
      tdPath('tdpB', 'M386 ' + wb + ' L246 ' + wb, TD_RED, 146, .4) +
      tdConflict(214, wb) +
      tdMove(tdMoto(0, 0, 0, 1, TD_RED), 'tdpB', 4.6, 0) +
      tdDrive(tdCar(0, 0, 0, TD_BLUE, 1, true), 'tdpA', .2, TD_LOOP, 0);
  },

  /* คำถาม  ขี่จักรยานยนต์อยู่ข้างซ้ายของรถบรรทุกพ่วง รถบรรทุกเปิดไฟเลี้ยวซ้าย

     ทั้งคู่วิ่งไปทางขวาของภาพ จึงอยู่ครึ่งบนของถนน
     ข้างซ้ายของรถบรรทุก เมื่อรถบรรทุกหันหน้าไปทางขวาของภาพ ซ้ายมือคือด้านบนของภาพ
     เราจึงอยู่เหนือรถบรรทุก ถูกบีบอยู่ระหว่างตัวรถกับขอบทาง
     ถนนที่เขาจะเลี้ยวซ้ายเข้าไป จึงต้องแยกขึ้นไปด้านบน และกวาดทับที่ที่เราอยู่พอดี
     นี่คือเหตุผลที่ต้องวาดให้ถูกด้าน ถ้าวาดกลับด้าน จุดตายจะหายไปทั้งจุด */
  truck: function (p) {
    var cy = 130, hh = 48, eb = cy - 24, wb = cy + 24, sx = 300, vh = 30, kerb = cy - hh - 7;
    return tdRoadV(p, sx, vh, -4, cy - hh) + tdRoadH(p, cy, hh) +
      tdMouth(p, sx, vh, kerb, 9) +
      tdDashH(p, cy, -4, sx - vh) + tdDashH(p, cy, sx + vh, 404) +
      tdDashV(p, sx, -4, cy - hh) +
      tdLaneArrow(46, eb, 'e', p.line) + tdLaneArrow(46, wb, 'w', p.line) +
      tdLaneArrow(sx - 15, 40, 'n', p.line) + tdLaneArrow(sx + 15, 40, 's', p.line) +
      tdBuilding(120, 42, 92, 44, '#7d8796', '#5c646f') +
      tdTree(238, 40, 12) + tdTree(120, 226, 13) +
      tdDrive(tdTruck(0, 0, 0, 1, true), 'tdpT', .32, TD_LOOP, 0) +
      tdPath('tdpT', 'M238 ' + (eb + 8) + ' L262 ' + (eb + 8) + ' Q288 ' + (eb + 8) + ' 288 ' + (eb - 20) + ' L288 8', TD_RED, 210, 1.7) +
      tdPath('tdpM', 'M206 ' + (eb - 18) + ' L318 ' + (eb - 18), TD_BLUE, 112, .5) +
      tdConflict(288, eb - 18) +
      /* กรวยจุดบอดของคนขับ มุมซ้ายหน้าของหัวลากคือที่ที่มองไม่เห็นเลย */
      '<g opacity=".2"><path d="M228 ' + (eb + 2) + ' L318 ' + (eb - 34) + ' L318 ' + (eb + 2) + ' Z" fill="#ff3b30"/></g>' +
      tdDrive(tdMoto(0, 0, 0, 1, TD_BLUE) + tdStreak(-15, 3), 'tdpM', .42, TD_LOOP, 0);
  },

  /* คำถาม  ฝนเพิ่งตกได้ไม่กี่นาทีหลังจากแดดออกมาหลายวัน ถนนเริ่มเปียก คุณควรทำอย่างไร

     ใจความคือนาทีแรกของฝนลื่นที่สุด เพราะน้ำผสมกับคราบน้ำมันที่สะสมมาหลายวัน
     ภาพจึงต้องเห็นผิวถนนเป็นมันวาว และเห็นว่าเราตามคันหน้าใกล้เกินกว่าจะเบรกทัน
     ทั้งสองคันวิ่งไปทางขวาของภาพ จึงอยู่ครึ่งบนของถนน */
  rain: function (p) {
    var cy = 116, hh = 46, eb = cy - 23, wb = cy + 23;
    return tdRoadH(p, cy, hh) + tdDashH(p, cy, -4, 404) +
      '<rect x="-4" y="' + (cy - hh) + '" width="408" height="' + (hh * 2) + '" fill="#9fc4e8" opacity=".14"/>' +
      '<ellipse cx="96" cy="' + (eb + 12) + '" rx="46" ry="8" fill="#cfe4f7" opacity=".2"/>' +
      '<ellipse cx="268" cy="' + (wb - 10) + '" rx="54" ry="9" fill="#cfe4f7" opacity=".18"/>' +
      '<ellipse cx="352" cy="' + (eb + 6) + '" rx="38" ry="7" fill="#cfe4f7" opacity=".16"/>' +
      tdLaneArrow(50, eb, 'e', p.line) + tdLaneArrow(340, wb, 'w', p.line) +
      tdTree(30, 26, 12) + tdTree(370, 236, 12) +
      tdDrive(tdCar(0, 0, 0, TD_RED, 1, true), 'tdpLead', .62, TD_LOOP, 0) +
      tdDrive(tdMoto(0, 0, 0, 1, TD_BLUE) + tdStreak(-15, 3), 'tdpFollow', .62, TD_LOOP, 0) +
      /* คานวัดระยะตามหลัง สั้นจนเห็นได้ว่าไม่พอกับถนนเปียก */
      '<g stroke="#ffd166" stroke-width="2.2" opacity=".95">' +
      '<line x1="212" y1="' + (cy + 34) + '" x2="252" y2="' + (cy + 34) + '"/>' +
      '<line x1="212" y1="' + (cy + 29) + '" x2="212" y2="' + (cy + 39) + '"/>' +
      '<line x1="252" y1="' + (cy + 29) + '" x2="252" y2="' + (cy + 39) + '"/></g>' +
      tdConflict(238, eb) +
      '<path id="tdpLead" d="M232 ' + eb + ' L392 ' + eb + '" fill="none" opacity="0"/>' +
      '<path id="tdpFollow" d="M156 ' + eb + ' L316 ' + eb + '" fill="none" opacity="0"/>' +
      tdRainDrops(22, .9, '.5');
  },

  /* คำถาม  ฝนตกหนักจนมองข้างหน้าได้ไม่ถึงห้าสิบเมตร มีรถบรรทุกวิ่งช้าอยู่ข้างหน้า

     ใจความคือระยะมองเห็นสั้นกว่าระยะเบรก ภาพจึงต้องมีม่านฝนบังข้างหน้าจริง
     ไม่ใช่แค่วาดเม็ดฝนเยอะขึ้น ถ้ายังเห็นถนนโล่งไปถึงขอบภาพ คำถามกับภาพจะขัดกันเอง */
  rainheavy: function (p) {
    var cy = 116, hh = 46, eb = cy - 23, wb = cy + 23;
    return tdRoadH(p, cy, hh) + tdDashH(p, cy, -4, 404) +
      '<rect x="-4" y="' + (cy - hh) + '" width="408" height="' + (hh * 2) + '" fill="#9fc4e8" opacity=".2"/>' +
      tdLaneArrow(44, eb, 'e', p.line) + tdLaneArrow(120, wb, 'w', p.line) +
      tdTree(28, 28, 12) + tdTree(92, 234, 12) +
      tdTruck(268, eb + 2, 0, 1, false) +
      /* ละอองน้ำที่ฟุ้งจากล้อรถบรรทุก เป็นสิ่งที่บังตาจริงในฝนหนัก */
      '<ellipse cx="216" cy="' + (eb + 2) + '" rx="30" ry="17" fill="#e6f0fa" opacity=".3">' +
      '<animate attributeName="opacity" values=".3;.12;.3" dur="1.1s" repeatCount="indefinite"/></ellipse>' +
      tdDrive(tdMoto(0, 0, 0, 1, TD_BLUE) + tdStreak(-15, 3), 'tdpA', .74, TD_LOOP, 0) +
      tdPath('tdpA', 'M140 ' + eb + ' L206 ' + eb, TD_BLUE, 70, .6) +
      tdConflict(220, eb) +
      tdRainDrops(40, .62, '.75') +
      /* ม่านฝน  ทึบขึ้นเรื่อย ๆ ไปทางขวา คือขอบระยะมองเห็นที่คำถามพูดถึง */
      '<rect x="230" y="-4" width="174" height="268" fill="url(#tdFog)"/>';
  },

  /* คำถาม  จะขี่จักรยานยนต์ไปร้านค้าปากซอย ห่างไม่ถึงหนึ่งกิโลเมตร

     ใจความคือใกล้นิดเดียว ภาพจึงต้องเห็นบ้าน เห็นร้าน และเห็นว่าระยะสั้นจริง
     หมวกยังแขวนอยู่ที่บ้าน คือสิ่งที่คำถามกำลังล่อให้ตอบว่าไม่ต้องใส่
     เราขี่ขึ้นเหนือออกจากซอย ชิดซ้ายจึงอยู่ครึ่งซ้ายของซอย */
  helmet: function (p) {
    var cy = 92, cx = 182, hh = 40, vh = 26, eb = cy - 20, wb = cy + 20, nb = cx - 13;
    return tdRoadV(p, cx, vh, cy + hh, 264) + tdRoadH(p, cy, hh) +
      tdMouth(p, cx, vh, cy + hh, 9) +
      tdDashH(p, cy, -4, 404) +
      tdGiveWay(p, cx - vh + 3, cx, cy + hh + 12) +
      tdLaneArrow(62, eb, 'e', p.line) + tdLaneArrow(330, eb, 'e', p.line) +
      tdLaneArrow(62, wb, 'w', p.line) + tdLaneArrow(330, wb, 'w', p.line) +
      tdLaneArrow(nb, 238, 'n', p.line) + tdLaneArrow(cx + 13, 238, 's', p.line) +
      tdBuilding(cx + 66, cy + 62, 70, 40, '#b4784a', '#7d5232') +
      '<rect x="' + (cx + 34) + '" y="' + (cy + 46) + '" width="64" height="9" rx="3" fill="#c0562f"/>' +
      tdBuilding(cx - 74, 214, 76, 46, '#8d6b4a', '#61472f') +
      '<g transform="translate(' + (cx - 30) + ',206)">' +
      '<ellipse cx="3" cy="4" rx="10" ry="5" fill="rgba(0,0,0,.3)"/>' +
      '<circle r="9.5" fill="#f0b429"/><path d="M-9.5 2a9.5 9.5 0 0 0 19 0z" fill="#c98f16"/>' +
      '<animateTransform attributeName="transform" type="rotate" values="-7 0 0;7 0 0;-7 0 0" ' +
      'dur="2.6s" repeatCount="indefinite" additive="sum"/></g>' +
      tdTree(44, 210, 13) + tdTree(356, 30, 12) +
      tdPath('tdpA', 'M' + nb + ' 224 L' + nb + ' ' + (cy + hh + 26), TD_BLUE, 66, 1.5) +
      tdPath('tdpB', 'M388 ' + wb + ' L44 ' + wb, TD_RED, 344, .4) +
      tdMove(tdCar(0, 0, 0, TD_RED, 1, false), 'tdpB', 6.4, 0) +
      tdDrive(tdMoto(0, 0, 0, 1, TD_BLUE, ''), 'tdpA', .5, TD_LOOP, 0);
  },

  /* คำถาม  คนที่จะซ้อนท้ายไม่ยอมสวมหมวก บอกว่าไปแค่ในหมู่บ้าน อึดอัดและทำผมเสีย

     ฉากนี้ไม่มีใครต้องให้ทางใคร จึงไม่มีจุดตัดและไม่มีรถคันที่สอง
     สิ่งเดียวที่ต้องเห็นชัดคือหัวสองหัว หัวหน้ามีหมวก หัวหลังไม่มี
     วงแหวนแดงจึงไปอยู่ที่หัวคนซ้อน ไม่ใช่ที่กลางถนน */
  pillion: function (p) {
    var cy = 152, hh = 36, eb = cy - 18, wb = cy + 18;
    return tdRoadH(p, cy, hh) + tdDashH(p, cy, -4, 404) +
      tdLaneArrow(60, eb, 'e', p.line) + tdLaneArrow(336, eb, 'e', p.line) +
      tdLaneArrow(60, wb, 'w', p.line) + tdLaneArrow(336, wb, 'w', p.line) +
      tdBuilding(74, 52, 96, 52, '#9a7350', '#6c4e34') +
      tdBuilding(214, 46, 78, 44, '#7d8796', '#5c646f') +
      tdBuilding(330, 54, 84, 48, '#8f8a5e', '#635f40') +
      tdTree(146, 88, 13) + tdTree(282, 90, 12) + tdTree(40, 218, 13) +
      tdMotoPair(182, eb, 0, 1.35, '#f0b429', '') +
      tdFocus(182 - 12.8, eb, 14) +
      '<g transform="translate(' + (182 + 1.4) + ',' + eb + ')">' +
      '<circle r="13" fill="none" stroke="#5ad27a" stroke-width="2.2" opacity=".8"/></g>' +
      tdPath('tdpA', 'M206 ' + eb + ' L352 ' + eb, TD_BLUE, 148, 1.4);
  },

  /* คำถาม  ขับกลางคืนบนทางตรงยาว เริ่มรู้สึกตาหนัก แต่เหลืออีกราวยี่สิบกิโลเมตรก็ถึงบ้าน

     ใจความคือรถเริ่มส่ายออกนอกแนวโดยที่คนขับไม่รู้ตัว
     เส้นทางจึงต้องเป็นเส้นคดที่ไหลข้ามเส้นแบ่งกลางไปหาเลนสวน
     เราวิ่งไปทางขวาของภาพ อยู่ครึ่งบน รถสวนอยู่ครึ่งล่างและวิ่งไปทางซ้าย */
  drowsy: function (p) {
    var cy = 120, hh = 46, eb = cy - 23, wb = cy + 23;
    return tdRoadH(p, cy, hh) + tdDashH(p, cy, -4, 404) +
      tdLaneArrow(40, eb, 'e', p.line) + tdLaneArrow(360, wb, 'w', p.line) +
      tdTree(28, 30, 12) + tdTree(210, 24, 11) + tdTree(330, 236, 12) +
      tdPath('tdpA', 'M24 ' + eb + ' C110 ' + eb + ' 150 ' + (eb + 4) + ' 214 ' + (cy + 2) +
        ' C268 ' + (cy + 8) + ' 300 ' + (eb + 6) + ' 388 ' + (eb + 2), TD_BLUE, 392, .8) +
      tdConflict(232, cy + 4) +
      tdMove(tdCar(0, 0, 0, TD_BLUE, 1, false), 'tdpA', 8.4, 0) +
      tdPath('tdpB', 'M392 ' + wb + ' L8 ' + wb, TD_RED, 384, .3) +
      tdMove(tdCar(0, 0, 0, TD_RED, 1, false), 'tdpB', 7, 0);
  },

  /* คำถาม  ดื่มเบียร์ไปสองแก้วในงานเลี้ยง อีกสักพักจะขี่จักรยานยนต์กลับบ้าน ระยะทางไม่ไกล

     ยังไม่ได้ออกรถ การตัดสินใจอยู่ตรงนี้ รถจึงต้องจอดนิ่งอยู่ในลานไม่ใช่วิ่งอยู่บนถนน
     ถ้าออกไปแล้วจะวิ่งไปทางขวาของภาพ ซึ่งชิดซ้ายคือขอบบนของถนน
     รถจึงจอดหันหน้าไปทางขวาอยู่ริมทางฝั่งบน
     เส้นทางกลับบ้านวาดเป็นเส้นคดไว้แล้ว เพราะนั่นคือสิ่งที่จะเกิดขึ้นจริงถ้าออกไป */
  drink: function (p) {
    var cy = 152, hh = 42, eb = cy - 21, wb = cy + 21, park = cy - hh - 22;
    return tdRoadH(p, cy, hh) + tdDashH(p, cy, -4, 404) +
      tdLaneArrow(60, eb, 'e', p.line) + tdLaneArrow(336, wb, 'w', p.line) +
      tdBuilding(128, 40, 140, 56, '#3b2f3f', '#271f2a') +
      '<rect x="62" y="58" width="132" height="10" rx="4" fill="#b8452f"/>' +
      '<g fill="#f5c451">' +
      '<circle cx="86" cy="20" r="6.4" opacity=".9"><animate attributeName="opacity" values=".9;.55;.9" dur="2.8s" repeatCount="indefinite"/></circle>' +
      '<circle cx="128" cy="20" r="6.4" opacity=".75"/>' +
      '<circle cx="170" cy="20" r="6.4" opacity=".9"/></g>' +
      /* แก้วเบียร์สองแก้วบนโต๊ะ คือสองแก้วในคำถามตรงตัว */
      '<g transform="translate(256,52)">' +
      '<ellipse cx="4" cy="20" rx="34" ry="14" fill="rgba(0,0,0,.34)"/>' +
      '<ellipse rx="32" ry="17" fill="#4a3b2e"/><ellipse rx="32" ry="17" fill="rgba(255,255,255,.08)"/>' +
      '<circle cx="-11" cy="-1" r="6.6" fill="#e8b53f"/><circle cx="-11" cy="-1" r="4.4" fill="#f7d777"/>' +
      '<circle cx="11" cy="2" r="6.6" fill="#e8b53f"/><circle cx="11" cy="2" r="4.4" fill="#f7d777"/></g>' +
      tdPerson(300, 92, '#3f6f9e') +
      tdMoto(150, park, 0, 1.15, TD_BLUE) +
      tdPath('tdpA', 'M170 ' + park + ' C212 ' + park + ' 222 ' + eb + ' 250 ' + (eb + 3) +
        ' C286 ' + (eb + 8) + ' 310 ' + (eb - 6) + ' 380 ' + eb, TD_BLUE, 236, 1.6);
  },

  /* คำถาม  เพื่อนดื่มมาหลายแก้วและกำลังจะขับรถกลับเอง เขายืนยันว่ายังไหว

     คนตัดสินใจคือเรา แต่คนที่จะขับคือเพื่อน ภาพจึงต้องมีคนสองคน
     คนหนึ่งอยู่ที่ประตูรถ อีกคนยืนอยู่ข้าง ๆ คือเราที่กำลังจะพูดหรือไม่พูด
     รถของเพื่อนจอดชิดขอบบน เพราะจะออกไปทางขวาของภาพ */
  friend: function (p) {
    var cy = 158, hh = 42, eb = cy - 21, wb = cy + 21, park = cy - hh - 20;
    return tdRoadH(p, cy, hh) + tdDashH(p, cy, -4, 404) +
      tdLaneArrow(52, eb, 'e', p.line) + tdLaneArrow(336, wb, 'w', p.line) +
      tdBuilding(150, 36, 188, 52, '#3a2f3b', '#261f27') +
      '<rect x="58" y="52" width="184" height="10" rx="4" fill="#b8452f"/>' +
      '<g fill="#f5c451">' +
      '<circle cx="92" cy="16" r="6.2" opacity=".9"/>' +
      '<circle cx="150" cy="16" r="6.2" opacity=".72"><animate attributeName="opacity" values=".72;.42;.72" dur="3s" repeatCount="indefinite"/></circle>' +
      '<circle cx="208" cy="16" r="6.2" opacity=".9"/></g>' +
      tdCar(168, park, 0, TD_RED, 1.1, false) +
      tdPerson(150, park + 22, '#c9843f') +
      tdPerson(116, park + 26, '#3f6f9e') +
      tdFocus(150, park + 22, 16) +
      tdPath('tdpA', 'M192 ' + park + ' C232 ' + park + ' 240 ' + eb + ' 272 ' + (eb + 4) +
        ' C304 ' + (eb + 9) + ' 326 ' + (eb - 6) + ' 384 ' + (eb + 1), TD_RED, 210, 1.6);
  },

  /* คำถาม  สี่แยกไม่มีสัญญาณไฟและไม่มีป้ายบอกทางเอกทางโท คุณกับรถอีกคันมาถึงปากแยกพร้อมกันพอดี
             รถคันนั้นอยู่ทางซ้ายมือของคุณ ใครมีสิทธิ์ไปก่อน

     เราขึ้นเหนือ จึงอยู่ครึ่งซ้ายของถนนแนวตั้ง
     เมื่อหันหน้าขึ้นเหนือ ซ้ายมือของเราคือด้านซ้ายของภาพ
     รถที่อยู่ทางซ้ายมือจึงมาจากขอบซ้ายของภาพ วิ่งไปทางขวา และอยู่ครึ่งบนของถนนแนวนอน
     วงเขียวอยู่ที่เขา เพราะเขาคือฝ่ายที่กฎหมายให้ไปก่อน ไม่ใช่เรา */
  giveleft: function (p) {
    var cy = 120, cx = 200, hh = 44, vh = 32, eb = cy - 22, wb = cy + 22, nb = cx - 16;
    return tdRoadH(p, cy, hh) + tdRoadV(p, cx, vh) + tdCross(p, cx, cy, vh, hh) +
      tdDashH(p, cy, -4, cx - vh) + tdDashH(p, cy, cx + vh, 404) +
      tdDashV(p, cx, cy + hh, 264) + tdDashV(p, cx, -4, cy - hh) +
      tdLaneArrow(76, eb, 'e', p.line) + tdLaneArrow(340, eb, 'e', p.line) +
      tdLaneArrow(76, wb, 'w', p.line) + tdLaneArrow(340, wb, 'w', p.line) +
      tdLaneArrow(nb, 236, 'n', p.line) + tdLaneArrow(cx + 16, 236, 's', p.line) +
      tdTree(38, 232, 12) + tdTree(360, 30, 12) +
      tdPath('tdpA', 'M' + nb + ' 236 L' + nb + ' ' + (cy + 6), TD_BLUE, 122, 2.2) +
      tdPath('tdpB', 'M96 ' + eb + ' L330 ' + eb, '#3fae63', 238, .5) +
      tdConflict(nb, eb) +
      tdDrive(tdCar(0, 0, 0, '#3fae63', 1, false) + tdStreak(-22, 3), 'tdpB', .52, TD_LOOP, 0) +
      '<g transform="translate(72,' + eb + ')"><circle r="26" fill="none" stroke="#5ad27a" stroke-width="2.4" opacity=".75"/></g>' +
      tdDrive(tdCar(0, 0, 0, TD_BLUE, 1, true), 'tdpA', .52, TD_LOOP, 0);
  },

  /* คำถาม  สัญญาณไฟเปลี่ยนเป็นสีเขียวให้เราไปได้ แต่ยังมีรถอีกคันค้างอยู่กลางแยก
             ออกไปไม่พ้นเพราะเพิ่งเลี้ยวไม่ทัน

     เราวิ่งไปทางขวาของภาพ จึงอยู่ครึ่งบน และไฟฝั่งเราเขียวแล้ว
     รถที่ค้างอยู่วางเฉียงกลางแยก เพราะเพิ่งเลี้ยวค้างไว้ ไม่ได้จอดตรง ๆ
     วงแหวนอยู่ที่ตัวเขา ไม่ใช่ที่จุดตัด เพราะคำถามถามว่าใครมีสิทธิ์ ไม่ได้ถามว่าจะชนตรงไหน */
  injunction: function (p) {
    var cy = 120, cx = 214, hh = 44, vh = 34, eb = cy - 22, wb = cy + 22, stop = cx - vh - 12;
    return tdRoadH(p, cy, hh) + tdRoadV(p, cx, vh) + tdCross(p, cx, cy, vh, hh) +
      tdDashH(p, cy, -4, cx - vh) + tdDashH(p, cy, cx + vh, 404) +
      tdDashV(p, cx, cy + hh, 264) + tdDashV(p, cx, -4, cy - hh) +
      '<rect x="' + stop + '" y="' + (cy - hh) + '" width="5" height="' + hh + '" fill="' + p.line + '" opacity=".92"/>' +
      tdLaneArrow(64, eb, 'e', p.line) + tdLaneArrow(356, eb, 'e', p.line) +
      tdLaneArrow(64, wb, 'w', p.line) + tdLaneArrow(356, wb, 'w', p.line) +
      tdSignal(stop - 12, cy - hh - 16, 'green') +
      tdTree(40, 28, 12) + tdTree(370, 232, 12) +
      tdCar(cx + 4, cy - 4, -34, TD_RED, 1, true) +
      tdFocus(cx + 4, cy - 4, 26) +
      tdPath('tdpB', 'M' + (cx + 14) + ' ' + (cy - 16) + ' L' + (cx + 34) + ' ' + (cy - 44), TD_RED, 40, 2.3) +
      tdPath('tdpA', 'M44 ' + eb + ' L' + (stop - 12) + ' ' + eb, TD_BLUE, 148, .6) +
      tdDrive(tdCar(0, 0, 0, TD_BLUE, 1, true) + tdStreak(-22, 3), 'tdpA', .62, TD_LOOP, 0);
  },

  /* คำถาม  ขับเข้าใกล้ทางร่วมทางแยกที่ไม่มีสัญญาณไฟ มองไปทั้งสองทางแล้วไม่เห็นรถคันไหนเลย ถนนโล่ง

     ฉากนี้ต้องไม่มีรถคันที่สองให้เห็น เพราะคำถามบอกว่าถนนโล่ง
     ถ้าวาดรถโผล่มา ภาพจะตอบคำถามแทนผู้เล่นไปเลย
     สิ่งที่วาดแทนคืออาคารมุมแยกกับพื้นที่สีเทาที่สายตาเรามองไม่ถึง
     นั่นคือเหตุผลจริงที่กฎหมายสั่งให้ลดความเร็วแม้จะมองแล้วไม่เห็นอะไร */
  slowjunction: function (p) {
    var cy = 126, cx = 236, hh = 42, vh = 30, eb = cy - 21, wb = cy + 21;
    return tdRoadH(p, cy, hh) + tdRoadV(p, cx, vh) + tdCross(p, cx, cy, vh, hh) +
      tdDashH(p, cy, -4, cx - vh) + tdDashH(p, cy, cx + vh, 404) +
      tdDashV(p, cx, cy + hh, 264) + tdDashV(p, cx, -4, cy - hh) +
      tdLaneArrow(64, eb, 'e', p.line) + tdLaneArrow(356, eb, 'e', p.line) +
      tdLaneArrow(64, wb, 'w', p.line) + tdLaneArrow(356, wb, 'w', p.line) +
      tdLaneArrow(cx - 15, 240, 'n', p.line) + tdLaneArrow(cx + 15, 240, 's', p.line) +
      /* อาคารมุมแยกฝั่งที่รถจะโผล่มา เป็นตัวบังจริงที่พบได้ทุกแยกในเมือง */
      tdBuilding(140, 204, 130, 62, '#8a7a62', '#5f5343') +
      tdBuilding(140, 44, 130, 54, '#7d8796', '#5c646f') +
      /* พื้นที่ที่สายตาเรามองไม่ถึง วัดจากตำแหน่งตาเราไปชนมุมอาคาร */
      '<g opacity=".26"><path d="M60 ' + eb + ' L205 176 L205 260 L60 260 Z" fill="#20262e"/></g>' +
      tdPath('tdpA', 'M30 ' + eb + ' L190 ' + eb, TD_BLUE, 162, .6) +
      tdConflict(cx - 15, eb) +
      tdDrive(tdCar(0, 0, 0, TD_BLUE, 1, true) + tdStreak(-22, 4), 'tdpA', .7, TD_LOOP, 0);
  },

  /* คำถาม  กำลังจะขับออกจากซอยเข้าถนนใหญ่ ตรงปากซอยมีเส้นขาวขวางอยู่
             รถบนถนนใหญ่วิ่งต่อเนื่องแต่มีช่องว่างพอให้แทรกได้

     เราขึ้นเหนือออกจากซอย จึงอยู่ครึ่งซ้ายของซอย
     ออกจากซอยแล้วเลี้ยวซ้าย คือเลี้ยวเข้าเลนที่อยู่ใกล้ตัวที่สุด ซึ่งคือเลนล่างที่วิ่งไปทางซ้าย
     ถนนใหญ่มีรถทั้งสองทิศ เพื่อให้เห็นว่าไม่ได้ว่างจริงอย่างที่คำถามชวนให้คิด */
  soiout: function (p) {
    var cy = 104, cx = 190, hh = 44, vh = 26, eb = cy - 22, wb = cy + 22, nb = cx - 13;
    return tdRoadV(p, cx, vh, cy + hh, 264) + tdRoadH(p, cy, hh) +
      tdMouth(p, cx, vh, cy + hh, 9) +
      tdDashH(p, cy, -4, 404) +
      tdGiveWay(p, cx - vh + 3, cx, cy + hh + 14) +
      tdLaneArrow(66, eb, 'e', p.line) + tdLaneArrow(344, eb, 'e', p.line) +
      tdLaneArrow(66, wb, 'w', p.line) + tdLaneArrow(344, wb, 'w', p.line) +
      tdLaneArrow(nb, 242, 'n', p.line) + tdLaneArrow(cx + 13, 242, 's', p.line) +
      tdBuilding(80, 208, 96, 52, '#8a7a62', '#5f5343') +
      tdBuilding(310, 210, 104, 52, '#7d8796', '#5c646f') +
      tdTree(40, 30, 12) +
      tdPath('tdpE', 'M40 ' + eb + ' L392 ' + eb, TD_RED, 352, .3) +
      tdPath('tdpW', 'M392 ' + wb + ' L40 ' + wb, TD_RED, 352, .9) +
      tdMove(tdCar(0, 0, 0, TD_RED, 1, false), 'tdpE', 5.4, 0) +
      tdMove(tdCar(0, 0, 0, TD_RED, 1, false), 'tdpW', 6.2, .8) +
      tdPath('tdpA', 'M' + nb + ' ' + (cy + hh + 40) + ' L' + nb + ' ' + (cy + 30) +
        ' Q' + nb + ' ' + wb + ' ' + (cx - 34) + ' ' + wb + ' L60 ' + wb, TD_BLUE, 190, 2.4) +
      tdConflict(nb, wb) +
      tdDrive(tdCar(0, 0, 0, TD_BLUE, 1, true), 'tdpA', .34, TD_LOOP, 0);
  },

  /* คำถาม  จะเปลี่ยนจากช่องซ้ายไปช่องขวา เหลือบดูกระจกข้างแล้วเห็นว่าว่าง

     ถนนสองช่องต่อทิศ ทิศออกอยู่ครึ่งบนทั้งสองช่อง
     ช่องซ้ายของคนที่วิ่งไปทางขวา คือช่องที่ชิดขอบบนของภาพ
     ช่องขวาคือช่องที่ชิดเส้นแบ่งกลาง จักรยานยนต์จึงต้องอยู่ในช่องนั้น เยื้องมาทางท้ายรถเรา
     ซึ่งเป็นตำแหน่งที่กระจกข้างมองไม่เห็นพอดี */
  lanechange: function (p) {
    var cy = 126, hh = 58, l1 = cy - 44, l2 = cy - 16, r1 = cy + 16, r2 = cy + 44;
    return tdRoadH(p, cy, hh) + tdSolidH(p, cy, -4, 404, 3) +
      tdDashH(p, cy - 29, -4, 404) + tdDashH(p, cy + 29, -4, 404) +
      tdLaneArrow(50, l1, 'e', p.line) + tdLaneArrow(50, l2, 'e', p.line) +
      tdLaneArrow(352, r1, 'w', p.line) + tdLaneArrow(352, r2, 'w', p.line) +
      tdTree(28, 24, 11) + tdTree(360, 236, 11) +
      tdDrive(tdCar(0, 0, 0, TD_BLUE, 1, false) + tdStreak(-22, 3), 'tdpA', .18, TD_LOOP, 0) +
      /* กรวยที่กระจกข้างมองไม่เห็น กางออกไปทางท้ายรถฝั่งที่จะเปลี่ยนเข้าไป */
      '<g opacity=".24"><path d="M196 ' + (l1 + 6) + ' L120 ' + (l2 + 16) + ' L196 ' + (l2 + 16) + ' Z" fill="#ff3b30"/></g>' +
      tdDrive(tdMoto(0, 0, 0, 1, TD_RED) + tdStreak(-15, 3), 'tdpM', .5, TD_LOOP, 0) +
      tdFocus(168, l2, 17) +
      tdPath('tdpA', 'M232 ' + l1 + ' C264 ' + l1 + ' 262 ' + l2 + ' 300 ' + l2, TD_BLUE, 96, 1.6) +
      tdPath('tdpM', 'M186 ' + l2 + ' L286 ' + l2, TD_RED, 100, .5) +
      tdConflict(272, l2);
  },

  /* คำถาม  จะเลี้ยวขวาที่แยกข้างหน้าอีกราวสามสิบเมตร ตอนนี้ยังอยู่ช่องซ้ายสุด

     ถนนสองช่องต่อทิศ เราอยู่ช่องที่ชิดขอบบน ซึ่งคือช่องซ้ายสุดของทิศที่วิ่งไปทางขวา
     ช่องขวาที่ต้องเข้าไปใช้ก่อนเลี้ยว มีรถวิ่งอยู่เต็ม จึงตัดข้ามไปไม่ได้ในระยะสามสิบเมตร
     ทางแยกอยู่ปลายภาพ เพื่อให้เห็นว่าระยะที่เหลือสั้นแค่ไหนจริง ๆ */
  turnprep: function (p) {
    var cy = 126, cx = 322, hh = 58, vh = 30, l1 = cy - 44, l2 = cy - 16, r1 = cy + 16, r2 = cy + 44;
    return tdRoadH(p, cy, hh) + tdRoadV(p, cx, vh) + tdCross(p, cx, cy, vh, hh) +
      tdSolidH(p, cy, -4, cx - vh, 3) + tdSolidH(p, cy, cx + vh, 404, 3) +
      tdDashH(p, cy - 29, -4, cx - vh) + tdDashH(p, cy + 29, cx + vh, 404) +
      tdLaneArrow(40, l1, 'e', p.line) + tdLaneArrow(40, l2, 'e', p.line) +
      tdLaneArrow(380, r2, 'w', p.line) +
      tdLaneArrow(cx - 15, 244, 'n', p.line) + tdLaneArrow(cx + 15, 244, 's', p.line) +
      tdTree(24, 26, 11) +
      tdDrive(tdCar(0, 0, 0, TD_BLUE, 1, false) + tdStreak(-22, 3), 'tdpA', .26, TD_LOOP, 0) +
      tdMove(tdCar(0, 0, 0, TD_RED, 1, false), 'tdpLane', 3.6, 0) +
      tdMove(tdCar(0, 0, 0, TD_RED, 1, false), 'tdpLane', 3.6, 1.8) +
      /* เส้นที่ถูกต้องคือไปต่อ ไม่ใช่ตัดข้ามช่อง จึงวาดเส้นตรงผ่านแยกไว้เป็นสีน้ำเงิน */
      tdPath('tdpA', 'M102 ' + l1 + ' L392 ' + l1, TD_BLUE, 292, 1.8) +
      /* เส้นที่คนมักทำจริง วาดเป็นสีแดงและจบที่วงจุดตัด ให้เห็นว่าไปชนกับอะไร */
      tdPath('tdpX', 'M102 ' + l1 + ' C170 ' + l1 + ' 180 ' + l2 + ' 214 ' + l2, TD_RED, 122, .5) +
      tdConflict(222, l2) +
      '<path id="tdpLane" d="M-30 ' + l2 + ' L430 ' + l2 + '" fill="none" opacity="0"/>';
  },

  /* คำถาม  ที่หมายอยู่ฝั่งตรงข้าม ข้างหน้าเป็นทางแยกพอดี
             ถ้ากลับรถตรงแยกนี้เลยก็สะดวกที่สุด และตอนนี้ไม่มีรถสวนมา

     เราวิ่งไปทางขวาของภาพ อยู่ครึ่งบน
     ที่แยกวาดเส้นกลับรถไว้เป็นสีแดงพร้อมเครื่องหมายห้าม เพราะนั่นคือสิ่งที่คำถามชวนให้ทำ
     แล้ววาดจุดกลับรถที่อนุญาตไว้ถัดไปเป็นสีน้ำเงิน เพื่อให้เห็นว่าทางเลือกที่ถูกอยู่ตรงไหน
     ภาพที่มีแต่ข้อห้ามโดยไม่บอกทางออก จะถูกอ่านว่าเป็นการดุ ไม่ใช่การสอน */
  uturnban: function (p) {
    /* คำถาม  ที่หมายอยู่ฝั่งตรงข้าม ข้างหน้าเป็นทางแยกพอดี
               ถ้ากลับรถตรงแยกนี้เลยก็สะดวกที่สุด และตอนนี้ไม่มีรถสวนมา

       ห้ามวาดเครื่องหมายห้ามหรือป้ายใด ๆ ลงในฉากนี้เด็ดขาด
       จุดสอนคือห้ามกลับรถที่ทางร่วมทางแยกเสมอ ไม่ว่าจะมีป้ายห้ามหรือไม่
       ถ้ามีป้ายอยู่ในภาพ คำถามจะไม่เหลืออะไรให้คิด และยังขัดกับโจทย์ที่บอกว่าไม่มีป้าย

       เราวิ่งไปทางขวาของภาพ จึงอยู่ครึ่งบนของถนน
       เลนสวนคือครึ่งล่าง ปล่อยว่างไว้จริงตามที่โจทย์บอกว่าไม่มีรถสวนมา
       ที่หมายอยู่ฝั่งตรงข้ามถนนและอยู่ด้านหลังเรา จึงเป็นเหตุผลที่อยากกลับรถ */
    var cy = 122, cx = 226, hh = 48, vh = 30, eb = cy - 24, wb = cy + 24;
    return tdRoadH(p, cy, hh) + tdRoadV(p, cx, vh) + tdCross(p, cx, cy, vh, hh) +
      tdDashH(p, cy, -4, cx - vh) + tdDashH(p, cy, cx + vh, 404) +
      tdDashV(p, cx, -4, cy - hh) + tdDashV(p, cx, cy + hh, 264) +
      tdLaneArrow(64, eb, 'e', p.line) + tdLaneArrow(360, eb, 'e', p.line) +
      tdLaneArrow(64, wb, 'w', p.line) + tdLaneArrow(360, wb, 'w', p.line) +
      tdLaneArrow(cx - 15, 240, 'n', p.line) + tdLaneArrow(cx + 15, 240, 's', p.line) +
      tdTree(340, 34, 12) +
      /* ที่หมาย  อยู่ฝั่งตรงข้ามถนนและอยู่ด้านหลังเรา
         วาดเป็นอาคารกับหมุด ไม่ใช่ป้ายจราจร จะได้ไม่ถูกอ่านเป็นเครื่องหมายบังคับ */
      tdBuilding(86, 214, 104, 50, '#b4784a', '#7d5232') +
      '<g transform="translate(86,176)">' +
      '<ellipse cx="2" cy="9" rx="8" ry="3.6" fill="rgba(0,0,0,.35)"/>' +
      '<path d="M0 8 C-8 -2 -10 -6 -10 -10 A10 10 0 1 1 10 -10 C10 -6 8 -2 0 8 Z" fill="#2f7fe0"/>' +
      '<circle cy="-10" r="3.8" fill="#fff"/></g>' +
      /* เส้นทางที่เรากำลังคิดจะทำ คือกลับรถตรงแยก
         ใช้สีน้ำเงินเหมือนเส้นทางของเราในทุกฉาก ไม่ได้บอกว่าถูกหรือผิด */
      tdPath('tdpA', 'M46 ' + eb + ' L' + (cx - 8) + ' ' + eb + ' Q' + (cx + 18) + ' ' + eb + ' ' + (cx + 18) + ' ' + cy +
        ' Q' + (cx + 18) + ' ' + wb + ' ' + (cx - 8) + ' ' + wb + ' L104 ' + wb, TD_BLUE, 300, 1.2) +
      /* วงแหวนสีเหลืองคือจุดที่ต้องตัดสินใจ เป็นสีกลางที่ใช้ทั้งไฟล์อยู่แล้ว
         ไม่ใช่สีแดงซึ่งจะถูกอ่านเป็นคำเตือนว่าห้าม แล้วกลายเป็นการเฉลย */
      tdConflict(cx + 18, cy) +
      tdDrive(tdCar(0, 0, 0, TD_BLUE, 1, false) + tdStreak(-22, 3), 'tdpA', .2, TD_LOOP, 0);
  },

  /* คำถาม  ถนนมีสองช่องทางไปทางเดียวกัน รถในช่องซ้ายหยุดนิ่งอยู่หน้าทางม้าลายโดยไม่มีไฟแดง
             ช่องของเราว่างโล่ง

     ทั้งสองช่องวิ่งไปทางขวาของภาพ จึงอยู่ครึ่งบนทั้งคู่
     ช่องซ้ายคือช่องที่ชิดขอบบน รถแดงหยุดอยู่ตรงนั้น เราอยู่ช่องถัดมาด้านใน
     คนเดินข้ามมาจากขอบบน คือฝั่งเดียวกับรถที่หยุด จึงถูกตัวรถคันนั้นบังไว้พอดี
     และจะโผล่เข้ามาในช่องของเราที่วงจุดตัด นี่คือทั้งหมดของคำถามข้อนี้ */
  zebrastop: function (p) {
    var cy = 128, hh = 58, l1 = cy - 44, l2 = cy - 16, r1 = cy + 16, r2 = cy + 44, zx = 236;
    return tdRoadH(p, cy, hh) + tdSolidH(p, cy, -4, 404, 3) +
      tdDashH(p, cy - 29, -4, zx - 10) + tdDashH(p, cy - 29, zx + 62, 404) +
      tdDashH(p, cy + 29, -4, 404) +
      tdZebra(p, zx, cy - hh, cy + hh, 5) +
      tdLaneArrow(52, l1, 'e', p.line) + tdLaneArrow(52, l2, 'e', p.line) +
      tdLaneArrow(360, r2, 'w', p.line) +
      tdTree(30, 22, 11) + tdTree(350, 238, 11) +
      tdCar(196, l1, 0, TD_RED, 1, true) +
      /* คนเดินอยู่พ้นหัวรถแดงออกมาแล้ว แต่ยังอยู่ในเงาที่ตัวรถบังจากมุมของเรา */
      tdDrive(tdPerson(0, 0, '#f0b429'), 'tdpP', .85, TD_LOOP, .6) +
      '<g opacity=".22"><path d="M172 ' + (l1 + 12) + ' L' + (zx + 70) + ' ' + (l1 - 6) + ' L' + (zx + 70) + ' ' + (l2 + 18) + ' Z" fill="#20262e"/></g>' +
      tdPath('tdpP', 'M' + (zx + 22) + ' ' + (l1 + 16) + ' L' + (zx + 22) + ' ' + (l2 + 18), '#f0b429', 32, 2.3) +
      tdPath('tdpA', 'M118 ' + l2 + ' L' + (zx - 18) + ' ' + l2, TD_BLUE, 102, .6) +
      tdConflict(zx + 22, l2) +
      tdDrive(tdCar(0, 0, 0, TD_BLUE, 1, false) + tdStreak(-22, 3), 'tdpA', .62, TD_LOOP, 0);
  },
};

/* ============================================================
   ประกอบเป็น SVG พร้อมใช้
   ============================================================
   name มาจากช่อง top ของคำถามโดยตรง ไม่มีการเดาจากป้ายหัวข้ออีกแล้ว
   ถ้าชื่อไม่ตรงกับฉากไหนเลย จะคืนค่าว่าง แล้วเกมจะกลับไปใช้ภาพวาดชุดเดิมเอง */
function topSVG(name, mood) {
  var fn = TD_SCENES[name];
  if (!fn) return '';

  var night = { drowsy: 1, drink: 1, friend: 1 }, wet = { rain: 1, rainheavy: 1 };
  var key = (night[name] || mood === 'night') ? 'night'
          : (wet[name] || mood === 'rain') ? 'rain' : 'day';
  var p = TD_COL[key];

  /* คนที่ตั้งเครื่องให้ลดการเคลื่อนไหว จะได้ภาพนิ่ง
     ยังเห็นเส้นทางและตำแหน่งรถครบ เพราะลูกศรถูกสั่งให้แสดงเต็มเส้นแทน */
  var still = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  var svg = '<svg class="scene-top" viewBox="0 0 ' + TD_W + ' ' + TD_H + '" preserveAspectRatio="xMidYMid meet" ' +
    'xmlns="http://www.w3.org/2000/svg" aria-hidden="true">' +
    '<defs>' + tdMarker(TD_BLUE) + tdMarker(TD_RED) +
    '<linearGradient id="tdG" x1="0" y1="0" x2="0" y2="1">' +
    '<stop offset="0" stop-color="' + p.grass + '"/><stop offset="1" stop-color="' + p.grass2 + '"/>' +
    '</linearGradient>' +
    '<linearGradient id="tdFog" x1="0" y1="0" x2="1" y2="0">' +
    '<stop offset="0" stop-color="#dbe6f0" stop-opacity="0"/>' +
    '<stop offset="0.55" stop-color="#dbe6f0" stop-opacity="0.55"/>' +
    '<stop offset="1" stop-color="#dbe6f0" stop-opacity="0.9"/>' +
    '</linearGradient></defs>' +
    '<rect width="' + TD_W + '" height="' + TD_H + '" fill="url(#tdG)"/>' +
    fn(p) + '</svg>';

  if (still) {
    svg = svg.replace(/<animate[^>]*\/>/g, '').replace(/<animateMotion[\s\S]*?<\/animateMotion>/g, '')
             .replace(/<animateTransform[^>]*\/>/g, '')
             .replace(/stroke-dashoffset="[0-9.]+"/g, 'stroke-dashoffset="0"')
             .replace(/opacity="0" stroke-dasharray/g, 'opacity="0.95" stroke-dasharray');
  }
  return svg;
}

if (typeof window !== 'undefined') { window.topSVG = topSVG; window.TD_SCENES = TD_SCENES; }
