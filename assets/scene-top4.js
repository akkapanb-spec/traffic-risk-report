'use strict';
/* ============================================================
   ฉากชุดที่สี่  คำถามเรื่องการหยุดรถและการจอดรถทั้งกลุ่ม
   ============================================================
   ต่อจาก scene-top.js, scene-top2.js และ scene-top3.js ต้องโหลดตามลำดับ

   ทำไมรวมไว้ไฟล์เดียว
     คำถามกลุ่มนี้สิบห้าข้อใช้ฉากฐานเดียวกันหมด คือถนนตรงกับขอบทางด้านซ้ายของเรา
     ต่างกันแค่ของที่อยู่ริมทางตรงนั้น ท่อดับเพลิง ป้ายรถเมล์ ปากทางเข้าอาคาร ทางม้าลาย
     เขียนฐานร่วมไว้ตัวเดียวแล้วสลับของริมทาง จึงสั้นกว่าและแก้ทีเดียวได้ทั้งกลุ่ม

   ============================================================
   กฎที่ใช้กับทุกฉากในไฟล์นี้
   ============================================================
   หนึ่ง  ประเทศไทยขับชิดซ้าย  เราวิ่งไปทางขวาของภาพเสมอ จึงอยู่ครึ่งบนของถนน
          ขอบทางด้านซ้ายของเราคือขอบบนของภาพ รถจึงเทียบขอบบนเสมอ ไม่ใช่ขอบล่าง
          ข้อเดียวที่ต่างคือข้อจอดฝั่งตรงข้าม ซึ่งจงใจวาดให้ผิดเพราะนั่นคือตัวคำถาม

   สอง   ภาพห้ามเฉลยคำตอบ
          ห้ามวาดป้ายห้ามจอด ห้ามวาดเส้นขาวแดงในข้อที่ไม่ได้พูดถึงมัน
          และห้ามวาดเส้นบอกระยะเป็นเมตร เพราะคำตอบเกือบทุกข้อคือตัวเลขระยะ
          ถ้าวาดไม้บรรทัดลงไป ผู้เล่นก็อ่านคำตอบจากภาพโดยไม่ต้องรู้กติกา

   สาม   ช่องว่างที่กำลังพิจารณา วาดเป็นกรอบเส้นประกับวงแหวนสีเหลือง
          สีเหลืองเป็นสีกลางที่ใช้ทั้งไฟล์ ไม่ใช่สีแดงที่อ่านเป็นคำเตือนว่าห้าม
   ============================================================ */

/* ฐานร่วมของทุกฉากในไฟล์นี้  ถนนสองทิศ ขอบทางบนคือฝั่งที่เราจอด */
var TD_PARK = { cy: 142, hh: 46 };
function tdParkBase(p) {
  var cy = TD_PARK.cy, hh = TD_PARK.hh;
  return tdRoadH(p, cy, hh) + tdDashH(p, cy, -4, 404) +
    tdLaneArrow(40, cy - 23, 'e', p.line) + tdLaneArrow(200, cy - 23, 'e', p.line) +
    tdLaneArrow(40, cy + 23, 'w', p.line) + tdLaneArrow(200, cy + 23, 'w', p.line);
}
/* เส้น y ที่ใช้บ่อย  ky คือแนวขอบทาง  py คือแนวกลางตัวรถที่จอดเทียบขอบ */
function tdKy() { return TD_PARK.cy - TD_PARK.hh - 7; }
function tdPy() { return TD_PARK.cy - TD_PARK.hh + 13; }

/* ช่องว่างที่กำลังพิจารณาจะจอด  กรอบเส้นประ ไม่ใช่ของจริงบนถนน
   รับแกนตั้งเข้ามาด้วย ไม่ไปหยิบจากตัวแปรร่วมเอง
   เพราะบางฉากช่องจอดไม่ได้อยู่แนวขอบทาง เช่นข้อจอดซ้อนคันกับข้อจอดฝั่งตรงข้าม */
function tdBay(x, w, y) {
  y = (y == null) ? tdPy() : y;
  return '<rect x="' + (x - w / 2) + '" y="' + (y - 14) + '" width="' + w + '" height="28" rx="5" ' +
    'fill="rgba(255,209,102,.14)" stroke="#ffd166" stroke-width="2.2" stroke-dasharray="8 6"/>';
}

/* กรอบช่องจอดกับวงแหวนจุดตัดสินใจ ออกมาจากการเรียกครั้งเดียว
   เดิมเรียกแยกกันสองตัว แล้วมีฉากหนึ่งส่งแกนตั้งไม่ตรงกัน
   ผลคือกรอบว่างลอยอยู่ที่หนึ่ง รถไปจอดอีกที่หนึ่ง โดยไม่มีอะไรเตือน
   รวมไว้ตัวเดียวจึงเพี้ยนแบบนั้นไม่ได้อีก */
function tdBaySpot(x, w, y) {
  y = (y == null) ? tdPy() : y;
  return tdBay(x, w, y) + tdConflict(x, y);
}

/* ============================================================
   สีที่ทาขอบทาง  เป็นคำสั่ง ไม่ใช่การตกแต่ง
   ============================================================
     ขาวดำ     จอดได้
     ขาวเหลือง ห้ามจอด แต่หยุดรับส่งคนหรือของชั่วขณะได้
     ขาวแดง    ห้ามทั้งหยุดและจอด

   วิธีใช้ในไฟล์นี้  ทาขาวดำตลอดแนวก่อน แล้วทับด้วยสีของเขตห้ามเฉพาะช่วงนั้น
   ได้ภาพตรงกับถนนจริง คือขอบทางส่วนใหญ่จอดได้ มีบางช่วงที่ห้าม
   ถ้าทาสีห้ามยาวตลอดแนว จะค้านกับรถที่จอดอยู่ในภาพเอง

   ช่วงละยี่สิบหกหน่วย เทียบสัดส่วนกับของจริงที่ทาช่วงละห้าสิบเซนติเมตร */
function tdKerbPaint(x1, x2, cB, y) {
  y = (y == null) ? tdKy() : y;
  var out = '', i, k = Math.floor((x2 - x1) / 26);
  for (i = 0; i < k; i++) {
    out += '<rect x="' + (x1 + i * 26) + '" y="' + y + '" width="26" height="7" fill="' +
      (i % 2 ? cB : '#f2f5f8') + '"/>';
  }
  return out;
}
function tdKerbOk(x1, x2, y)     { return tdKerbPaint(x1, x2, '#2b3138', y); }   // ขาวดำ จอดได้
function tdKerbNoPark(x1, x2, y) { return tdKerbPaint(x1, x2, '#f0c419', y); }   // ขาวเหลือง ห้ามจอด
function tdKerbNoStop(x1, x2, y) { return tdKerbPaint(x1, x2, '#d0342c', y); }   // ขาวแดง ห้ามหยุดห้ามจอด

/* หัวจ่ายน้ำดับเพลิง  มองจากบนเห็นตัวกลมกับข้อต่อสองข้าง */
function tdHydrant(x, y) {
  return '<g transform="translate(' + x + ',' + y + ')">' +
    '<ellipse cx="3" cy="5" rx="11" ry="5" fill="rgba(0,0,0,.34)"/>' +
    '<rect x="-13" y="-3.6" width="26" height="7.2" rx="3.6" fill="#9b2820"/>' +
    '<circle r="8.4" fill="#d0342c"/><circle r="5" fill="#e8564d"/>' +
    '<circle r="2.2" fill="#f7b3ae"/></g>';
}

/* ป้ายหยุดรถประจำทาง  เสากับแผ่นป้าย มองจากบนเห็นเป็นแท่งกับแผ่น */
function tdBusSign(x, y) {
  return '<g transform="translate(' + x + ',' + y + ')">' +
    '<ellipse cx="4" cy="6" rx="16" ry="6" fill="rgba(0,0,0,.32)"/>' +
    '<rect x="-3" y="-4" width="6" height="8" rx="3" fill="#4a5568"/>' +
    '<rect x="-16" y="-13" width="32" height="11" rx="3" fill="#1d4ed8"/>' +
    '<rect x="-12" y="-10.5" width="18" height="6" rx="2" fill="#dfe7f0"/>' +
    '<circle cx="9" cy="-7.5" r="2" fill="#dfe7f0"/></g>';
}

/* ปากทางเข้าออกอาคาร  ช่องเปิดที่ขอบทาง พร้อมอาคารด้านหลัง */
function tdGateMouth(p, x, w) {
  var ky = tdKy();
  return tdBuilding(x, ky - 52, w + 40, 58, '#7d8796', '#5c646f') +
    '<rect x="' + (x - w / 2) + '" y="' + ky + '" width="' + w + '" height="9" fill="' + p.road + '"/>' +
    '<rect x="' + (x - w / 2) + '" y="' + (ky - 22) + '" width="' + w + '" height="24" fill="' + p.road + '"/>';
}

var TD_SCENES4 = {

  /* คำถาม  ที่ว่างพอดีคันหนึ่งอยู่ข้างหัวจ่ายน้ำดับเพลิงริมทาง
     หัวจ่ายคือตัวโจทย์ จึงต้องเห็นชัด แต่ห้ามวาดเส้นบอกระยะสามเมตร เพราะนั่นคือคำตอบ */
  parkhydrant: function (p) {
    var ky = tdKy(), py = tdPy();
    return tdParkBase(p) +
      tdKerbOk(36, 366) + tdKerbNoStop(166, 270) +
      tdBuilding(96, ky - 46, 120, 52, '#9a7350', '#6c4e34') +
      tdBuilding(300, ky - 44, 104, 48, '#7d8796', '#5c646f') +
      tdHydrant(214, ky - 13) +
      tdCar(120, py, 0, '#8a94a3', 1, false) + tdCar(308, py, 0, '#8a94a3', 1, false) +
      tdBaySpot(214, 68) +
      tdPath('tdpA', 'M60 ' + (TD_PARK.cy - 23) + ' L150 ' + (TD_PARK.cy - 23) + ' Q192 ' + (TD_PARK.cy - 23) + ' 196 ' + py + ' L212 ' + py,
        TD_BLUE, 180, 1.4) +
      tdDrive(tdCar(0, 0, 0, TD_BLUE, 1, true) + tdStreak(-22, 3), 'tdpA', .34, TD_LOOP, 0);
  },

  /* คำถาม  จะแวะซื้อของ มีที่ว่างพอดีอยู่ห่างจากปากทางแยกราวห้าเมตร
     ปากทางแยกคือตัวโจทย์ จึงวาดซอยแยกออกไปจากขอบทาง */
  parkjunction: function (p) {
    var ky = tdKy(), py = tdPy(), cy = TD_PARK.cy, hh = TD_PARK.hh, sx = 128, vh = 26;
    return tdRoadV(p, sx, vh, -4, cy - hh) + tdParkBase(p) +
      /* ขอบทางส่วนใหญ่จอดได้ แต่ช่วงที่ต่อจากปากซอยเป็นเขตห้ามหยุดห้ามจอด
         ทาก่อนที่ช่องเปิดปากซอยจะถูกวาดทับ สีจึงไม่ไปโผล่ตรงที่ไม่มีขอบทาง */
      tdKerbOk(36, 366) + tdKerbNoStop(154, 258) +
      '<rect x="' + (sx - vh) + '" y="' + ky + '" width="' + (vh * 2) + '" height="9" fill="' + p.road + '"/>' +
      tdDashV(p, sx, -4, cy - hh) +
      tdLaneArrow(sx - 13, 40, 'n', p.line) + tdLaneArrow(sx + 13, 40, 's', p.line) +
      tdBuilding(260, ky - 46, 128, 52, '#b4784a', '#7d5232') +
      tdCar(272, py, 0, '#8a94a3', 1, false) +
      tdBaySpot(190, 68) +
      tdPath('tdpA', 'M52 ' + (cy - 23) + ' L126 ' + (cy - 23) + ' Q168 ' + (cy - 23) + ' 172 ' + py + ' L188 ' + py,
        TD_BLUE, 170, 1.4) +
      tdDrive(tdCar(0, 0, 0, TD_BLUE, 1, true) + tdStreak(-22, 3), 'tdpA', .34, TD_LOOP, 0);
  },

  /* คำถาม  เพื่อนยืนโบกเรียกให้จอดรับ ตรงที่เขายืนอยู่คือปากทางแยกพอดี
     ต่างจากข้อบนตรงที่นี่คือการหยุดรับคน ไม่ใช่การจอด และมีคนยืนอยู่จริง */
  stopjunction: function (p) {
    var ky = tdKy(), py = tdPy(), cy = TD_PARK.cy, hh = TD_PARK.hh, sx = 214, vh = 26;
    return tdRoadV(p, sx, vh, -4, cy - hh) + tdParkBase(p) +
      /* ปากทางแยกเป็นเขตห้ามหยุด ทาขาวแดงคร่อมทั้งสองฝั่งของปากทาง */
      tdKerbOk(36, 366) + tdKerbNoStop(136, 292) +
      '<rect x="' + (sx - vh) + '" y="' + ky + '" width="' + (vh * 2) + '" height="9" fill="' + p.road + '"/>' +
      tdDashV(p, sx, -4, cy - hh) +
      tdLaneArrow(sx - 13, 40, 'n', p.line) + tdLaneArrow(sx + 13, 40, 's', p.line) +
      tdBuilding(92, ky - 46, 110, 52, '#9a7350', '#6c4e34') +
      tdBuilding(330, ky - 44, 96, 48, '#7d8796', '#5c646f') +
      /* เพื่อนยืนโบกอยู่ที่ปากทางแยกพอดี แขนโบกจึงต้องขยับ */
      '<g transform="translate(' + (sx + 2) + ',' + (ky - 12) + ')">' + tdPerson(0, 0, '#c9843f') +
      '<path d="M6 -3 L17 -12" stroke="#c9843f" stroke-width="3.4" stroke-linecap="round">' +
      '<animateTransform attributeName="transform" type="rotate" values="-16 6 -3;10 6 -3;-16 6 -3" ' +
      'dur="1.1s" repeatCount="indefinite"/></path></g>' +
      tdBaySpot(sx, 64) +
      tdPath('tdpA', 'M60 ' + (cy - 23) + ' L160 ' + (cy - 23) + ' Q198 ' + (cy - 23) + ' 200 ' + py + ' L' + (sx - 4) + ' ' + py,
        TD_BLUE, 190, 1.4) +
      tdDrive(tdCar(0, 0, 0, TD_BLUE, 1, true) + tdStreak(-22, 3), 'tdpA', .36, TD_LOOP, 0);
  },

  /* คำถาม  เห็นที่ว่างพอดีคันหนึ่ง อยู่ห่างจากทางม้าลายราวสองเมตร
     ทางม้าลายคือตัวโจทย์ ใช้ตัวช่วยวาดแถบม้าลายที่มีอยู่แล้ว */
  parkzebra: function (p) {
    var ky = tdKy(), py = tdPy(), cy = TD_PARK.cy, hh = TD_PARK.hh, zx = 262;
    return tdParkBase(p) +
      tdKerbOk(36, 366) + tdKerbNoStop(170, 296) +
      tdZebra(p, zx, cy - hh, cy + hh, 7) +
      tdBuilding(110, ky - 46, 132, 52, '#b4784a', '#7d5232') +
      tdBuilding(330, ky - 44, 96, 48, '#7d8796', '#5c646f') +
      tdCar(108, py, 0, '#8a94a3', 1, false) +
      tdBaySpot(206, 70) +
      tdPath('tdpA', 'M46 ' + (cy - 23) + ' L146 ' + (cy - 23) + ' Q188 ' + (cy - 23) + ' 192 ' + py + ' L204 ' + py,
        TD_BLUE, 190, 1.4) +
      tdDrive(tdCar(0, 0, 0, TD_BLUE, 1, true) + tdStreak(-22, 3), 'tdpA', .34, TD_LOOP, 0);
  },

  /* คำถาม  ร้านที่จะแวะไม่มีที่จอด คนอื่นจอดซ้อนคันกันอยู่แล้วหลายคัน
     ต้องเห็นรถซ้อนคันจริง คือรถจอดชั้นในติดขอบทาง แล้วมีอีกแถวจอดซ้อนออกมาในช่องทาง */
  parkdouble: function (p) {
    /* คำถาม  ร้านที่จะแวะไม่มีที่จอด คนอื่นจอดซ้อนคันกันอยู่แล้วหลายคัน เราจะเข้าไปแค่ห้านาที

       ฉากนี้ใช้ถนนของตัวเองที่กว้างกว่าฐานร่วม เพราะต้องมีของสามอย่างเรียงกันในครึ่งบน
       แถวรถที่จอดชิดขอบทาง ตัวเราที่กำลังจะจอดซ้อน และช่องที่เหลือให้รถวิ่งผ่าน

       คนที่จอดซ้อนในภาพคือรถของเราคันเดียว ไม่ได้วาดรถคันอื่นจอดซ้อนไว้ก่อน
       เพราะถ้าวาดไว้ ภาพจะเล่าว่าเรื่องนี้จบไปแล้ว อ่านไม่ออกว่าเรากำลังจะตัดสินใจอะไร
       รถสีแดงจึงเป็นรถที่วิ่งผ่านในช่องทาง มีไว้ให้เห็นว่าการจอดซ้อนไปขวางใคร

       ขอบทางทาขาวดำ เพราะขอบทางตรงนั้นจอดได้จริง ปัญหาคือเต็มไปแล้วต่างหาก */
    var cy = 140, hh = 64, ky = cy - hh - 7;
    var kerbRow = cy - hh + 14, dblRow = kerbRow + 25, lane = cy - 6;
    return tdRoadH(p, cy, hh) + tdDashH(p, cy, -4, 404) +
      tdKerbOk(70, 356, ky) +
      tdLaneArrow(40, lane, 'e', p.line) + tdLaneArrow(40, cy + 32, 'w', p.line) +
      tdLaneArrow(370, cy + 32, 'w', p.line) +
      tdBuilding(186, ky - 34, 220, 52, '#b4784a', '#7d5232') +
      '<rect x="88" y="' + (ky - 14) + '" width="196" height="10" rx="4" fill="#c0562f"/>' +
      /* แถวที่จอดชิดขอบทาง เต็มทุกช่องตามที่โจทย์บอกว่าไม่มีที่จอด */
      tdCar(108, kerbRow, 0, '#8a94a3', 1, false) + tdCar(174, kerbRow, 0, '#8a94a3', 1, false) +
      tdCar(240, kerbRow, 0, '#8a94a3', 1, false) + tdCar(306, kerbRow, 0, '#8a94a3', 1, false) +
      /* ที่ที่เรากำลังจะไปจอด คือซ้อนออกมาเทียบรถที่จอดอยู่แล้ว */
      tdBaySpot(240, 68, dblRow) +
      /* รถที่วิ่งผ่านในช่องทาง สองคันเหลื่อมเวลากัน ไม่ใช่รถที่จอดอยู่ */
      '<path id="tdpFlow" d="M-44 ' + lane + ' L444 ' + lane + '" fill="none" opacity="0"/>' +
      tdMove(tdCar(0, 0, 0, '#c2492f', 1, false), 'tdpFlow', 4.4, 0) +
      tdMove(tdCar(0, 0, 0, '#c2492f', 1, false), 'tdpFlow', 4.4, 2.2) +
      tdPath('tdpA', 'M40 ' + lane + ' L188 ' + lane + ' Q226 ' + lane + ' 230 ' + dblRow + ' L236 ' + dblRow,
        TD_BLUE, 220, 1.4) +
      tdDrive(tdCar(0, 0, 0, TD_BLUE, 1, true) + tdStreak(-22, 3), 'tdpA', .46, TD_LOOP, 0);
  },

  /* คำถาม  จอดรถชิดขอบทางเรียบร้อยแล้ว กำลังจะเปิดประตูฝั่งคนขับลงจากรถ
     รถพวงมาลัยขวา ประตูคนขับจึงอยู่ฝั่งขวาของรถ ซึ่งคือด้านล่างของภาพเมื่อรถหันหน้าไปทางขวา
     เป็นฝั่งที่หันออกสู่ช่องทางเดินรถพอดี จึงเป็นฝั่งที่มีรถวิ่งผ่าน */
  dooropen: function (p) {
    var ky = tdKy(), py = tdPy(), cy = TD_PARK.cy;
    return tdParkBase(p) +
      tdKerbOk(36, 366) +
      tdBuilding(120, ky - 46, 140, 52, '#9a7350', '#6c4e34') +
      tdBuilding(310, ky - 44, 108, 48, '#7d8796', '#5c646f') +
      tdCar(120, py, 0, '#8a94a3', 1, false) + tdCar(286, py, 0, '#8a94a3', 1, false) +
      tdCar(202, py, 0, TD_BLUE, 1, false) +
      /* บานประตูที่กำลังเปิดออกไปทางช่องทางเดินรถ */
      '<g transform="translate(200,' + (py + 9) + ')">' +
      '<rect x="-15" y="0" width="30" height="5" rx="2.5" fill="' + tdShade(TD_BLUE, .8) + '">' +
      '<animateTransform attributeName="transform" type="rotate" values="0 -15 0;62 -15 0;62 -15 0;0 -15 0" ' +
      'keyTimes="0;0.3;0.75;1" dur="3.4s" repeatCount="indefinite"/></rect></g>' +
      /* จักรยานยนต์ที่วิ่งชิดซ้ายมาในช่องเดียวกับที่ประตูจะเปิดออกไป */
      tdPath('tdpM', 'M-30 ' + (py + 30) + ' L430 ' + (py + 30), TD_RED, 460, 0) +
      tdMove(tdMoto(0, 0, 0, 1, TD_RED), 'tdpM', 3.6, 0) +
      tdConflict(214, py + 26);
  },

  /* คำถาม  จะจอดแวะซื้อของ ตรงขอบทางที่ว่างอยู่ทาสีขาวสลับแดงไว้ตลอดแนว
     สีที่ทาขอบทางคือตัวโจทย์ ต้องเห็นชัดและสลับสีให้ถูก
     ไม่ได้เป็นการเฉลย เพราะคำถามถามว่าสีนี้ห้ามอะไรบ้าง ซึ่งต้องรู้กติกาถึงจะตอบได้ */
  kerbred: function (p) {
    var ky = tdKy(), py = tdPy(), cy = TD_PARK.cy;
    /* สีขาวแดงคือตัวโจทย์ของข้อนี้ จึงทายาวตลอดแนวจริง ๆ ไม่ได้ทาขาวดำรองไว้
       ใช้ตัวช่วยร่วมตัวเดียวกับฉากอื่น จะได้ขนาดช่วงสีเท่ากันทั้งไฟล์ */
    return tdParkBase(p) + tdKerbNoStop(36, 366) +
      tdBuilding(122, ky - 46, 140, 52, '#b4784a', '#7d5232') +
      tdBuilding(312, ky - 44, 104, 48, '#7d8796', '#5c646f') +
      tdBaySpot(232, 70) +
      tdPath('tdpA', 'M50 ' + (cy - 23) + ' L166 ' + (cy - 23) + ' Q212 ' + (cy - 23) + ' 216 ' + py + ' L230 ' + py,
        TD_BLUE, 200, 1.4) +
      tdDrive(tdCar(0, 0, 0, TD_BLUE, 1, true) + tdStreak(-22, 3), 'tdpA', .36, TD_LOOP, 0);
  },

  /* คำถาม  เห็นที่จอดว่างพอดีอยู่ข้างหน้า จะชะลอแล้วเข้าจอด มีรถตามหลังมาอยู่
     ใจความคือรถที่ตามหลัง ต้องเห็นว่ามีคนตามมาจริงและอยู่ใกล้พอที่จะเป็นปัญหา
     ห้ามวาดเส้นบอกระยะสามสิบเมตร เพราะระยะนั้นคือคำตอบ */
  signalstop: function (p) {
    var ky = tdKy(), py = tdPy(), cy = TD_PARK.cy;
    return tdParkBase(p) +
      tdKerbOk(36, 366) +
      tdBuilding(130, ky - 46, 150, 52, '#9a7350', '#6c4e34') +
      tdBuilding(320, ky - 44, 100, 48, '#7d8796', '#5c646f') +
      tdCar(300, py, 0, '#8a94a3', 1, false) +
      tdBay(216, 70) +
      /* รถที่ตามหลังมา วิ่งในช่องเดียวกับเรา */
      tdPath('tdpB', 'M-30 ' + (cy - 23) + ' L150 ' + (cy - 23), TD_RED, 180, .2) +
      tdMove(tdCar(0, 0, 0, '#c2492f', 1, false), 'tdpB', 3.2, 0) +
      tdPath('tdpA', 'M110 ' + (cy - 23) + ' L172 ' + (cy - 23) + ' Q202 ' + (cy - 23) + ' 206 ' + py + ' L214 ' + py,
        TD_BLUE, 150, 1.5) +
      tdConflict(180, cy - 23) +
      tdDrive(tdCar(0, 0, 0, TD_BLUE, 1, true) + tdStreak(-22, 3), 'tdpA', .4, TD_LOOP, 0);
  },

  /* คำถาม  จอดรถเสร็จแล้ว ตัวรถห่างจากขอบฟุตบาทราวครึ่งเมตร เพราะมีร่องน้ำอยู่
     ต้องเห็นช่องว่างระหว่างรถกับขอบทางจริง ๆ และเห็นว่ามันไปเบียดใคร
     คนที่ถูกเบียดคือจักรยานยนต์ที่วิ่งชิดซ้าย จึงต้องมีคันหนึ่งวิ่งอยู่ */
  parkgap: function (p) {
    var ky = tdKy(), py = tdPy() + 11, cy = TD_PARK.cy;
    return tdParkBase(p) +
      tdKerbOk(36, 366) +
      tdBuilding(120, ky - 46, 140, 52, '#9a7350', '#6c4e34') +
      tdBuilding(312, ky - 44, 104, 48, '#7d8796', '#5c646f') +
      /* ร่องน้ำริมทาง คือเหตุผลที่คนขับอ้างว่าจอดชิดไม่ได้ */
      '<rect x="36" y="' + (ky + 8) + '" width="330" height="7" rx="3" fill="' + tdShade('#41464e', .72) + '"/>' +
      tdCar(140, py - 11, 0, '#8a94a3', 1, false) + tdCar(300, py - 11, 0, '#8a94a3', 1, false) +
      tdCar(220, py, 0, TD_BLUE, 1, false) +
      /* ช่องว่างที่เกิดขึ้น วงไว้ให้เห็นว่ากว้างกว่าคันข้าง ๆ */
      '<rect x="196" y="' + (ky + 7) + '" width="48" height="11" rx="4" fill="none" ' +
      'stroke="#ffd166" stroke-width="2.2" stroke-dasharray="7 5"/>' +
      tdPath('tdpM', 'M-30 ' + (py + 26) + ' L430 ' + (py + 26), TD_RED, 460, 0) +
      tdMove(tdMoto(0, 0, 0, 1, TD_RED), 'tdpM', 3.8, 0) +
      tdConflict(238, py + 22);
  },

  /* คำถาม  ที่ว่างที่เจออยู่ห่างจากป้ายหยุดรถประจำทางมาทางด้านหน้าราวสิบเมตร
     ด้านหน้าของป้าย คือฝั่งที่รถโดยสารยังไม่ถึงป้าย ซึ่งคือฝั่งซ้ายของภาพ
     เพราะรถโดยสารวิ่งไปทางขวาเหมือนเรา จึงเข้าหาป้ายจากทางซ้าย */
  parkbus: function (p) {
    var ky = tdKy(), py = tdPy(), cy = TD_PARK.cy;
    return tdParkBase(p) +
      tdKerbOk(36, 366) + tdKerbNoPark(160, 300) +
      tdBuilding(110, ky - 46, 128, 52, '#9a7350', '#6c4e34') +
      tdBuilding(316, ky - 44, 104, 48, '#7d8796', '#5c646f') +
      tdBusSign(268, ky - 8) +
      /* ศาลาที่พักผู้โดยสาร ช่วยให้อ่านออกว่าเป็นป้ายรถเมล์ ไม่ใช่ป้ายจราจร */
      '<rect x="240" y="' + (ky - 34) + '" width="64" height="20" rx="4" fill="#5b6b7f"/>' +
      '<rect x="240" y="' + (ky - 34) + '" width="64" height="7" rx="3" fill="#8494a8"/>' +
      tdPerson(252, ky - 12, '#3f6f9e') +
      tdBaySpot(190, 70) +
      tdPath('tdpA', 'M46 ' + (cy - 23) + ' L146 ' + (cy - 23) + ' Q176 ' + (cy - 23) + ' 180 ' + py + ' L188 ' + py,
        TD_BLUE, 180, 1.4) +
      tdDrive(tdCar(0, 0, 0, TD_BLUE, 1, true) + tdStreak(-22, 3), 'tdpA', .34, TD_LOOP, 0);
  },

  /* คำถาม  ที่ว่างริมถนนอยู่ตรงหน้าปากทางเข้าออกของอาคารพาณิชย์พอดี ตอนนี้ไม่มีรถเข้าออก
     ปากทางเข้าออกคือตัวโจทย์ วาดเป็นช่องเปิดที่ขอบทางพร้อมอาคารด้านหลัง
     ต้องเห็นว่าช่องว่างอยู่ขวางปากทางนั้นพอดี ไม่ใช่อยู่ถัดไป */
  parkgate: function (p) {
    var ky = tdKy(), py = tdPy(), cy = TD_PARK.cy;
    return tdParkBase(p) +
      tdKerbOk(36, 366) + tdKerbNoStop(154, 266) +
      tdGateMouth(p, 210, 62) +
      tdBuilding(74, ky - 44, 88, 48, '#9a7350', '#6c4e34') +
      tdCar(322, py, 0, '#8a94a3', 1, false) +
      tdBaySpot(210, 66) +
      tdPath('tdpA', 'M50 ' + (cy - 23) + ' L156 ' + (cy - 23) + ' Q192 ' + (cy - 23) + ' 196 ' + py + ' L208 ' + py,
        TD_BLUE, 190, 1.4) +
      tdDrive(tdCar(0, 0, 0, TD_BLUE, 1, true) + tdStreak(-22, 3), 'tdpA', .36, TD_LOOP, 0);
  },

  /* คำถาม  ที่หมายอยู่ฝั่งตรงข้าม และมีที่ว่างพอดีอยู่ริมทางฝั่งนั้น ถนนสวนทางกันได้สองทิศ
     ข้อนี้เป็นข้อเดียวในไฟล์ที่ช่องว่างอยู่ขอบล่าง เพราะนั่นคือฝั่งตรงข้ามของเรา
     รถที่จอดอยู่ฝั่งนั้นต้องหันหน้าไปทางซ้ายของภาพ เพราะเป็นทิศทางของเลนนั้น */
  parkopposite: function (p) {
    var cy = TD_PARK.cy, hh = TD_PARK.hh, ky2 = cy + hh, py2 = cy + hh - 13;
    return tdParkBase(p) +
      tdKerbOk(36, 366) + tdKerbOk(36, 366, TD_PARK.cy + TD_PARK.hh) +
      tdBuilding(120, tdKy() - 44, 132, 48, '#7d8796', '#5c646f') +
      tdBuilding(240, 236, 128, 46, '#b4784a', '#7d5232') +
      /* รถที่จอดอยู่ฝั่งตรงข้าม หันหน้าไปทางซ้ายตามทิศของเลนนั้น */
      tdCar(160, py2, 180, '#8a94a3', 1, false) + tdCar(316, py2, 180, '#8a94a3', 1, false) +
      tdBay2(240) +
      tdPath('tdpA', 'M56 ' + (cy - 23) + ' L170 ' + (cy - 23) + ' Q228 ' + (cy - 23) + ' 232 ' + py2 + ' L238 ' + py2,
        TD_BLUE, 220, 1.4) +
      tdConflict(240, py2) +
      tdDrive(tdCar(0, 0, 0, TD_BLUE, 1, true) + tdStreak(-22, 3), 'tdpA', .4, TD_LOOP, 0);
  },

  /* คำถาม  ต้องจอดรถบนถนนที่ลาดชัน ริมทางเป็นขอบฟุตบาท
     ความชันมองจากบนไม่เห็น จึงต้องบอกด้วยลูกศรกับแถบไล่เฉดที่ผิวถนน
     ล้อหน้าคือสิ่งที่คำถามถาม จึงวาดล้อหน้าให้เห็นชัดเป็นสองแท่ง */
  parkslope: function (p) {
    var ky = tdKy(), py = tdPy(), cy = TD_PARK.cy;
    return tdParkBase(p) +
      tdKerbOk(36, 366) +
      /* แถบไล่เฉดบอกว่าพื้นลาดลงไปทางซ้าย ลูกศรบอกทิศทางลง */
      '<rect x="-4" y="' + (cy - TD_PARK.hh) + '" width="200" height="' + (TD_PARK.hh * 2) + '" fill="#000" opacity=".16"/>' +
      '<g transform="translate(92,' + (cy + 30) + ')" opacity=".8">' +
      '<path d="M34 0 H-24 M-16 -8 l-8 8 8 8" fill="none" stroke="#ffd166" stroke-width="3.4" ' +
      'stroke-linecap="round" stroke-linejoin="round"/></g>' +
      tdBuilding(120, ky - 46, 140, 52, '#9a7350', '#6c4e34') +
      tdBuilding(316, ky - 44, 100, 48, '#7d8796', '#5c646f') +
      tdCar(224, py, 0, TD_BLUE, 1, false) +
      /* ล้อหน้าของรถ วงไว้เพราะเป็นสิ่งเดียวที่คำถามถาม */
      '<g fill="#1b2430"><rect x="236" y="' + (py - 12) + '" width="7" height="7" rx="2"/>' +
      '<rect x="236" y="' + (py + 5) + '" width="7" height="7" rx="2"/></g>' +
      tdFocus(240, py, 24);
  },

  /* คำถาม  รถเสียกลางทางตอนกลางคืน ต้องจอดริมถนนที่ไม่มีไฟส่องสว่าง
     รถของเราดับสนิทและอยู่ในช่องทางเดินรถ ยังไม่ได้แสดงเครื่องหมายอะไร
     รถที่วิ่งมาจากด้านหลังคือสิ่งที่คำถามกำลังจะถามถึง จึงต้องเห็นว่ามีจริง */
  brokennight: function (p) {
    var cy = TD_PARK.cy, py = tdPy() + 8;
    return tdParkBase(p) +
      tdKerbOk(36, 366) +
      tdTree(48, 40, 13) + tdTree(330, 44, 12) +
      /* รถของเรา ไฟดับทั้งคัน จึงกลืนไปกับถนน */
      tdCar(230, py, 0, '#4a5568', 1, false) +
      /* รถที่วิ่งตามมาจากด้านหลัง เปิดไฟหน้าอยู่ ลำแสงยังไปไม่ถึงตัวรถที่จอด */
      tdPath('tdpB', 'M-40 ' + (cy - 23) + ' L150 ' + (cy - 23), TD_RED, 190, .2) +
      tdMove(tdCar(0, 0, 0, '#c2492f', 1, false) + tdBeam(22, 0, 'e', 76, 26, .22), 'tdpB', 3.4, 0) +
      tdConflict(214, py);
  },

  /* คำถาม  จำเป็นต้องจอดรถริมถนนตอนกลางคืน ตรงนั้นไม่มีไฟส่องสว่างเลย
     ต่างจากข้อรถเสียตรงที่ข้อนี้จอดเรียบร้อยชิดขอบทางแล้ว
     คำถามคือควรเปิดไฟดวงไหนไว้ ภาพจึงต้องมืดจริงและเห็นว่ารถไม่มีไฟดวงใดติดอยู่ */
  parknight: function (p) {
    var ky = tdKy(), py = tdPy(), cy = TD_PARK.cy;
    return tdParkBase(p) +
      tdKerbOk(36, 366) +
      tdTree(60, 40, 13) + tdTree(300, 42, 12) +
      tdCar(206, py, 0, '#3d4654', 1, false) +
      /* วงแหวนชี้ที่ตัวรถ เพราะคำถามถามว่ารถคันนี้ควรเปิดไฟอะไร */
      tdFocus(206, py, 32) +
      /* รถที่วิ่งสวนมาในเลนล่าง ไฟหน้าส่องไปคนละทางกับรถที่จอด จึงไม่ช่วยให้ใครเห็นมัน */
      tdPath('tdpB', 'M430 ' + (cy + 23) + ' L-40 ' + (cy + 23), TD_RED, 470, .3) +
      tdMove(tdCar(0, 0, 0, '#c2492f', 1, false) + tdBeam(22, 0, 'e', 80, 26, .2), 'tdpB', 4.2, 0);
  }
};

/* กรอบช่องว่างฝั่งขอบล่าง ใช้เฉพาะข้อจอดฝั่งตรงข้ามข้อเดียว */
function tdBay2(x) {
  var y = TD_PARK.cy + TD_PARK.hh - 27;
  return '<rect x="' + (x - 35) + '" y="' + y + '" width="70" height="28" rx="5" ' +
    'fill="rgba(255,209,102,.14)" stroke="#ffd166" stroke-width="2.2" stroke-dasharray="8 6"/>';
}

(function () {
  var target = (typeof TD_SCENES !== 'undefined') ? TD_SCENES
             : (typeof window !== 'undefined' ? window.TD_SCENES : null);
  if (!target) { throw new Error('ต้องโหลด assets/scene-top.js ก่อน assets/scene-top4.js'); }
  Object.keys(TD_SCENES4).forEach(function (k) {
    if (target[k]) { throw new Error('ชื่อฉากซ้ำกับของเดิม: ' + k); }
    target[k] = TD_SCENES4[k];
  });
})();
