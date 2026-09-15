'use strict';
/* ============================================================
   ฉากชุดที่หก  กลุ่มแซงและสวนทาง กับกลุ่มทางแยกและทางม้าลาย
   ============================================================
   ต่อจาก scene-top.js ถึง scene-top5.js ต้องโหลดตามลำดับ

   กฎสองข้อเดิม
   หนึ่ง  ขับชิดซ้าย  วิ่งไปทางขวาของภาพอยู่ครึ่งบน วิ่งไปทางซ้ายอยู่ครึ่งล่าง
          การแซงจึงเป็นการออกไปอยู่ครึ่งล่าง ซึ่งเป็นเลนของรถที่สวนมา
          การเลี้ยวขวาจึงเป็นการตัดข้ามเลนสวน ส่วนเลี้ยวซ้ายไม่ต้องตัดใคร
   สอง   ภาพห้ามเฉลยคำตอบ  ห้ามวาดป้ายบังคับหรือเครื่องหมายห้าม
          วงแหวนจุดตัดสินใจใช้สีเหลืองซึ่งเป็นสีกลาง ไม่ใช่สีแดง

   หมายเหตุเรื่องกลุ่มแซง
     ทั้งแปดข้อในกลุ่มนี้ คำตอบที่ถูกคือไม่แซงหรือรอ
     ถ้าวาดฉากให้ดูอันตรายเกินจริง เช่นใส่รถสวนมาจ่ออยู่ตรงหน้า ก็คือเฉลย
     จึงวาดตามที่โจทย์บอกเป๊ะ ๆ คือข้างหน้าโล่งจริง เลนขวาว่างจริง
     สิ่งที่ทำให้แซงไม่ได้คือกติกาและระยะ ซึ่งเป็นสิ่งที่ผู้เล่นต้องรู้เอง
   ============================================================ */

var TD_SCENES6 = {

  /* ---------- กลุ่มแซงและสวนทาง ---------- */

  /* คำถาม  ใกล้จะถึงทางแยกอีกราวยี่สิบเมตร มีรถช้าอยู่ข้างหน้า จะแซงได้หรือไม่
     แยกต้องอยู่ใกล้พอให้เห็นว่าเส้นทางแซงไปจบตรงปากแยกพอดี
     ไม่วาดรถโผล่ออกมาจากแยก เพราะโจทย์ไม่ได้บอกว่ามี และการใส่เข้าไปคือการเฉลย */
  passjunction: function (p) {
    var cy = 124, cx = 300, hh = 48, vh = 30, eb = cy - 24, wb = cy + 24;
    return tdRoadH(p, cy, hh) + tdRoadV(p, cx, vh) + tdCross(p, cx, cy, vh, hh) +
      tdDashH(p, cy, -4, cx - vh) + tdDashH(p, cy, cx + vh, 404) +
      tdDashV(p, cx, -4, cy - hh) + tdDashV(p, cx, cy + hh, 264) +
      tdLaneArrow(48, eb, 'e', p.line) + tdLaneArrow(48, wb, 'w', p.line) +
      tdLaneArrow(cx - 15, 244, 'n', p.line) + tdLaneArrow(cx + 15, 244, 's', p.line) +
      tdTree(40, 32, 12) + tdTree(180, 236, 12) +
      tdCar(196, eb, 0, '#8a94a3', 1, true) +
      /* เส้นทางแซง ออกไปอยู่เลนสวนแล้ววกกลับ ปลายเส้นไปจบตรงปากแยกพอดี */
      tdPath('tdpA', 'M56 ' + eb + ' L126 ' + eb + ' Q162 ' + eb + ' 166 ' + wb + ' L236 ' + wb +
        ' Q268 ' + wb + ' 272 ' + eb + ' L' + (cx - vh) + ' ' + eb, TD_BLUE, 300, 1.3) +
      tdConflict(cx - vh + 6, cy) +
      tdDrive(tdCar(0, 0, 0, TD_BLUE, 1, false) + tdStreak(-22, 3), 'tdpA', .24, TD_LOOP, 0);
  },

  /* คำถาม  มีรถช้าอยู่ข้างหน้า และอีกราวยี่สิบเมตรข้างหน้าเป็นทางม้าลาย
     ไม่วาดคนเดินข้าม เพราะโจทย์ไม่ได้บอกว่ามีคน
     ประเด็นคือห้ามแซงใกล้ทางข้ามไม่ว่าจะมีคนหรือไม่ ถ้าวาดคนลงไปก็กลายเป็นคนละคำถาม */
  passzebra: function (p) {
    var cy = 124, hh = 48, eb = cy - 24, wb = cy + 24, zx = 300;
    return tdRoadH(p, cy, hh) + tdDashH(p, cy, -4, 404) +
      tdZebra(p, zx, cy - hh, cy + hh, 7) +
      tdLaneArrow(48, eb, 'e', p.line) + tdLaneArrow(48, wb, 'w', p.line) +
      tdBuilding(90, 40, 120, 48, '#7d8796', '#5c646f') + tdTree(200, 236, 12) +
      tdCar(200, eb, 0, '#8a94a3', 1, true) +
      tdPath('tdpA', 'M56 ' + eb + ' L128 ' + eb + ' Q164 ' + eb + ' 168 ' + wb + ' L238 ' + wb +
        ' Q270 ' + wb + ' 274 ' + eb + ' L' + (zx - 22) + ' ' + eb, TD_BLUE, 300, 1.3) +
      tdConflict(zx - 20, cy) +
      tdDrive(tdCar(0, 0, 0, TD_BLUE, 1, false) + tdStreak(-22, 3), 'tdpA', .24, TD_LOOP, 0);
  },

  /* คำถาม  กำลังขับขึ้นสะพาน มีรถช้าอยู่ข้างหน้า เลนขวาว่างและมองไม่เห็นยอดสะพาน
     ใจความคือมองไม่เห็นสิ่งที่อยู่พ้นยอดสะพาน ภาพจึงต้องมีม่านบังจริง
     ถ้าเห็นทะลุไปถึงปลายสะพาน คำถามจะไม่เหลืออะไรให้คิด */
  passbridge: function (p) {
    var cy = 126, hh = 48, eb = cy - 24, wb = cy + 24;
    return tdRoadH(p, cy, hh) + tdDashH(p, cy, -4, 404) +
      /* ตัวสะพาน พื้นสว่างกว่าถนนและมีราวสองข้าง */
      '<g>' +
      '<rect x="150" y="' + (cy - hh - 10) + '" width="254" height="' + (hh * 2 + 20) + '" fill="#57606d"/>' +
      '<rect x="150" y="' + (cy - hh - 10) + '" width="254" height="9" fill="#8d97a6"/>' +
      '<rect x="150" y="' + (cy + hh + 1) + '" width="254" height="9" fill="#8d97a6"/>' +
      '<rect x="150" y="' + (cy - hh - 10) + '" width="16" height="' + (hh * 2 + 20) + '" fill="rgba(0,0,0,.18)"/>' +
      '</g>' +
      tdLaneArrow(48, eb, 'e', p.line) + tdLaneArrow(48, wb, 'w', p.line) +
      tdTree(40, 34, 12) + tdTree(60, 234, 12) +
      tdCar(236, eb, 0, '#8a94a3', 1, true) +
      tdPath('tdpA', 'M50 ' + eb + ' L140 ' + eb + ' Q178 ' + eb + ' 182 ' + wb + ' L266 ' + wb, TD_BLUE, 240, 1.3) +
      tdConflict(300, cy) +
      tdDrive(tdCar(0, 0, 0, TD_BLUE, 1, false) + tdStreak(-22, 3), 'tdpA', .3, TD_LOOP, 0) +
      /* ยอดสะพาน  พ้นจากนี้ไปมองไม่เห็นอะไรเลย จึงเป็นม่านทึบ ไม่ใช่แค่จาง */
      '<rect x="322" y="-4" width="82" height="268" fill="url(#tdFog)"/>';
  },

  /* คำถาม  ฝนตกจนมองข้างหน้าได้ไม่ไกล มีรถช้าอยู่ข้างหน้าและเลนสวนดูเหมือนว่าง
     เลนสวนต้องว่างจริงตามที่โจทย์บอก ห้ามแอบวางรถสวนไว้ในม่านฝนเพื่อให้ดูอันตราย
     เพราะประเด็นคือมองไม่เห็น ไม่ใช่ว่ามีรถอยู่จริงหรือไม่ */
  passrain: function (p) {
    var cy = 126, hh = 48, eb = cy - 24, wb = cy + 24;
    return tdRoadH(p, cy, hh) + tdDashH(p, cy, -4, 404) +
      '<rect x="-4" y="' + (cy - hh) + '" width="408" height="' + (hh * 2) + '" fill="#9fc4e8" opacity=".18"/>' +
      tdLaneArrow(44, eb, 'e', p.line) + tdLaneArrow(44, wb, 'w', p.line) +
      tdTree(30, 32, 12) + tdTree(80, 234, 12) +
      tdCar(214, eb, 0, '#8a94a3', 1, true) +
      tdPath('tdpA', 'M46 ' + eb + ' L128 ' + eb + ' Q166 ' + eb + ' 170 ' + wb + ' L250 ' + wb, TD_BLUE, 230, 1.3) +
      tdConflict(276, cy) +
      tdDrive(tdCar(0, 0, 0, TD_BLUE, 1, false) + tdStreak(-22, 3), 'tdpA', .3, TD_LOOP, 0) +
      tdRainDrops(38, .64, '.72') +
      '<rect x="258" y="-4" width="146" height="268" fill="url(#tdFog)"/>';
  },

  /* คำถาม  บนถนนที่มีช่องเดินรถทิศทางเดียวกันเพียงช่องเดียว
             รถคันหน้าวิ่งช้าและชิดขวา เลนซ้ายว่าง

     ชิดขวาแปลว่าเขาเบียดไปทางเส้นแบ่งกลาง ซึ่งคือด้านล่างของช่องเรา
     ช่องว่างที่เหลือจึงอยู่ด้านบน คือด้านที่ติดขอบทาง
     ต้องวาดให้เห็นว่าช่องนั้นแคบและติดขอบทาง ไม่ใช่ช่องเดินรถอีกช่องหนึ่ง */
  passleft: function (p) {
    var cy = 126, hh = 48, eb = cy - 24, wb = cy + 24, ky = cy - hh;
    return tdRoadH(p, cy, hh) + tdSolidH(p, cy, -4, 404, 3) +
      tdLaneArrow(44, eb, 'e', p.line) + tdLaneArrow(356, wb, 'w', p.line) +
      tdBuilding(120, 38, 140, 46, '#9a7350', '#6c4e34') + tdTree(300, 236, 12) +
      /* รถคันหน้าเบียดลงมาชิดเส้นแบ่งกลาง ช่องที่เหลือจึงอยู่ด้านบนติดขอบทาง */
      tdCar(220, cy - 13, 0, '#8a94a3', 1, true) +
      tdPath('tdpA', 'M48 ' + eb + ' L146 ' + eb + ' Q186 ' + eb + ' 190 ' + (ky + 12) + ' L286 ' + (ky + 12),
        TD_BLUE, 250, 1.3) +
      tdConflict(228, ky + 12) +
      tdDrive(tdCar(0, 0, 0, TD_BLUE, 1, false) + tdStreak(-22, 3), 'tdpA', .3, TD_LOOP, 0) +
      tdStream('tdpOnc', 'M448 ' + wb + ' L-48 ' + wb, '#c2492f', 8, 1, false);
  },

  /* คำถาม  ขับรถกระบะเข้าซอยแคบ มีรถจักรยานยนต์สวนมา ถนนแคบจนสวนกันได้ลำบาก
     ซอยแคบจึงไม่มีเส้นแบ่งกลาง และมีอาคารประชิดสองข้าง
     เราเป็นคันใหญ่กว่า ซึ่งเป็นใจความของกติกาข้อนี้ จึงต้องเห็นว่าใครใหญ่กว่าใคร */
  narrowsoi: function (p) {
    var cy = 128, hh = 30;
    return tdRoadH(p, cy, hh) +
      tdBuilding(80, 44, 130, 50, '#9a7350', '#6c4e34') +
      tdBuilding(250, 40, 150, 46, '#7d8796', '#5c646f') +
      tdBuilding(110, 224, 140, 48, '#b4784a', '#7d5232') +
      tdBuilding(290, 228, 130, 44, '#8f8a5e', '#635f40') +
      /* ไม่มีเส้นแบ่งกลาง เพราะซอยกว้างไม่ถึงหกเมตร */
      tdCar(108, cy - 9, 0, TD_BLUE, 1, true) +
      tdStream('tdpOnc', 'M430 ' + (cy + 9) + ' L-30 ' + (cy + 9), TD_RED, 7.2, 1, false, true) +
      tdPath('tdpA', 'M130 ' + (cy - 9) + ' L268 ' + (cy - 9), TD_BLUE, 142, 1.3) +
      tdConflict(248, cy);
  },

  /* คำถาม  ขับรถเก๋งเข้าทางแคบ มีรถบรรทุกสวนมา ถนนแคบจนสวนกันไม่ได้
     กลับกันกับข้อบน คราวนี้เราเป็นคันเล็กกว่า
     สองข้อนี้ต้องวาดให้เห็นชัดว่าใครใหญ่กว่า เพราะกติกาผูกกับขนาดรถโดยตรง */
  narrowtruck: function (p) {
    var cy = 128, hh = 32;
    return tdRoadH(p, cy, hh) +
      tdTree(50, 40, 14) + tdTree(320, 44, 13) +
      tdTree(90, 226, 13) + tdTree(300, 232, 14) +
      tdCar(92, cy - 10, 0, TD_BLUE, 1, true) +
      tdStream('tdpOnc', 'M470 ' + (cy + 10) + ' L-70 ' + (cy + 10), '#8a94a3', 9, 1, false) +
      tdTruck(300, cy + 10, 180, 1, false) +
      tdPath('tdpA', 'M114 ' + (cy - 10) + ' L232 ' + (cy - 10), TD_BLUE, 122, 1.3) +
      tdConflict(246, cy);
  },

  /* คำถาม  เลนของเรามีรถจอดเสียขวางอยู่ ต้องหลบล้ำออกไปทางขวา แต่มีรถสวนมาพอดี
     ต้องเห็นครบสามอย่าง รถที่จอดขวางเลนเรา เส้นทางที่ต้องล้ำออกไป และรถที่สวนมา
     รถสวนต้องวิ่งอยู่จริงและต่อเนื่อง ไม่ใช่จอดรออยู่เฉย ๆ */
  obstacle: function (p) {
    var cy = 126, hh = 48, eb = cy - 24, wb = cy + 24;
    return tdRoadH(p, cy, hh) + tdDashH(p, cy, -4, 404) +
      tdLaneArrow(40, eb, 'e', p.line) + tdLaneArrow(40, wb, 'w', p.line) +
      tdTree(34, 32, 12) + tdTree(120, 236, 12) +
      /* รถจอดเสียขวางเลนเรา เปิดไฟฉุกเฉินไว้ */
      '<g>' + tdCar(222, eb, 0, '#8a94a3', 1, false) +
      '<circle cx="240" cy="' + (eb - 11) + '" r="3.6" fill="#f6a723">' +
      '<animate attributeName="opacity" values="1;.1;1" dur=".8s" repeatCount="indefinite"/></circle>' +
      '<circle cx="204" cy="' + (eb - 11) + '" r="3.6" fill="#f6a723">' +
      '<animate attributeName="opacity" values="1;.1;1" dur=".8s" repeatCount="indefinite"/></circle></g>' +
      tdPath('tdpA', 'M44 ' + eb + ' L140 ' + eb + ' Q182 ' + eb + ' 186 ' + wb + ' L262 ' + wb +
        ' Q294 ' + wb + ' 298 ' + eb + ' L372 ' + eb, TD_BLUE, 320, 1.4) +
      tdConflict(224, wb) +
      tdDrive(tdCar(0, 0, 0, TD_BLUE, 1, true) + tdStreak(-22, 3), 'tdpA', .26, TD_LOOP, 0) +
      tdStream('tdpOnc', 'M448 ' + wb + ' L-48 ' + wb, '#c2492f', 6.4, 2, false);
  },

  /* ---------- กลุ่มทางแยกและทางม้าลาย ---------- */

  /* คำถาม  เข้าใกล้ทางม้าลายที่ไม่มีสัญญาณไฟ มีคนกำลังเดินข้ามอยู่กลางทาง
     คนต้องอยู่กลางทางจริงตามโจทย์ และต้องเดินอยู่ ไม่ใช่ยืนนิ่ง
     ไม่มีเสาสัญญาณไฟในฉากนี้ เพราะโจทย์บอกว่าไม่มี */
  zebrawalk: function (p) {
    var cy = 126, hh = 48, eb = cy - 24, wb = cy + 24, zx = 252;
    return tdRoadH(p, cy, hh) + tdDashH(p, cy, -4, 404) +
      tdZebra(p, zx, cy - hh, cy + hh, 7) +
      tdLaneArrow(46, eb, 'e', p.line) + tdLaneArrow(360, wb, 'w', p.line) +
      tdBuilding(110, 40, 130, 46, '#7d8796', '#5c646f') + tdTree(330, 234, 12) +
      /* คนเดินข้ามอยู่กลางทาง เดินจากขอบล่างขึ้นไปขอบบน */
      '<g>' + tdPerson(0, 0, '#f0b429') +
      '<animateMotion dur="6s" repeatCount="indefinite" rotate="0">' +
      '<mpath href="#tdpWalk"/></animateMotion></g>' +
      '<path id="tdpWalk" d="M' + zx + ' ' + (cy + hh + 10) + ' L' + zx + ' ' + (cy - hh - 10) + '" fill="none" opacity="0"/>' +
      tdPath('tdpA', 'M48 ' + eb + ' L' + (zx - 30) + ' ' + eb, TD_BLUE, 180, 1.2) +
      tdConflict(zx, eb) +
      tdDrive(tdCar(0, 0, 0, TD_BLUE, 1, true) + tdStreak(-22, 3), 'tdpA', .42, TD_LOOP, 0);
  },

  /* คำถาม  รถคันหน้าหยุดนิ่งอยู่ตรงทางม้าลายโดยไม่มีไฟแดง เลนขวาว่าง
     เราอยู่หลังคันที่หยุด ต่างจากอีกข้อหนึ่งที่เราอยู่คนละช่องกับคันที่หยุด
     คนเดินข้ามถูกตัวรถที่หยุดบังไว้พอดี จึงวาดให้โผล่มาแค่ครึ่งตัว
     ไม่ได้เป็นการเฉลย เพราะคำตอบที่ผิดคือแซง ซึ่งภาพไม่ได้บอกว่าแซงไม่ได้ */
  zebraqueue: function (p) {
    var cy = 130, hh = 56, l1 = cy - 42, l2 = cy - 15, zx = 262;
    return tdRoadH(p, cy, hh) + tdSolidH(p, cy, -4, 404, 3) +
      tdDashH(p, cy - 28, -4, 404) + tdDashH(p, cy + 28, -4, 404) +
      tdZebra(p, zx, cy - hh, cy + hh, 7) +
      tdLaneArrow(44, l1, 'e', p.line) + tdLaneArrow(44, l2, 'e', p.line) +
      tdLaneArrow(364, cy + 15, 'w', p.line) + tdLaneArrow(364, cy + 42, 'w', p.line) +
      tdBuilding(110, 34, 130, 40, '#9a7350', '#6c4e34') +
      /* รถคันหน้าหยุดสนิทอยู่ก่อนถึงทางม้าลาย */
      tdCar(zx - 40, l1, 0, '#c2492f', 1, true) +
      /* คนเดินข้ามโผล่พ้นหัวรถที่หยุดมาแค่ครึ่งตัว */
      tdPerson(zx, cy - hh - 2, '#f0b429') +
      tdPath('tdpA', 'M48 ' + l1 + ' L' + (zx - 70) + ' ' + l1, TD_BLUE, 150, 1.2) +
      tdConflict(zx, l1) +
      tdDrive(tdCar(0, 0, 0, TD_BLUE, 1, true) + tdStreak(-22, 3), 'tdpA', .44, TD_LOOP, 0);
  },

  /* คำถาม  ยืนอยู่ริมถนนและจะข้ามไปอีกฝั่ง มองไปทางซ้ายเห็นทางม้าลายอยู่ห่างราวห้าสิบเมตร
             แต่ตรงจุดที่ยืนอยู่รถน้อยกว่า
     เราเป็นคนเดินเท้า จึงไม่มีรถสีน้ำเงินในฉากนี้
     ทางม้าลายต้องอยู่ทางซ้ายและห่างออกไปจริง ตามที่โจทย์บอก */
  crosswalk: function (p) {
    var cy = 128, hh = 50, eb = cy - 25, wb = cy + 25, zx = 66, me = cy + hh + 14;
    return tdRoadH(p, cy, hh) + tdDashH(p, cy, -4, 404) +
      tdZebra(p, zx, cy - hh, cy + hh, 7) +
      tdLaneArrow(200, eb, 'e', p.line) + tdLaneArrow(200, wb, 'w', p.line) +
      tdBuilding(240, 40, 160, 48, '#7d8796', '#5c646f') +
      tdBuilding(250, 230, 150, 44, '#b4784a', '#7d5232') +
      tdStream('tdpE', 'M-48 ' + eb + ' L448 ' + eb, '#8a94a3', 6.4, 2, false) +
      tdStream('tdpW', 'M448 ' + wb + ' L-48 ' + wb, '#c2492f', 7, 2, false) +
      /* เราคือคนที่ยืนอยู่ริมถนน ยังไม่ได้ก้าวลงไป */
      tdPerson(250, me, '#3f6f9e') +
      /* เส้นทางที่กำลังคิดจะทำ คือข้ามตรงจุดที่ยืนอยู่ */
      tdPath('tdpA', 'M250 ' + (me - 10) + ' L250 ' + (cy - hh - 12), TD_BLUE, 110, 1.4) +
      tdConflict(250, cy);
  },

  /* คำถาม  ขับตรงผ่านทางแยก มีคนบอกว่าให้เปิดไฟฉุกเฉินไว้เพื่อบอกคนอื่นว่าเราจะไปตรง
     ต้องเห็นว่ารถของเราเปิดไฟฉุกเฉินอยู่จริง คือไฟกะพริบทั้งสี่มุม
     และต้องมีรถในทางขวางที่กำลังรอ เพราะคนที่เดือดร้อนจากไฟฉุกเฉินคือเขา */
  hazardthru: function (p) {
    var cy = 126, cx = 214, hh = 48, vh = 32, eb = cy - 24, wb = cy + 24, nb = cx - 16;
    return tdRoadH(p, cy, hh) + tdRoadV(p, cx, vh) + tdCross(p, cx, cy, vh, hh) +
      tdDashH(p, cy, -4, cx - vh) + tdDashH(p, cy, cx + vh, 404) +
      tdDashV(p, cx, -4, cy - hh) + tdDashV(p, cx, cy + hh, 264) +
      tdLaneArrow(48, eb, 'e', p.line) + tdLaneArrow(360, wb, 'w', p.line) +
      tdLaneArrow(nb, 246, 'n', p.line) + tdLaneArrow(cx + 16, 246, 's', p.line) +
      tdTree(56, 34, 12) + tdTree(340, 232, 12) +
      /* รถในทางขวางที่รออยู่ เขาคือคนที่ต้องเดาว่าเราจะไปทางไหน */
      tdCar(nb, cy + hh + 30, -90, '#c2492f', 1, true) +
      /* รถของเรา เปิดไฟฉุกเฉินอยู่ กะพริบพร้อมกันทั้งสี่มุม */
      '<g>' + tdCar(96, eb, 0, TD_BLUE, 1, false) +
      '<g fill="#f6a723"><circle cx="114" cy="' + (eb - 11) + '" r="3.4"/><circle cx="114" cy="' + (eb + 11) + '" r="3.4"/>' +
      '<circle cx="78" cy="' + (eb - 11) + '" r="3.4"/><circle cx="78" cy="' + (eb + 11) + '" r="3.4"/>' +
      '<animate attributeName="opacity" values="1;.1;1" dur=".8s" repeatCount="indefinite"/></g></g>' +
      tdPath('tdpA', 'M120 ' + eb + ' L372 ' + eb, TD_BLUE, 254, 1.2) +
      tdConflict(nb, eb);
  },

  /* คำถาม  อีกไม่ถึงสิบเมตรจะถึงทางเลี้ยวที่ต้องการ คุณเพิ่งนึกได้ว่าลืมเปิดไฟเลี้ยว
     ระยะที่เหลือต้องดูสั้นมากจริง ๆ เพราะนั่นคือทั้งหมดของคำถาม
     รถของเราไม่มีไฟเลี้ยวติด ซึ่งเป็นสิ่งที่โจทย์บอกอยู่แล้ว ไม่ใช่การเฉลย */
  turnsignal: function (p) {
    var cy = 124, hh = 46, eb = cy - 23, wb = cy + 23, sx = 250, vh = 26;
    return tdRoadV(p, sx, vh, -4, cy - hh) + tdRoadH(p, cy, hh) +
      tdMouth(p, sx, vh, cy - hh - 7, 9) +
      tdDashH(p, cy, -4, 404) + tdDashV(p, sx, -4, cy - hh) +
      tdLaneArrow(48, eb, 'e', p.line) + tdLaneArrow(360, wb, 'w', p.line) +
      tdLaneArrow(sx - 13, 40, 'n', p.line) + tdLaneArrow(sx + 13, 40, 's', p.line) +
      tdBuilding(110, 42, 130, 48, '#9a7350', '#6c4e34') + tdTree(120, 232, 12) +
      /* รถที่ตามหลังมา เขาคือคนที่ต้องรู้ล่วงหน้าว่าเราจะเลี้ยว */
      tdStream('tdpBack', 'M-70 ' + eb + ' L150 ' + eb, '#c2492f', 4.2, 1, false) +
      tdCar(196, eb, 0, TD_BLUE, 1, true) +
      /* เส้นทางเลี้ยวซ้ายเข้าซอย เหลือระยะสั้นมากก่อนถึงปากซอย */
      tdPath('tdpA', 'M216 ' + eb + ' L' + (sx - 24) + ' ' + eb + ' Q' + (sx - 13) + ' ' + eb + ' ' +
        (sx - 13) + ' ' + (eb - 30) + ' L' + (sx - 13) + ' -6', TD_BLUE, 160, 1.3) +
      tdConflict(sx - 13, eb - 14);
  },

  /* คำถาม  ไฟเลี้ยวข้างขวาเสีย และอีกไม่ไกลข้างหน้าต้องเลี้ยวขวาเข้าซอย รถตามหลังมาอยู่หลายคัน
     เลี้ยวขวาคือตัดข้ามเลนสวน ซอยจึงต้องอยู่ด้านล่างของภาพ
     ต้องเห็นรถตามหลังหลายคันจริง เพราะนั่นคือเหตุผลที่ต้องให้สัญญาณ */
  handsignal: function (p) {
    var cy = 118, hh = 46, eb = cy - 23, wb = cy + 23, sx = 264, vh = 26;
    return tdRoadV(p, sx, vh, cy + hh, 264) + tdRoadH(p, cy, hh) +
      tdMouth(p, sx, vh, cy + hh, 9) +
      tdDashH(p, cy, -4, 404) + tdDashV(p, sx, cy + hh, 264) +
      tdLaneArrow(48, eb, 'e', p.line) + tdLaneArrow(360, wb, 'w', p.line) +
      tdLaneArrow(sx - 13, 240, 'n', p.line) + tdLaneArrow(sx + 13, 240, 's', p.line) +
      tdBuilding(120, 38, 140, 44, '#7d8796', '#5c646f') +
      /* รถตามหลังมาหลายคันต่อเนื่อง */
      tdStream('tdpBack', 'M-140 ' + eb + ' L120 ' + eb, '#c2492f', 4.6, 3, false) +
      tdCar(182, eb, 0, TD_BLUE, 1, true) +
      /* เลี้ยวขวาเข้าซอย ต้องตัดข้ามเลนสวนก่อน */
      tdPath('tdpA', 'M202 ' + eb + ' L' + (sx + 4) + ' ' + eb + ' Q' + (sx + 13) + ' ' + eb + ' ' +
        (sx + 13) + ' ' + (cy + hh + 20) + ' L' + (sx + 13) + ' 252', TD_BLUE, 200, 1.4) +
      tdConflict(sx + 13, wb) +
      tdStream('tdpOnc', 'M448 ' + wb + ' L-48 ' + wb, '#8a94a3', 7.4, 2, false);
  },

  /* คำถาม  กลางทางแยกตีกรอบเส้นทแยงสีเหลืองไว้ เรากำลังรอเลี้ยวขวาและต้องหยุดรอรถสวน
     ต้องเห็นว่ารถของเราเข้าไปรออยู่ในกรอบแล้ว และมีรถสวนวิ่งต่อเนื่องจนออกไม่ได้
     ถ้าเลนสวนว่าง คำถามจะไม่มีเหตุผลให้ต้องรอ */
  yellowbox: function (p) {
    var cy = 126, cx = 214, hh = 48, vh = 34, eb = cy - 24, wb = cy + 24;
    return tdRoadH(p, cy, hh) + tdRoadV(p, cx, vh) + tdCross(p, cx, cy, vh, hh) +
      tdDashH(p, cy, -4, cx - vh) + tdDashH(p, cy, cx + vh, 404) +
      tdDashV(p, cx, -4, cy - hh) + tdDashV(p, cx, cy + hh, 264) +
      tdYellowBox(cx - vh, cy - hh, cx + vh, cy + hh) +
      tdLaneArrow(50, eb, 'e', p.line) + tdLaneArrow(366, wb, 'w', p.line) +
      tdLaneArrow(cx - 17, 246, 'n', p.line) + tdLaneArrow(cx + 17, 246, 's', p.line) +
      tdTree(52, 34, 12) +
      /* รถของเราเข้าไปรอเลี้ยวขวาอยู่ในกรอบแล้ว */
      tdCar(cx - 8, eb, 0, TD_BLUE, 1, true) +
      tdPath('tdpA', 'M' + (cx + 10) + ' ' + eb + ' Q' + (cx + 17) + ' ' + eb + ' ' + (cx + 17) + ' ' + (cy + hh + 16) +
        ' L' + (cx + 17) + ' 250', TD_BLUE, 150, 1.4) +
      tdConflict(cx + 17, wb) +
      /* รถสวนวิ่งต่อเนื่อง จึงยังออกจากกรอบไปไม่ได้ */
      tdStream('tdpOnc', 'M448 ' + wb + ' L-48 ' + wb, '#c2492f', 5.4, 3, false);
  },

  /* คำถาม  ได้ยินเสียงไซเรนรถพยาบาลมาจากด้านหลัง ขณะนั้นเรากำลังจะถึงทางแยกพอดี
     ต้องเห็นรถพยาบาลตามมาจากด้านหลังจริง และเห็นว่าแยกอยู่ตรงหน้าพอดี
     สองอย่างนี้พร้อมกันคือทั้งหมดของคำถาม */
  emergency: function (p) {
    var cy = 126, cx = 286, hh = 48, vh = 32, eb = cy - 24, wb = cy + 24;
    return tdRoadH(p, cy, hh) + tdRoadV(p, cx, vh) + tdCross(p, cx, cy, vh, hh) +
      tdDashH(p, cy, -4, cx - vh) + tdDashH(p, cy, cx + vh, 404) +
      tdDashV(p, cx, -4, cy - hh) + tdDashV(p, cx, cy + hh, 264) +
      tdLaneArrow(40, eb, 'e', p.line) + tdLaneArrow(40, wb, 'w', p.line) +
      tdLaneArrow(cx - 16, 246, 'n', p.line) + tdLaneArrow(cx + 16, 246, 's', p.line) +
      tdTree(44, 34, 12) + tdTree(140, 236, 12) +
      /* รถพยาบาลตามมาจากด้านหลัง ไฟวับวาบแดงน้ำเงินสลับกัน */
      '<g>' +
      '<path id="tdpAmb" d="M-80 ' + eb + ' L140 ' + eb + '" fill="none" opacity="0"/>' +
      tdMove('<g>' + tdCar(0, 0, 0, '#f2f5f8', 1.15, false) +
        '<rect x="-8" y="-11" width="16" height="4" rx="2" fill="#d0342c">' +
        '<animate attributeName="fill" values="#d0342c;#1d4ed8;#d0342c" dur=".5s" repeatCount="indefinite"/></rect>' +
        '<rect x="-8" y="7" width="16" height="4" rx="2" fill="#1d4ed8">' +
        '<animate attributeName="fill" values="#1d4ed8;#d0342c;#1d4ed8" dur=".5s" repeatCount="indefinite"/></rect>' +
        '</g>', 'tdpAmb', 3.6, 0) + '</g>' +
      /* รถของเรา กำลังจะถึงปากแยกพอดี */
      tdCar(200, eb, 0, TD_BLUE, 1, true) +
      tdPath('tdpA', 'M218 ' + eb + ' L' + (cx - vh - 6) + ' ' + eb, TD_BLUE, 46, 1.4) +
      tdConflict(cx - vh + 4, eb);
  }
};

(function () {
  var target = (typeof TD_SCENES !== 'undefined') ? TD_SCENES
             : (typeof window !== 'undefined' ? window.TD_SCENES : null);
  if (!target) { throw new Error('ต้องโหลด assets/scene-top.js ก่อน assets/scene-top6.js'); }
  Object.keys(TD_SCENES6).forEach(function (k) {
    if (target[k]) { throw new Error('ชื่อฉากซ้ำกับของเดิม: ' + k); }
    target[k] = TD_SCENES6[k];
  });
})();
