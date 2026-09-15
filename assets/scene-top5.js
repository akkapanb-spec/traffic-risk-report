'use strict';
/* ============================================================
   ฉากชุดที่ห้า  กลุ่มกลางคืนกับทัศนวิสัย และกลุ่มเส้นจราจรบนผิวถนน
   ============================================================
   ต่อจาก scene-top.js ถึง scene-top4.js ต้องโหลดตามลำดับ

   ============================================================
   รถวิ่งสวนมาต่อเนื่อง
   ============================================================
   ฉากกลางคืนรุ่นเดิมมีรถสวนมาคันเดียวแล้วหายไป ถนนจึงดูร้าง
   ซึ่งขัดกับโจทย์ที่บอกว่ารถคันอื่นเริ่มทยอยเปิดไฟหน้ากันแล้ว
   ถ้าไม่มีรถคันอื่นให้เห็น ประโยคนั้นในโจทย์ก็ลอยอยู่เฉย ๆ

   tdStream จึงปล่อยรถออกมาเป็นสายต่อเนื่อง เหลื่อมเวลากันเท่า ๆ กัน
   ไม่มีช่วงที่ถนนว่างเลย และไม่มีรอยต่อให้เห็นว่าวนกลับไปเริ่มใหม่ตอนไหน

   ============================================================
   กฎสองข้อเดิม ใช้กับไฟล์นี้เหมือนกัน
   ============================================================
   หนึ่ง  ขับชิดซ้าย  วิ่งไปทางขวาของภาพอยู่ครึ่งบน วิ่งไปทางซ้ายอยู่ครึ่งล่าง
          รถที่สวนมาจึงผ่านทางขวามือของเราเสมอ
   สอง   ภาพห้ามเฉลยคำตอบ  ห้ามวาดป้ายบังคับหรือเครื่องหมายห้าม
          เว้นแต่คำถามข้อนั้นถามความหมายของเครื่องหมายนั้นตรง ๆ
   ============================================================ */

/* สายรถที่วิ่งต่อเนื่อง  ปล่อยออกมา k คันเหลื่อมเวลากันเท่า ๆ กันบนเส้นทางเดียว
   lit จริงคือเปิดไฟหน้า ใช้กับฉากกลางคืนและฉากที่ทัศนวิสัยไม่ดี */
function tdStream(id, d, col, dur, k, lit, moto) {
  var out = '<path id="' + id + '" d="' + d + '" fill="none" opacity="0"/>', i, body;
  for (i = 0; i < k; i++) {
    body = moto ? tdMoto(0, 0, 0, 1, col) : tdCar(0, 0, 0, col, 1, false);
    if (lit) { body += tdBeam(22, 0, 'e', 74, 26, .2); }
    out += tdMove(body, id, dur, (dur / k) * i);
  }
  return out;
}

/* เส้นทึบขวางถนน  ใช้กับเส้นแนวหยุด  หนากว่าเส้นแบ่งช่องมาก */
function tdStopBar(p, x, y1, y2) {
  return '<rect x="' + x + '" y="' + y1 + '" width="7" height="' + (y2 - y1) + '" fill="' + p.line + '" opacity=".95"/>';
}
/* เส้นประหนาขวางถนน  ใช้กับเส้นให้ทาง  ช่วงสั้นเว้นสั้นตามของจริง */
function tdYieldBar(p, x, y1, y2) {
  var out = '', y;
  for (y = y1; y < y2 - 6; y += 16) {
    out += '<rect x="' + x + '" y="' + y + '" width="7" height="10" fill="' + p.line + '" opacity=".95"/>';
  }
  return out;
}

var TD_SCENES5 = {

  /* ---------- กลุ่มกลางคืนและทัศนวิสัย ---------- */

  /* คำถาม  ขับรถตอนพลบค่ำ ยังพอมองเห็นทางอยู่บ้าง รถคันอื่นเริ่มทยอยเปิดไฟหน้ากันแล้ว

     ต้องเห็นรถคันอื่นเปิดไฟหน้าจริง ๆ หลายคันต่อเนื่อง ไม่ใช่คันเดียวแล้วหาย
     เพราะประโยคนั้นคือตัวโจทย์ทั้งประโยค
     รถของเราเป็นคันเดียวที่ยังไม่เปิดไฟ ซึ่งคือสิ่งที่คำถามกำลังถาม
     ไม่ได้เป็นการเฉลย เพราะโจทย์บอกอยู่แล้วว่าเรายังไม่ได้เปิด */
  dusk: function (p) {
    var cy = 126, hh = 48, eb = cy - 24, wb = cy + 24;
    return tdRoadH(p, cy, hh) + tdDashH(p, cy, -4, 404) +
      tdLaneArrow(44, eb, 'e', p.line) + tdLaneArrow(356, wb, 'w', p.line) +
      tdTree(34, 36, 13) + tdTree(300, 232, 12) + tdTree(210, 30, 11) +
      /* สายรถสวนมาต่อเนื่องสามคัน ทุกคันเปิดไฟหน้าแล้ว */
      tdStream('tdpOnc', 'M448 ' + wb + ' L-48 ' + wb, '#c2492f', 6.6, 3, true) +
      /* สายรถที่วิ่งไปทางเดียวกับเราและอยู่ข้างหน้า ก็เปิดไฟท้ายไว้แล้ว */
      tdStream('tdpAhead', 'M240 ' + eb + ' L448 ' + eb, '#8a94a3', 5.2, 2, true) +
      /* รถของเรา ยังไม่เปิดไฟดวงใดเลย */
      tdPath('tdpA', 'M40 ' + eb + ' L236 ' + eb, TD_BLUE, 200, 1.2) +
      tdDrive(tdCar(0, 0, 0, TD_BLUE, 1, false) + tdStreak(-22, 3), 'tdpA', .4, TD_LOOP, 0) +
      tdFocus(96, eb, 30);
  },

  /* คำถาม  ฝนตกและฟ้าครึ้มจนมืดลงมาก ทั้งที่ยังไม่ถึงเวลาค่ำ
     ต่างจากข้อพลบค่ำตรงที่นี่มืดเพราะฝน ไม่ใช่เพราะเวลา จึงต้องมีเม็ดฝนและผิวถนนเปียก */
  darkday: function (p) {
    var cy = 126, hh = 48, eb = cy - 24, wb = cy + 24;
    return tdRoadH(p, cy, hh) + tdDashH(p, cy, -4, 404) +
      '<rect x="-4" y="' + (cy - hh) + '" width="408" height="' + (hh * 2) + '" fill="#9fc4e8" opacity=".16"/>' +
      tdLaneArrow(44, eb, 'e', p.line) + tdLaneArrow(356, wb, 'w', p.line) +
      tdTree(34, 36, 13) + tdTree(320, 230, 12) +
      tdStream('tdpOnc', 'M448 ' + wb + ' L-48 ' + wb, '#c2492f', 6.2, 3, true) +
      tdStream('tdpAhead', 'M250 ' + eb + ' L448 ' + eb, '#8a94a3', 5, 2, true) +
      tdPath('tdpA', 'M40 ' + eb + ' L240 ' + eb, TD_BLUE, 204, 1.2) +
      tdDrive(tdCar(0, 0, 0, TD_BLUE, 1, false) + tdStreak(-22, 3), 'tdpA', .4, TD_LOOP, 0) +
      tdFocus(96, eb, 30) +
      tdRainDrops(30, .74, '.6');
  },

  /* คำถาม  ขับกลางคืนบนถนนนอกเมืองที่ไม่มีไฟทาง เปิดไฟสูงอยู่ แล้วเห็นไฟหน้ารถสวนมาแต่ไกล

     ใจความคือลำแสงของเราไปถึงตาเขา ภาพจึงต้องเห็นลำแสงยาวของเราชัด
     และเห็นว่าปลายลำแสงไปตกใส่รถที่สวนมาพอดี
     ไม่มีต้นไม้หรืออาคาร เพราะเป็นถนนนอกเมืองที่ไม่มีไฟทาง */
  highbeam: function (p) {
    var cy = 126, hh = 48, eb = cy - 24, wb = cy + 24;
    return tdRoadH(p, cy, hh) + tdDashH(p, cy, -4, 404) +
      tdLaneArrow(44, eb, 'e', p.line) + tdLaneArrow(356, wb, 'w', p.line) +
      /* ลำแสงไฟสูงของเรา ยาวและกว้างกว่าปกติมาก */
      tdCar(78, eb, 0, TD_BLUE, 1, false) +
      '<g transform="translate(100,' + eb + ')">' + tdBeam(0, 0, 'e', 186, 42, .3) + '</g>' +
      tdStream('tdpOnc', 'M448 ' + wb + ' L-48 ' + wb, '#c2492f', 7.4, 2, true) +
      tdConflict(276, cy) +
      tdTree(26, 232, 12);
  },

  /* คำถาม  ต้องเดินเท้าริมถนนตอนกลางคืนในช่วงที่ไม่มีทางเท้า

     เราไม่ได้อยู่ในรถ แต่เป็นคนเดินเท้า จึงไม่มีรถสีน้ำเงินในฉากนี้
     ต้องเห็นว่าไม่มีทางเท้าจริง คือขอบทางจบแล้วเป็นพื้นดินเลย
     และต้องเห็นรถวิ่งต่อเนื่องทั้งสองทิศ เพราะนั่นคืออันตรายของข้อนี้ */
  walknight: function (p) {
    var cy = 122, hh = 46, eb = cy - 23, wb = cy + 23, sh = cy + hh + 12;
    return tdRoadH(p, cy, hh) + tdDashH(p, cy, -4, 404) +
      tdLaneArrow(44, eb, 'e', p.line) + tdLaneArrow(356, wb, 'w', p.line) +
      /* ไหล่ทางเป็นดิน ไม่มีทางเท้า จึงวาดเป็นแถบสีพื้นไม่ใช่แผ่นปูน */
      '<rect x="-4" y="' + (cy + hh + 7) + '" width="408" height="18" fill="' + tdShade(p.grass, .72) + '"/>' +
      tdStream('tdpOnc', 'M448 ' + wb + ' L-48 ' + wb, '#c2492f', 6, 3, true) +
      tdStream('tdpSame', 'M-48 ' + eb + ' L448 ' + eb, '#8a94a3', 6.8, 2, true) +
      /* เราคือคนเดินเท้า เดินอยู่บนไหล่ทางดิน ชุดสีเข้มจึงกลืนกับความมืด */
      '<g>' + tdPerson(0, 0, '#3f4a5a') +
      '<animateMotion dur="11s" repeatCount="indefinite" rotate="0">' +
      '<mpath href="#tdpWalk"/></animateMotion></g>' +
      '<path id="tdpWalk" d="M330 ' + sh + ' L40 ' + sh + '" fill="none" opacity="0"/>' +
      tdTree(60, 30, 13) + tdTree(300, 28, 12);
  },

  /* คำถาม  ฝนตกหนักจนมีน้ำขังเป็นแนวยาวบนถนน รถคันหน้าลุยผ่านไปได้

     ต้องเห็นแนวน้ำขังยาวจริง ๆ และเห็นละอองน้ำที่รถคันหน้าสาดขึ้นมา
     ไม่ใช่แค่ถนนเปียก เพราะน้ำขังกับถนนเปียกเป็นคนละเรื่องกันโดยสิ้นเชิง */
  flood: function (p) {
    var cy = 126, hh = 48, eb = cy - 24, wb = cy + 24;
    return tdRoadH(p, cy, hh) + tdDashH(p, cy, -4, 404) +
      /* แนวน้ำขัง กินความกว้างเกือบทั้งช่องทางและยาวไปข้างหน้า */
      '<g>' +
      '<rect x="188" y="' + (cy - hh + 3) + '" width="216" height="' + (hh - 6) + '" rx="8" fill="#5f86ad" opacity=".62"/>' +
      '<rect x="200" y="' + (cy - hh + 10) + '" width="150" height="9" rx="4" fill="#c8dff2" opacity=".4"/>' +
      '<rect x="236" y="' + (cy - 18) + '" width="120" height="7" rx="3" fill="#c8dff2" opacity=".3"/>' +
      '</g>' +
      tdLaneArrow(44, eb, 'e', p.line) + tdLaneArrow(356, wb, 'w', p.line) +
      tdTree(32, 34, 13) + tdTree(320, 230, 12) +
      /* รถคันหน้าที่ลุยผ่านไปแล้ว กับละอองน้ำที่สาดขึ้นมา */
      tdCar(300, eb, 0, '#c2492f', 1, false) +
      '<ellipse cx="268" cy="' + eb + '" rx="30" ry="16" fill="#e6f0fa" opacity=".45">' +
      '<animate attributeName="opacity" values=".45;.18;.45" dur="1s" repeatCount="indefinite"/></ellipse>' +
      tdStream('tdpOnc', 'M448 ' + wb + ' L-48 ' + wb, '#8a94a3', 7, 2, false) +
      tdPath('tdpA', 'M44 ' + eb + ' L200 ' + eb, TD_BLUE, 160, 1.2) +
      tdConflict(206, eb) +
      tdDrive(tdCar(0, 0, 0, TD_BLUE, 1, true) + tdStreak(-22, 3), 'tdpA', .46, TD_LOOP, 0) +
      tdRainDrops(34, .68, '.7');
  },

  /* ---------- กลุ่มเส้นจราจรบนผิวถนน ---------- */

  /* คำถาม  ขับมาถึงปากทางที่มีเส้นประขาวหนาขวางถนนอยู่ตรงหน้า ซึ่งคือเส้นให้ทาง
             ทางขวางหน้ามีรถวิ่งอยู่ห่าง ๆ
     เส้นประหนาคือตัวโจทย์ ต้องวาดให้เห็นว่าเป็นเส้นประ ไม่ใช่เส้นทึบ
     เพราะคู่เทียบของข้อนี้คือข้อเส้นทึบซึ่งสั่งคนละอย่าง */
  giveway: function (p) {
    var cy = 118, cx = 232, hh = 46, vh = 32, eb = cy - 23, wb = cy + 23, nb = cx - 16;
    return tdRoadH(p, cy, hh) + tdRoadV(p, cx, vh, cy + hh, 264) + tdCross(p, cx, cy, vh, hh) +
      tdMouth(p, cx, vh, cy + hh, 9) +
      tdDashH(p, cy, -4, 404) + tdDashV(p, cx, cy + hh, 264) +
      tdLaneArrow(52, eb, 'e', p.line) + tdLaneArrow(360, wb, 'w', p.line) +
      tdLaneArrow(nb, 246, 'n', p.line) + tdLaneArrow(cx + 16, 246, 's', p.line) +
      /* เส้นให้ทาง เป็นเส้นประหนาขวางปากทางรองที่เราขับมา */
      tdYieldBar(p, cx - vh + 4, cy + hh + 12, cy + hh + 12 + 52) +
      tdBuilding(80, 46, 110, 50, '#7d8796', '#5c646f') +
      tdTree(348, 40, 12) +
      /* รถในทางขวางหน้า วิ่งต่อเนื่องแต่ยังห่าง */
      tdStream('tdpCross', 'M448 ' + wb + ' L-48 ' + wb, '#c2492f', 7.6, 2, false) +
      tdPath('tdpA', 'M' + nb + ' 250 L' + nb + ' ' + (cy + hh + 22), TD_BLUE, 80, 1.4) +
      tdConflict(nb, cy + hh + 6) +
      tdDrive(tdCar(0, 0, 0, TD_BLUE, 1, true), 'tdpA', .5, TD_LOOP, 0);
  },

  /* คำถาม  ขับมาถึงปากทางที่มีเส้นสีขาวขวางถนนอยู่ตรงหน้า เป็นเส้นทึบหนา ไม่ใช่เส้นประ
     วางองค์ประกอบให้เหมือนข้อเส้นให้ทางทุกอย่าง ต่างกันแค่ชนิดเส้น
     ความเหมือนนี้ตั้งใจ เพราะผู้เล่นต้องแยกสองเส้นนี้ให้ออกจากตัวเส้นเอง ไม่ใช่จากฉากรอบ ๆ */
  stopline: function (p) {
    var cy = 118, cx = 232, hh = 46, vh = 32, eb = cy - 23, wb = cy + 23, nb = cx - 16;
    return tdRoadH(p, cy, hh) + tdRoadV(p, cx, vh, cy + hh, 264) + tdCross(p, cx, cy, vh, hh) +
      tdMouth(p, cx, vh, cy + hh, 9) +
      tdDashH(p, cy, -4, 404) + tdDashV(p, cx, cy + hh, 264) +
      tdLaneArrow(52, eb, 'e', p.line) + tdLaneArrow(360, wb, 'w', p.line) +
      tdLaneArrow(nb, 246, 'n', p.line) + tdLaneArrow(cx + 16, 246, 's', p.line) +
      /* เส้นแนวหยุด เป็นเส้นทึบหนาขวางเต็มปากทาง */
      '<rect x="' + (cx - vh + 4) + '" y="' + (cy + hh + 12) + '" width="' + (vh * 2 - 8) + '" height="7" ' +
      'fill="' + p.line + '" opacity=".95"/>' +
      tdBuilding(80, 46, 110, 50, '#7d8796', '#5c646f') +
      tdTree(348, 40, 12) +
      tdStream('tdpCross', 'M448 ' + wb + ' L-48 ' + wb, '#c2492f', 7.6, 2, false) +
      tdPath('tdpA', 'M' + nb + ' 250 L' + nb + ' ' + (cy + hh + 26), TD_BLUE, 76, 1.4) +
      tdConflict(nb, cy + hh + 10) +
      tdDrive(tdCar(0, 0, 0, TD_BLUE, 1, true), 'tdpA', .5, TD_LOOP, 0);
  },

  /* คำถาม  ขับตามรถบรรทุกที่วิ่งช้ามานาน เส้นแบ่งช่องเดินรถตรงนั้นเป็นเส้นทึบสีขาว ข้างหน้ายังโล่ง
     เส้นทึบคือตัวโจทย์ ต้องวาดให้ยาวต่อเนื่องไม่ขาดช่วง จะได้ไม่สับสนกับเส้นประ
     ข้างหน้าโล่งจริง เพื่อให้ผู้เล่นรู้สึกถึงแรงจูงใจที่จะแซง */
  solidline: function (p) {
    var cy = 126, hh = 54, l1 = cy - 39, l2 = cy - 13, w1 = cy + 13, w2 = cy + 39;
    return tdRoadH(p, cy, hh) +
      tdSolidH(p, cy, -4, 404, 3) +
      /* เส้นแบ่งช่องเดินรถของฝั่งเรา เป็นเส้นทึบยาวไม่ขาดช่วง */
      tdSolidH(p, cy - 26, -4, 404, 3) +
      tdDashH(p, cy + 26, -4, 404) +
      tdLaneArrow(40, l1, 'e', p.line) + tdLaneArrow(40, l2, 'e', p.line) +
      tdLaneArrow(364, w1, 'w', p.line) + tdLaneArrow(364, w2, 'w', p.line) +
      tdTree(30, 30, 12) + tdTree(340, 234, 12) +
      tdTruck(250, l1, 0, 1, false) +
      tdPath('tdpA', 'M60 ' + l1 + ' L196 ' + l1, TD_BLUE, 140, 1.2) +
      tdConflict(212, l1) +
      tdDrive(tdCar(0, 0, 0, TD_BLUE, 1, true) + tdStreak(-22, 3), 'tdpA', .5, TD_LOOP, 0) +
      tdStream('tdpOnc', 'M448 ' + w2 + ' L-48 ' + w2, '#c2492f', 8.4, 1, false);
  },

  /* คำถาม  ถนนมีเส้นแบ่งทิศทางเป็นเส้นคู่ ฝั่งที่ติดกับเลนของเราเป็นเส้นทึบ อีกฝั่งเป็นเส้นประ
     ต้องเห็นชัดว่าเส้นไหนอยู่ฝั่งไหน เพราะทั้งข้อขึ้นอยู่กับเรื่องนี้เรื่องเดียว
     เลนเราอยู่ครึ่งบน เส้นทึบจึงต้องอยู่เหนือเส้นประ */
  doubleline: function (p) {
    var cy = 128, hh = 48, eb = cy - 24, wb = cy + 24;
    return tdRoadH(p, cy, hh) +
      /* เส้นคู่กลางถนน  ทึบอยู่ฝั่งบนซึ่งเป็นฝั่งของเรา ประอยู่ฝั่งล่าง */
      tdSolidH(p, cy - 4, -4, 404, 3) +
      tdDashH(p, cy + 4, -4, 404) +
      tdLaneArrow(44, eb, 'e', p.line) + tdLaneArrow(356, wb, 'w', p.line) +
      tdTree(30, 32, 13) + tdTree(330, 232, 12) +
      tdCar(232, eb, 0, '#8a94a3', 1, true) +
      tdPath('tdpA', 'M44 ' + eb + ' L176 ' + eb, TD_BLUE, 136, 1.2) +
      tdConflict(196, eb) +
      tdDrive(tdCar(0, 0, 0, TD_BLUE, 1, true) + tdStreak(-22, 3), 'tdpA', .5, TD_LOOP, 0) +
      tdStream('tdpOnc', 'M448 ' + wb + ' L-48 ' + wb, '#c2492f', 7.2, 2, false);
  },

  /* คำถาม  ถนนในเมืองมีช่องทางหนึ่งตีเส้นทึบสีเหลืองหนากั้นไว้ ช่องนั้นโล่งกว่าช่องอื่นมาก
     ช่องเดินรถประจำทางต้องโล่งจริงให้เห็น ส่วนช่องอื่นต้องมีรถต่อคิว
     ความต่างของสองช่องคือแรงจูงใจทั้งหมดของคำถามข้อนี้ */
  buslane: function (p) {
    var cy = 130, hh = 58, l1 = cy - 43, l2 = cy - 15, out = '', i;
    for (i = 0; i < 5; i++) { out += tdCar(70 + i * 62, l2, 0, i === 1 ? '#8a94a3' : '#c2492f', 1, true); }
    return tdRoadH(p, cy, hh) +
      tdSolidH(p, cy, -4, 404, 3) +
      /* เส้นทึบสีเหลืองหนา กั้นช่องเดินรถประจำทางไว้ */
      '<rect x="-4" y="' + (cy - 29) + '" width="408" height="6" fill="#f0c419" opacity=".95"/>' +
      tdDashH(p, cy + 29, -4, 404) +
      tdLaneArrow(36, l1, 'e', p.line) + tdLaneArrow(36, l2, 'e', p.line) +
      tdLaneArrow(368, cy + 15, 'w', p.line) + tdLaneArrow(368, cy + 43, 'w', p.line) +
      tdBuilding(120, 30, 150, 44, '#7d8796', '#5c646f') +
      /* ช่องเดินรถประจำทาง โล่งจริง มีรถโดยสารวิ่งอยู่คันเดียว */
      tdStream('tdpBus', 'M-70 ' + l1 + ' L470 ' + l1, '#3f6f9e', 7.8, 1, false) +
      out +
      tdFocus(132, l2, 30) +
      tdPath('tdpA', 'M150 ' + l2 + ' Q196 ' + l2 + ' 202 ' + l1 + ' L300 ' + l1, TD_BLUE, 170, 1.6) +
      tdConflict(206, l1);
  },

  /* คำถาม  อยู่ในช่องที่พื้นถนนตีลูกศรชี้ตรงไปข้างหน้าไว้ แต่เพิ่งนึกได้ว่าต้องเลี้ยวซ้ายที่แยกข้างหน้า
     ลูกศรบนผิวถนนคือตัวโจทย์ ต้องเห็นทั้งช่องของเราที่เป็นลูกศรตรง
     และช่องข้างเคียงที่เป็นลูกศรเลี้ยวซ้าย จะได้รู้ว่าเราอยู่ผิดช่อง */
  lanearrow: function (p) {
    var cy = 130, cx = 268, hh = 56, vh = 32, l1 = cy - 41, l2 = cy - 14, stop = cx - vh - 12;
    /* ลูกศรบนผิวถนน ใช้ตัวช่วยกลางจาก scene-top.js
       ห้ามวาดเองด้วยมือ เคยวาดแล้วหันผิดไปเก้าสิบองศาทั้งสองอัน
       ลูกศรตรงชี้ขึ้นแทนที่จะชี้ไปทางขวา และลูกศรเลี้ยวซ้ายกลายเป็นเบนไปทางขวา
       ซึ่งทำให้คำถามข้อนี้บอกข้อมูลผิดทั้งข้อ เพราะทั้งข้อขึ้นอยู่กับลูกศรสองอันนี้ */
    return tdRoadH(p, cy, hh) + tdRoadV(p, cx, vh, -4, cy - hh) + tdCross(p, cx, cy, vh, hh) +
      tdMouth(p, cx, vh, cy - hh - 7, 9) +
      tdSolidH(p, cy, -4, cx - vh, 3) + tdSolidH(p, cy, cx + vh, 404, 3) +
      tdDashH(p, cy - 27, -4, stop) + tdDashH(p, cy + 27, -4, 404) +
      tdDashV(p, cx, -4, cy - hh) +
      tdLaneArrow(cx - 16, 40, 'n', p.line) + tdLaneArrow(cx + 16, 40, 's', p.line) +
      tdLaneArrow(368, cy + 14, 'w', p.line) + tdLaneArrow(368, cy + 41, 'w', p.line) +
      '<rect x="' + stop + '" y="' + (cy - hh) + '" width="5" height="' + hh + '" fill="' + p.line + '" opacity=".92"/>' +
      /* ช่องซ้ายสุดทาลูกศรเลี้ยวซ้าย ช่องที่เราอยู่ทาลูกศรตรง */
      /* ช่องซ้ายสุดทาลูกศรเลี้ยวซ้าย ช่องที่เราอยู่ทาลูกศรตรง */
      tdRoadArrow(150, l1, 'left', p.line) + tdRoadArrow(150, l2, 'straight', p.line) +
      tdBuilding(90, 40, 120, 46, '#9a7350', '#6c4e34') +
      tdCar(96, l1, 0, '#8a94a3', 1, true) +
      tdPath('tdpA', 'M40 ' + l2 + ' L' + (stop - 10) + ' ' + l2, TD_BLUE, 200, 1.2) +
      tdConflict(stop - 6, l2) +
      tdDrive(tdCar(0, 0, 0, TD_BLUE, 1, true) + tdStreak(-22, 3), 'tdpA', .5, TD_LOOP, 0);
  }
};

(function () {
  var target = (typeof TD_SCENES !== 'undefined') ? TD_SCENES
             : (typeof window !== 'undefined' ? window.TD_SCENES : null);
  if (!target) { throw new Error('ต้องโหลด assets/scene-top.js ก่อน assets/scene-top5.js'); }
  Object.keys(TD_SCENES5).forEach(function (k) {
    if (target[k]) { throw new Error('ชื่อฉากซ้ำกับของเดิม: ' + k); }
    target[k] = TD_SCENES5[k];
  });
})();
