'use strict';
/* ============================================================
   ฉากชุดที่เจ็ด  ชุดสุดท้าย  ช่องทางเดินรถ ความเร็ว สภาพรถ และเหตุฉุกเฉิน
   ============================================================
   ต่อจาก scene-top.js ถึง scene-top6.js ต้องโหลดตามลำดับ
   ชุดนี้ปิดท้าย ทำให้คำถามครบทั้งร้อยข้อมีฉากมุมสูงของตัวเอง

   กฎสองข้อเดิม
   หนึ่ง  ขับชิดซ้าย  วิ่งไปทางขวาของภาพอยู่ครึ่งบน วิ่งไปทางซ้ายอยู่ครึ่งล่าง
   สอง   ภาพห้ามเฉลยคำตอบ

   เรื่องที่ต้องระวังเป็นพิเศษในชุดนี้
     คำถามสามข้อเรื่องความเร็ว ถ้าวาดป้ายจำกัดความเร็วลงไปก็คือเฉลยตัวเลขให้เสร็จ
     ทั้งสามข้อโจทย์เขียนตรงกันว่าไม่มีป้าย จึงต้องไม่มีป้ายในภาพด้วย
     สิ่งที่แยกสามข้อนี้ออกจากกันคือ ในเขตหรือนอกเขต และรถยนต์หรือจักรยานยนต์
     ภาพจึงต้องบอกสองอย่างนั้นให้ชัดแทน คือตัวเมืองกับทุ่ง และชนิดรถที่เราขี่
   ============================================================ */

/* แถบไล่เฉดบอกความชัน  มองจากมุมสูงไม่เห็นความสูง จึงต้องบอกด้วยสีกับลูกศร
   ด้านที่เข้มกว่าคือด้านต่ำ ลูกศรชี้ไปทางที่ลาดลง */
function tdSlope(p, cy, hh, x1, x2, down) {
  var mid = (x1 + x2) / 2;
  return '<rect x="' + x1 + '" y="' + (cy - hh) + '" width="' + (x2 - x1) + '" height="' + (hh * 2) + '" ' +
    'fill="#000" opacity=".18"/>' +
    '<g transform="translate(' + mid + ',' + (cy + hh + 18) + ')" opacity=".85">' +
    '<path d="M' + (down < 0 ? 34 : -34) + ' 0 H' + (down < 0 ? -24 : 24) +
    ' M' + (down < 0 ? -16 : 16) + ' -8 l' + (down < 0 ? -8 : 8) + ' 8 ' + (down < 0 ? 8 : -8) + ' 8" ' +
    'fill="none" stroke="#ffd166" stroke-width="3.4" stroke-linecap="round" stroke-linejoin="round"/></g>';
}

/* ของยาวที่ยื่นพ้นท้ายกระบะ  วาดเป็นแท่งยาวโผล่ออกมาจากท้ายรถ */
function tdLoad(x, y, len, flag) {
  return '<g transform="translate(' + x + ',' + y + ')">' +
    '<rect x="' + (-len) + '" y="-7" width="' + len + '" height="14" rx="2" fill="rgba(0,0,0,.3)" transform="translate(3,4)"/>' +
    '<rect x="' + (-len) + '" y="-7" width="' + len + '" height="14" rx="2" fill="#b08a5a"/>' +
    '<rect x="' + (-len) + '" y="-7" width="' + len + '" height="5" rx="2" fill="#cba97a"/>' +
    (flag === 'red'
      ? '<rect x="' + (-len - 14) + '" y="-9" width="16" height="18" rx="2" fill="#d0342c"/>'
      : flag === 'lamp'
        ? '<circle cx="' + (-len - 8) + '" cy="0" r="6" fill="#ff2d2d">' +
          '<animate attributeName="opacity" values="1;.35;1" dur="1s" repeatCount="indefinite"/></circle>'
        : '') +
    '</g>';
}

var TD_SCENES7 = {

  /* ---------- ช่องทางเดินรถ ---------- */

  /* คำถาม  ขี่จักรยานยนต์บนถนนที่มีสามช่องทางไปทางเดียวกัน ช่องขวาสุดวิ่งได้ลื่นกว่า
     ต้องเห็นครบสามช่อง และเห็นว่าช่องขวาสุดโล่งกว่าจริง
     ช่องขวาสุดคือช่องที่อยู่ล่างสุดของครึ่งบน เพราะขวามือของคนที่วิ่งไปทางขวาคือด้านล่าง */
  threelane: function (p) {
    var cy = 132, hh = 62, l1 = cy - 50, l2 = cy - 30, l3 = cy - 10, out = '', i;
    for (i = 0; i < 4; i++) {
      out += tdCar(70 + i * 74, l1, 0, '#8a94a3', 1, true) + tdCar(104 + i * 74, l2, 0, '#8a94a3', 1, true);
    }
    return tdRoadH(p, cy, hh) + tdSolidH(p, cy + 2, -4, 404, 3) +
      tdDashH(p, cy - 40, -4, 404) + tdDashH(p, cy - 20, -4, 404) +
      tdLaneArrow(30, l1, 'e', p.line) + tdLaneArrow(30, l2, 'e', p.line) + tdLaneArrow(30, l3, 'e', p.line) +
      tdLaneArrow(374, cy + 30, 'w', p.line) +
      tdBuilding(140, 28, 170, 40, '#7d8796', '#5c646f') +
      out +
      /* ช่องขวาสุดโล่ง มีรถวิ่งผ่านไปเรื่อย ๆ ซึ่งคือแรงจูงใจของคำถามข้อนี้ */
      tdStream('tdpFast', 'M-60 ' + l3 + ' L460 ' + l3, '#c2492f', 4.2, 2, false) +
      tdMoto(150, l1, 0, 1, TD_BLUE) + tdFocus(150, l1, 26) +
      tdPath('tdpA', 'M170 ' + l1 + ' Q214 ' + l1 + ' 220 ' + l2 + ' Q262 ' + l2 + ' 268 ' + l3 + ' L330 ' + l3,
        TD_BLUE, 200, 1.6) +
      tdConflict(272, l3);
  },

  /* คำถาม  ถนนหลายช่องทาง คนขับข้างหน้าวิ่งคร่อมเส้นแบ่งช่องมาตลอดทาง ไม่ได้จะเปลี่ยนช่องไปไหน
     ต้องเห็นชัดว่าคันนั้นคร่อมเส้นอยู่จริง คือตัวรถทับเส้นแบ่งช่องพอดี
     และต้องเห็นว่าเขากินพื้นที่ของสองช่องพร้อมกัน */
  straddle: function (p) {
    var cy = 130, hh = 58, l1 = cy - 43, l2 = cy - 15;
    return tdRoadH(p, cy, hh) + tdSolidH(p, cy, -4, 404, 3) +
      tdDashH(p, cy - 29, -4, 404) + tdDashH(p, cy + 29, -4, 404) +
      tdLaneArrow(36, l1, 'e', p.line) + tdLaneArrow(36, l2, 'e', p.line) +
      tdLaneArrow(368, cy + 15, 'w', p.line) + tdLaneArrow(368, cy + 43, 'w', p.line) +
      tdTree(30, 28, 12) + tdTree(340, 236, 12) +
      /* คันที่คร่อมเส้น ตัวรถอยู่บนเส้นแบ่งช่องพอดี จึงกินทั้งสองช่อง */
      tdCar(250, cy - 29, 0, '#c2492f', 1, false) +
      tdFocus(250, cy - 29, 30) +
      tdCar(110, l2, 0, TD_BLUE, 1, true) +
      tdPath('tdpA', 'M130 ' + l2 + ' L206 ' + l2, TD_BLUE, 80, 1.3) +
      tdConflict(224, cy - 22) +
      tdStream('tdpOnc', 'M448 ' + (cy + 43) + ' L-48 ' + (cy + 43), '#8a94a3', 7.6, 1, false);
  },

  /* คำถาม  รถติดยาวบนถนนสายหลัก ไหล่ทางด้านซ้ายโล่งและกว้างพอให้รถผ่านได้
     ไหล่ทางต้องดูโล่งและกว้างจริงตามที่โจทย์บอก ไม่ใช่วาดให้แคบจนแซงไม่ได้
     เพราะถ้าวาดให้แคบ ก็เท่ากับตอบคำถามให้เสร็จด้วยรูปทรงของถนน */
  shoulder: function (p) {
    var cy = 136, hh = 46, eb = cy - 23, wb = cy + 23, sh = cy - hh - 18, out = '', i;
    for (i = 0; i < 6; i++) { out += tdCar(60 + i * 60, eb, 0, i === 1 ? '#8a94a3' : '#c2492f', 1, true); }
    return tdRoadH(p, cy, hh) + tdDashH(p, cy, -4, 404) +
      /* ไหล่ทางลาดยางกว้าง อยู่นอกเส้นขอบทาง */
      '<rect x="-4" y="' + (cy - hh - 30) + '" width="408" height="30" fill="' + tdShade(p.road, 1.1) + '"/>' +
      '<line x1="-4" y1="' + (cy - hh) + '" x2="404" y2="' + (cy - hh) + '" stroke="' + p.line +
      '" stroke-width="3" opacity=".9"/>' +
      tdLaneArrow(376, eb, 'e', p.line) + tdLaneArrow(40, wb, 'w', p.line) +
      out + tdFocus(120, eb, 30) +
      tdPath('tdpA', 'M138 ' + eb + ' Q176 ' + eb + ' 182 ' + sh + ' L330 ' + sh, TD_BLUE, 200, 1.5) +
      tdConflict(196, sh);
  },

  /* คำถาม  ที่หมายอยู่ตรงข้ามพอดี ถ้าย้อนศรไปนิดเดียวราวห้าสิบเมตรก็ถึง แต่ถ้าไปกลับรถต้องอ้อมไกล
     ถนนเดินรถทางเดียว ลูกศรทุกช่องจึงชี้ทางเดียวกันหมด
     เส้นทางที่เราคิดจะทำสวนทางกับลูกศรทุกอัน ซึ่งอ่านออกทันทีว่าย้อนศร */
  wrongway: function (p) {
    var cy = 130, hh = 50, l1 = cy - 26, l2 = cy + 26;
    return tdRoadH(p, cy, hh) + tdDashH(p, cy, -4, 404) +
      tdLaneArrow(60, l1, 'e', p.line) + tdLaneArrow(200, l1, 'e', p.line) + tdLaneArrow(340, l1, 'e', p.line) +
      tdLaneArrow(60, l2, 'e', p.line) + tdLaneArrow(200, l2, 'e', p.line) + tdLaneArrow(340, l2, 'e', p.line) +
      tdBuilding(120, 36, 150, 44, '#7d8796', '#5c646f') +
      /* ที่หมายอยู่ด้านหลังเรา จึงเป็นเหตุผลที่อยากย้อน */
      tdBuilding(96, 224, 130, 46, '#b4784a', '#7d5232') +
      '<g transform="translate(96,190)">' +
      '<ellipse cx="2" cy="9" rx="8" ry="3.6" fill="rgba(0,0,0,.35)"/>' +
      '<path d="M0 8 C-8 -2 -10 -6 -10 -10 A10 10 0 1 1 10 -10 C10 -6 8 -2 0 8 Z" fill="#2f7fe0"/>' +
      '<circle cy="-10" r="3.8" fill="#fff"/></g>' +
      tdStream('tdpFlow', 'M-60 ' + l1 + ' L460 ' + l1, '#8a94a3', 5.6, 2, false) +
      tdCar(260, l2, 0, TD_BLUE, 1, true) +
      /* เส้นทางที่คิดจะทำ สวนทางกับลูกศรของทุกช่อง */
      tdPath('tdpA', 'M242 ' + l2 + ' L110 ' + l2, TD_BLUE, 136, 1.4) +
      tdConflict(180, l2);
  },

  /* คำถาม  จะกลับรถตรงจุดที่อนุญาตให้กลับได้ มองกระจกเห็นรถตามมาห่างราวห้าสิบเมตร
     จุดกลับรถต้องเป็นช่องเปิดที่เกาะกลางจริง เพราะโจทย์บอกว่าอนุญาต
     รถที่ตามมาต้องเห็นชัดว่ากำลังวิ่งเข้ามา ไม่ใช่จอดอยู่ */
  uturnfollow: function (p) {
    var cy = 128, hh = 52, eb = cy - 26, wb = cy + 26, g1 = 200, g2 = 262;
    return tdRoadH(p, cy, hh) +
      '<rect x="-4" y="' + (cy - 8) + '" width="' + (g1 + 4) + '" height="16" rx="4" fill="' + p.kerb + '"/>' +
      '<rect x="-4" y="' + (cy - 8) + '" width="' + (g1 + 4) + '" height="5" rx="3" fill="rgba(255,255,255,.34)"/>' +
      '<rect x="' + g2 + '" y="' + (cy - 8) + '" width="' + (404 - g2) + '" height="16" rx="4" fill="' + p.kerb + '"/>' +
      '<rect x="' + g2 + '" y="' + (cy - 8) + '" width="' + (404 - g2) + '" height="5" rx="3" fill="rgba(255,255,255,.34)"/>' +
      tdLaneArrow(60, eb, 'e', p.line) + tdLaneArrow(340, eb, 'e', p.line) +
      tdLaneArrow(60, wb, 'w', p.line) + tdLaneArrow(340, wb, 'w', p.line) +
      tdTree(40, 30, 12) + tdTree(320, 234, 12) +
      /* รถที่ตามมาจากด้านหลังในเลนเดียวกับเรา */
      tdStream('tdpBack', 'M-120 ' + eb + ' L120 ' + eb, '#c2492f', 3.8, 1, false) +
      tdCar(176, eb, 0, TD_BLUE, 1, true) +
      tdPath('tdpA', 'M194 ' + eb + ' L208 ' + eb + ' Q232 ' + eb + ' 232 ' + cy +
        ' Q232 ' + wb + ' 206 ' + wb + ' L90 ' + wb, TD_BLUE, 220, 1.5) +
      tdConflict(150, eb);
  },

  /* ---------- ความเร็ว สามข้อ ----------
     ห้ามมีป้ายจำกัดความเร็วในสามฉากนี้ เพราะโจทย์ทั้งสามข้อบอกว่าไม่มีป้าย
     และตัวเลขบนป้ายคือคำตอบ สิ่งที่ภาพต้องบอกคือในเขตหรือนอกเขต และเราขี่อะไร */

  /* คำถาม  ขับอยู่บนถนนในเขตเทศบาลนครนครสวรรค์ ถนนโล่งและไม่มีป้ายจำกัดความเร็วให้เห็น
     เป็นรถยนต์ในเขตเมือง ภาพจึงต้องแน่นไปด้วยอาคารสองฝั่ง */
  speedtown: function (p) {
    var cy = 130, hh = 50, eb = cy - 25, wb = cy + 25;
    return tdRoadH(p, cy, hh) + tdDashH(p, cy, -4, 404) +
      tdLaneArrow(48, eb, 'e', p.line) + tdLaneArrow(356, wb, 'w', p.line) +
      tdBuilding(70, 34, 100, 46, '#9a7350', '#6c4e34') +
      tdBuilding(180, 30, 96, 40, '#7d8796', '#5c646f') +
      tdBuilding(300, 36, 110, 48, '#8f8a5e', '#635f40') +
      tdBuilding(110, 226, 120, 44, '#7d8796', '#5c646f') +
      tdBuilding(270, 230, 130, 46, '#9a7350', '#6c4e34') +
      tdCar(120, eb, 0, TD_BLUE, 1, false) +
      tdPath('tdpA', 'M140 ' + eb + ' L368 ' + eb, TD_BLUE, 230, 1.2) +
      tdDrive(tdCar(0, 0, 0, TD_BLUE, 1, false) + tdStreak(-22, 4), 'tdpA', .001, TD_LOOP, 0) +
      tdStream('tdpOnc', 'M448 ' + wb + ' L-48 ' + wb, '#8a94a3', 6.8, 2, false);
  },

  /* คำถาม  ขับรถยนต์ออกนอกเขตเทศบาลมาแล้ว ถนนโล่งและไม่มีป้ายจำกัดความเร็ว
     นอกเขตเมือง ภาพจึงเป็นทุ่งกับต้นไม้ ไม่มีอาคารเลย
     ความต่างจากข้อในเขตอยู่ตรงนี้จุดเดียว และต้องต่างให้เห็นชัด */
  speedrural: function (p) {
    var cy = 130, hh = 50, eb = cy - 25, wb = cy + 25;
    return tdRoadH(p, cy, hh) + tdDashH(p, cy, -4, 404) +
      tdLaneArrow(48, eb, 'e', p.line) + tdLaneArrow(356, wb, 'w', p.line) +
      /* ทุ่งนาสองฝั่ง ไม่มีอาคารเลย เป็นตัวบอกว่าอยู่นอกเขตเมือง */
      '<g opacity=".45">' +
      '<rect x="20" y="18" width="150" height="52" rx="4" fill="' + tdShade(p.grass, .82) + '"/>' +
      '<rect x="230" y="24" width="140" height="46" rx="4" fill="' + tdShade(p.grass, .88) + '"/>' +
      '<rect x="50" y="210" width="160" height="44" rx="4" fill="' + tdShade(p.grass, .85) + '"/>' +
      '<rect x="250" y="206" width="130" height="48" rx="4" fill="' + tdShade(p.grass, .8) + '"/></g>' +
      tdTree(30, 40, 14) + tdTree(196, 26, 12) + tdTree(360, 222, 13) + tdTree(96, 236, 12) +
      tdPath('tdpA', 'M24 ' + eb + ' L380 ' + eb, TD_BLUE, 358, 1.2) +
      tdDrive(tdCar(0, 0, 0, TD_BLUE, 1, false) + tdStreak(-22, 4), 'tdpA', .001, TD_LOOP, 0) +
      tdStream('tdpOnc', 'M448 ' + wb + ' L-48 ' + wb, '#8a94a3', 8.4, 1, false);
  },

  /* คำถาม  ขี่จักรยานยนต์ขนาดทั่วไปบนถนนในเขตเทศบาลนครนครสวรรค์ ถนนโล่งและไม่มีป้ายจำกัดความเร็ว
     เหมือนข้อในเขตทุกอย่าง ต่างกันที่เราขี่จักรยานยนต์ ไม่ใช่รถยนต์
     ความต่างนี้สำคัญ เพราะกฎกระทรวงกำหนดความเร็วของสองประเภทนี้ไม่เท่ากัน */
  speedmoto: function (p) {
    var cy = 130, hh = 50, eb = cy - 25, wb = cy + 25;
    return tdRoadH(p, cy, hh) + tdDashH(p, cy, -4, 404) +
      tdLaneArrow(48, eb, 'e', p.line) + tdLaneArrow(356, wb, 'w', p.line) +
      tdBuilding(80, 32, 110, 44, '#7d8796', '#5c646f') +
      tdBuilding(200, 36, 100, 48, '#9a7350', '#6c4e34') +
      tdBuilding(320, 30, 104, 40, '#8f8a5e', '#635f40') +
      tdBuilding(140, 228, 140, 44, '#b4784a', '#7d5232') +
      tdBuilding(300, 226, 120, 42, '#7d8796', '#5c646f') +
      tdPath('tdpA', 'M30 ' + eb + ' L372 ' + eb, TD_BLUE, 344, 1.2) +
      tdDrive(tdMoto(0, 0, 0, 1, TD_BLUE) + tdStreak(-15, 4), 'tdpA', .001, TD_LOOP, 0) +
      tdStream('tdpOnc', 'M448 ' + wb + ' L-48 ' + wb, '#8a94a3', 6.4, 2, false);
  },

  /* คำถาม  ขับบนถนนแคบที่ไม่ได้ตีเส้นแบ่งกลาง กว้างประมาณห้าเมตร มีรถจอดและคนเดินอยู่ริมทาง
     ต้องเห็นครบสามอย่าง ถนนไม่มีเส้นแบ่งกลาง รถที่จอดริมทาง และคนที่เดินอยู่
     ความแคบต้องดูแคบจริง จึงวาดถนนบางกว่าฉากอื่นชัดเจน */
  narrownoline: function (p) {
    var cy = 132, hh = 30;
    return tdRoadH(p, cy, hh) +
      tdBuilding(90, 48, 140, 54, '#9a7350', '#6c4e34') +
      tdBuilding(280, 44, 150, 50, '#7d8796', '#5c646f') +
      tdBuilding(140, 226, 150, 46, '#b4784a', '#7d5232') +
      tdBuilding(320, 230, 120, 42, '#8f8a5e', '#635f40') +
      /* รถที่จอดริมทางฝั่งบน กินความกว้างที่แคบอยู่แล้วไปอีก */
      tdCar(214, cy - 18, 0, '#8a94a3', 1, false) +
      /* คนเดินอยู่ริมทางฝั่งล่าง ไม่มีทางเท้าให้เดิน */
      tdPerson(150, cy + hh + 12, '#f0b429') +
      tdCar(70, cy - 8, 0, TD_BLUE, 1, true) +
      tdPath('tdpA', 'M92 ' + (cy - 8) + ' L160 ' + (cy - 8) + ' Q194 ' + (cy - 8) + ' 198 ' + (cy + 12) + ' L286 ' + (cy + 12),
        TD_BLUE, 210, 1.4) +
      tdConflict(216, cy + 10);
  },

  /* ---------- สภาพรถและเหตุฉุกเฉิน ---------- */

  /* คำถาม  ขับรถลงจากทางลาดชันยาว มีคนแนะนำให้ใส่เกียร์ว่างเพื่อประหยัดน้ำมัน
     ความชันมองจากมุมสูงไม่เห็น จึงบอกด้วยแถบไล่เฉดกับลูกศรชี้ทางลง
     ต้องเห็นว่าทางลงยาว ไม่ใช่เนินสั้น ๆ */
  downhill: function (p) {
    var cy = 128, hh = 48, eb = cy - 24, wb = cy + 24;
    return tdRoadH(p, cy, hh) + tdDashH(p, cy, -4, 404) +
      tdSlope(p, cy, hh, -4, 260, -1) +
      tdLaneArrow(300, eb, 'e', p.line) + tdLaneArrow(300, wb, 'w', p.line) +
      tdTree(40, 36, 13) + tdTree(150, 34, 12) + tdTree(320, 230, 13) +
      /* เราลงเขาไปทางซ้าย จึงต้องอยู่ครึ่งล่างของถนน  รถสวนขึ้นเขาไปทางขวา อยู่ครึ่งบน
         ตรงกับลูกศรบนผิวถนนสองตัวข้างบนนี้ ซึ่งวางถูกอยู่แล้วตั้งแต่แรก
         ของเดิมสลับกัน รถเราจึงวิ่งสวนลูกศรของตัวเอง */
      tdPath('tdpA', 'M360 ' + wb + ' L40 ' + wb, TD_BLUE, 322, 1.2) +
      tdDrive(tdCar(0, 0, 0, TD_BLUE, 1, false) + tdStreak(-22, 4), 'tdpA', .5, TD_LOOP, 0) +
      tdStream('tdpOnc', 'M-48 ' + eb + ' L448 ' + eb, '#8a94a3', 8, 1, false);
  },

  /* คำถาม  ขับลงทางลาดยาวจากภูเขา เริ่มรู้สึกว่าเบรกเริ่มไม่ค่อยอยู่และมีกลิ่นไหม้
     ต่างจากข้อเกียร์ว่างตรงที่นี่เบรกร้อนแล้ว จึงต้องเห็นควันที่ล้อ
     และทางต้องคดโค้งแบบทางภูเขา ไม่ใช่ทางลาดตรง */
  brakefade: function (p) {
    var cy = 132, hh = 46;
    return '<path d="M-4 ' + (cy - 60) + ' C90 ' + (cy - 60) + ' 110 ' + (cy + 40) + ' 200 ' + (cy + 40) +
      ' C290 ' + (cy + 40) + ' 310 ' + (cy - 50) + ' 404 ' + (cy - 50) + '" fill="none" stroke="' + p.kerb +
      '" stroke-width="' + (hh * 2 + 14) + '"/>' +
      '<path d="M-4 ' + (cy - 60) + ' C90 ' + (cy - 60) + ' 110 ' + (cy + 40) + ' 200 ' + (cy + 40) +
      ' C290 ' + (cy + 40) + ' 310 ' + (cy - 50) + ' 404 ' + (cy - 50) + '" fill="none" stroke="' + p.road +
      '" stroke-width="' + (hh * 2) + '" id="tdpRoad"/>' +
      '<path d="M-4 ' + (cy - 60) + ' C90 ' + (cy - 60) + ' 110 ' + (cy + 40) + ' 200 ' + (cy + 40) +
      ' C290 ' + (cy + 40) + ' 310 ' + (cy - 50) + ' 404 ' + (cy - 50) + '" fill="none" stroke="' + p.line +
      '" stroke-width="2.4" stroke-dasharray="14 12" opacity=".85"/>' +
      tdSlope(p, cy, 8, 20, 150, -1) +
      tdTree(40, 36, 13) + tdTree(120, 232, 13) + tdTree(330, 226, 12) + tdTree(250, 30, 12) +
      /* เส้นทางลงเขา ไล่ตามแนวถนนที่คดโค้ง */
      '<path id="tdpA" d="M392 ' + (cy - 62) + ' C300 ' + (cy - 62) + ' 282 ' + (cy + 28) + ' 200 ' + (cy + 28) +
      ' C112 ' + (cy + 28) + ' 96 ' + (cy - 72) + ' 10 ' + (cy - 72) + '" fill="none" opacity="0"/>' +
      /* รถของเรา มีควันขึ้นที่ล้อเพราะเบรกร้อน */
      tdMove('<g>' + tdCar(0, 0, 0, TD_BLUE, 1, true) +
        '<circle cx="-14" cy="-13" r="7" fill="#e8eef4" opacity=".55">' +
        '<animate attributeName="r" values="5;11;5" dur="1.3s" repeatCount="indefinite"/>' +
        '<animate attributeName="opacity" values=".55;.12;.55" dur="1.3s" repeatCount="indefinite"/></circle>' +
        '<circle cx="-14" cy="13" r="7" fill="#e8eef4" opacity=".55">' +
        '<animate attributeName="r" values="5;11;5" dur="1.3s" begin=".4s" repeatCount="indefinite"/>' +
        '<animate attributeName="opacity" values=".55;.12;.55" dur="1.3s" begin=".4s" repeatCount="indefinite"/></circle>' +
        '</g>', 'tdpA', 9, 0);
  },

  /* คำถาม  รถเสียจอดค้างอยู่ริมถนนนอกเขตเทศบาล ย้ายออกจากทางเดินรถไม่ได้
     ต่างจากข้อรถเสียกลางคืนตรงที่นี่เป็นกลางวันและอยู่นอกเขตเมือง
     ยังไม่ได้วางเครื่องหมายอะไรไว้ ซึ่งเป็นสิ่งที่คำถามกำลังถาม */
  brokenrural: function (p) {
    var cy = 130, hh = 48, eb = cy - 24, wb = cy + 24;
    return tdRoadH(p, cy, hh) + tdDashH(p, cy, -4, 404) +
      tdLaneArrow(40, eb, 'e', p.line) + tdLaneArrow(360, wb, 'w', p.line) +
      tdTree(34, 38, 14) + tdTree(210, 28, 12) + tdTree(330, 232, 13) +
      /* รถเสียจอดค้างอยู่ในช่องทางเดินรถ เปิดไฟฉุกเฉินไว้อย่างเดียว */
      '<g>' + tdCar(250, eb, 0, TD_BLUE, 1, false) +
      '<circle cx="268" cy="' + (eb - 11) + '" r="3.6" fill="#f6a723">' +
      '<animate attributeName="opacity" values="1;.1;1" dur=".8s" repeatCount="indefinite"/></circle>' +
      '<circle cx="232" cy="' + (eb - 11) + '" r="3.6" fill="#f6a723">' +
      '<animate attributeName="opacity" values="1;.1;1" dur=".8s" repeatCount="indefinite"/></circle></g>' +
      tdFocus(250, eb, 32) +
      /* รถที่วิ่งมาจากด้านหลังด้วยความเร็วนอกเมือง */
      tdStream('tdpBack', 'M-120 ' + eb + ' L170 ' + eb, '#c2492f', 3.4, 1, false) +
      tdConflict(200, eb);
  },

  /* คำถาม  จะใช้เชือกลากรถของเพื่อนที่เสียไปอู่ เชือกที่มีอยู่ยาวประมาณหนึ่งเมตรครึ่ง
     ต้องเห็นรถสองคันผูกกันด้วยเชือกที่สั้นผิดปกติ
     ไม่วาดเส้นบอกระยะเป็นเมตร เพราะช่วงสามถึงห้าเมตรคือคำตอบ */
  towing: function (p) {
    var cy = 130, hh = 48, eb = cy - 24, wb = cy + 24;
    return tdRoadH(p, cy, hh) + tdDashH(p, cy, -4, 404) +
      tdLaneArrow(40, eb, 'e', p.line) + tdLaneArrow(360, wb, 'w', p.line) +
      tdTree(32, 34, 12) + tdTree(340, 234, 12) +
      /* รถสองคันผูกกันด้วยเชือกสั้น ระยะห่างจึงน้อยผิดปกติ */
      '<g>' +
      '<path id="tdpTow" d="M-90 ' + eb + ' L470 ' + eb + '" fill="none" opacity="0"/>' +
      tdMove(tdCar(0, 0, 0, TD_BLUE, 1, false), 'tdpTow', 7, 0) +
      tdMove('<g>' + tdCar(0, 0, 0, '#8a94a3', 1, false) +
        '<line x1="20" y1="0" x2="40" y2="0" stroke="#3d4654" stroke-width="3" stroke-linecap="round"/></g>',
        'tdpTow', 7, 0.5) +
      '</g>' +
      tdFocus(210, eb, 34) +
      tdStream('tdpOnc', 'M448 ' + wb + ' L-48 ' + wb, '#c2492f', 7.6, 1, false);
  },

  /* คำถาม  ต้องขนของยาวใส่ท้ายกระบะ ปลายของยื่นพ้นท้ายรถออกไปพอสมควร
     เป็นกลางวัน ยังไม่ได้ติดอะไรที่ปลายของ ซึ่งคือสิ่งที่คำถามถาม
     ของต้องยื่นพ้นท้ายให้เห็นชัด ไม่ใช่แค่เต็มกระบะ */
  overhang: function (p) {
    var cy = 130, hh = 48, eb = cy - 24, wb = cy + 24;
    return tdRoadH(p, cy, hh) + tdDashH(p, cy, -4, 404) +
      tdLaneArrow(40, eb, 'e', p.line) + tdLaneArrow(360, wb, 'w', p.line) +
      tdTree(34, 34, 12) + tdTree(330, 232, 12) +
      tdCar(250, eb, 0, TD_BLUE, 1, false) +
      tdLoad(230, eb, 62, '') +
      tdFocus(178, eb, 26) +
      tdStream('tdpBack', 'M-120 ' + eb + ' L130 ' + eb, '#c2492f', 4, 1, false) +
      tdStream('tdpOnc', 'M448 ' + wb + ' L-48 ' + wb, '#8a94a3', 7.4, 1, false);
  },

  /* คำถาม  ขนของยาวยื่นพ้นท้ายกระบะ และจะต้องขับกลับตอนกลางคืน ตอนนี้ผูกธงแดงไว้แล้ว
     ธงแดงต้องเห็นอยู่จริงตามที่โจทย์บอก และฉากต้องมืด
     ธงสีเข้มในความมืดจึงกลืนไปกับพื้น ซึ่งคือใจความของคำถาม */
  overhangnight: function (p) {
    var cy = 130, hh = 48, eb = cy - 24, wb = cy + 24;
    return tdRoadH(p, cy, hh) + tdDashH(p, cy, -4, 404) +
      tdLaneArrow(40, eb, 'e', p.line) + tdLaneArrow(360, wb, 'w', p.line) +
      tdTree(34, 34, 12) + tdTree(330, 232, 12) +
      tdCar(250, eb, 0, TD_BLUE, 1, false) +
      tdLoad(230, eb, 62, 'red') +
      tdFocus(164, eb, 26) +
      /* รถที่ตามมาข้างหลัง เปิดไฟหน้าอยู่ แต่ลำแสงยังไปไม่ถึงปลายของ */
      tdStream('tdpBack', 'M-120 ' + eb + ' L120 ' + eb, '#c2492f', 4, 1, true) +
      tdStream('tdpOnc', 'M448 ' + wb + ' L-48 ' + wb, '#8a94a3', 7.4, 1, true);
  },

  /* คำถาม  แตรรถเสียงเบามาก ต้องอยู่ใกล้ ๆ ถึงจะได้ยิน แต่ยังพอดังอยู่
     เสียงมองไม่เห็น จึงวาดเป็นคลื่นวงกลมรอบรถ
     คลื่นต้องแคบ คือไปได้ไม่ไกล ซึ่งเป็นตัวโจทย์ ไม่ใช่คำตอบ
     เพราะคำตอบคือต้องซ่อมก่อนใช้ ซึ่งภาพไม่ได้บอก */
  weakhorn: function (p) {
    var cy = 130, hh = 48, eb = cy - 24, wb = cy + 24;
    return tdRoadH(p, cy, hh) + tdDashH(p, cy, -4, 404) +
      tdLaneArrow(40, eb, 'e', p.line) + tdLaneArrow(360, wb, 'w', p.line) +
      tdTree(30, 32, 12) + tdTree(340, 234, 12) +
      tdCar(140, eb, 0, TD_BLUE, 1, false) +
      /* คลื่นเสียงแคบ ๆ ไปได้ไม่ไกล */
      '<g transform="translate(160,' + eb + ')" fill="none" stroke="#ffd166" stroke-width="2.6">' +
      '<path d="M8 -10 A13 13 0 0 1 8 10" opacity=".9">' +
      '<animate attributeName="opacity" values=".9;.2;.9" dur="1.1s" repeatCount="indefinite"/></path>' +
      '<path d="M18 -16 A21 21 0 0 1 18 16" opacity=".6">' +
      '<animate attributeName="opacity" values=".6;.1;.6" dur="1.1s" begin=".2s" repeatCount="indefinite"/></path>' +
      '</g>' +
      /* คนที่อยู่ไกลออกไป ยังไม่ได้ยินอะไรเลย */
      tdPerson(320, cy - hh - 16, '#3f6f9e') +
      tdStream('tdpOnc', 'M448 ' + wb + ' L-48 ' + wb, '#8a94a3', 7.4, 1, false);
  },

  /* คำถาม  รถคันหน้าออกตัวช้ากว่าปกติหลังไฟเขียว คุณรีบมาก
     ภาพเล่าแค่ไฟเขียวกับรถคันหน้าที่ยังไม่ขยับ ไม่วาดคลื่นเสียงแตร
     เพราะคำตอบที่ถูกคือไม่บีบ ถ้าวาดแตรลงไปจะกลายเป็นชี้นำว่าให้บีบ */
  hornrush: function (p) {
    var cy = 126, cx = 268, hh = 48, vh = 32, eb = cy - 24, wb = cy + 24, stop = cx - vh - 12;
    return tdRoadH(p, cy, hh) + tdRoadV(p, cx, vh) + tdCross(p, cx, cy, vh, hh) +
      tdDashH(p, cy, -4, cx - vh) + tdDashH(p, cy, cx + vh, 404) +
      tdDashV(p, cx, -4, cy - hh) + tdDashV(p, cx, cy + hh, 264) +
      tdLaneArrow(50, eb, 'e', p.line) + tdLaneArrow(50, wb, 'w', p.line) +
      tdLaneArrow(cx - 16, 246, 'n', p.line) + tdLaneArrow(cx + 16, 246, 's', p.line) +
      '<rect x="' + stop + '" y="' + (cy - hh) + '" width="5" height="' + hh + '" fill="' + p.line + '" opacity=".92"/>' +
      tdSignal(stop - 22, cy - hh - 16, 'green') +
      tdTree(50, 34, 12) + tdTree(140, 236, 12) +
      /* รถคันหน้ายังไม่ขยับ ไฟเบรกยังติดอยู่ */
      tdCar(stop - 26, eb, 0, '#8a94a3', 1, true) +
      tdCar(stop - 72, eb, 0, TD_BLUE, 1, true) +
      tdConflict(stop - 26, eb);
  },

  /* คำถาม  ขับผ่านมาพบอุบัติเหตุเพิ่งเกิดสด ๆ มีคนนอนอยู่ข้างรถจักรยานยนต์
     ต้องเห็นครบสามอย่าง รถจักรยานยนต์ล้ม คนนอนอยู่ข้าง ๆ และรถอื่นที่ยังวิ่งผ่าน
     รถที่ยังวิ่งผ่านสำคัญ เพราะอันตรายซ้ำซ้อนคือการถูกชนระหว่างเข้าไปช่วย */
  crashscene: function (p) {
    var cy = 130, hh = 48, eb = cy - 24, wb = cy + 24;
    return tdRoadH(p, cy, hh) + tdDashH(p, cy, -4, 404) +
      tdLaneArrow(40, eb, 'e', p.line) + tdLaneArrow(360, wb, 'w', p.line) +
      tdTree(34, 34, 12) + tdTree(330, 232, 12) +
      /* จักรยานยนต์ล้มนอนอยู่กับพื้น หมุนเอียงเพื่อให้อ่านว่าล้ม ไม่ใช่จอด */
      tdMoto(246, eb + 6, 24, 1, '#c2492f') +
      /* คนนอนอยู่ข้างรถ วาดเป็นรูปยาวแทนวงกลม เพราะนอนไม่ใช่ยืน */
      '<g transform="translate(268,' + (eb + 22) + ') rotate(14)">' +
      '<ellipse cx="3" cy="4" rx="19" ry="7" fill="rgba(0,0,0,.3)"/>' +
      '<rect x="-18" y="-6" width="36" height="12" rx="6" fill="#3f6f9e"/>' +
      '<circle cx="-20" cy="0" r="6" fill="#e0a878"/></g>' +
      tdFocus(258, eb + 14, 40) +
      tdCar(86, eb, 0, TD_BLUE, 1, true) +
      tdPath('tdpA', 'M106 ' + eb + ' L196 ' + eb, TD_BLUE, 94, 1.4) +
      /* รถที่ยังวิ่งผ่านไม่หยุด คืออันตรายซ้อนของจุดเกิดเหตุ */
      tdStream('tdpOnc', 'M448 ' + wb + ' L-48 ' + wb, '#8a94a3', 5.6, 2, false);
  },

  /* คำถาม  ลูกอายุสิบห้าปียังไม่มีใบขับขี่ ขอขี่จักรยานยนต์ไปโรงเรียนเองเพราะใกล้มาก
     ยังไม่ได้ออกจากบ้าน การตัดสินใจอยู่หน้าบ้าน จึงไม่มีถนนให้เห็นมาก
     ต้องเห็นบ้าน เห็นโรงเรียนที่อยู่ใกล้จริง และเห็นว่าคนขี่ตัวเล็กกว่าผู้ใหญ่ */
  teenrider: function (p) {
    var cy = 168, hh = 32, sx = 150;
    return tdRoadH(p, cy, hh) + tdDashH(p, cy, -4, 404) +
      tdLaneArrow(50, cy - 16, 'e', p.line) + tdLaneArrow(340, cy + 16, 'w', p.line) +
      /* บ้านเราอยู่ฝั่งบนซ้าย โรงเรียนอยู่ฝั่งบนขวา ใกล้กันจริงตามที่โจทย์บอก */
      tdBuilding(90, 64, 120, 62, '#9a7350', '#6c4e34') +
      tdBuilding(296, 56, 150, 66, '#b4784a', '#7d5232') +
      '<rect x="236" y="32" width="120" height="11" rx="4" fill="#c0562f"/>' +
      tdTree(196, 74, 14) +
      /* คนขี่ตัวเล็กกว่าปกติ วงไว้เพราะอายุคือทั้งหมดของคำถาม */
      tdMoto(150, cy - 16, 0, .92, TD_BLUE) +
      tdFocus(150, cy - 16, 26) +
      tdPath('tdpA', 'M' + (sx + 22) + ' ' + (cy - 16) + ' L296 ' + (cy - 16) + ' Q322 ' + (cy - 16) + ' 326 ' + 100 + ' L326 92',
        TD_BLUE, 220, 1.5) +
      tdStream('tdpOnc', 'M448 ' + (cy + 16) + ' L-48 ' + (cy + 16), '#8a94a3', 6.4, 2, false);
  }
};

(function () {
  var target = (typeof TD_SCENES !== 'undefined') ? TD_SCENES
             : (typeof window !== 'undefined' ? window.TD_SCENES : null);
  if (!target) { throw new Error('ต้องโหลด assets/scene-top.js ก่อน assets/scene-top7.js'); }
  Object.keys(TD_SCENES7).forEach(function (k) {
    if (target[k]) { throw new Error('ชื่อฉากซ้ำกับของเดิม: ' + k); }
    target[k] = TD_SCENES7[k];
  });
})();
